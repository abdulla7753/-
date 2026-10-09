"""Fast unit tests: schemas, geometry, statistics, queue definition."""

from __future__ import annotations

import math

import pytest
from pydantic import ValidationError

from roadflow_server import geometry as geo
from roadflow_server.queues import approach_queue_series
from roadflow_server.schemas import SimulationRequest
from roadflow_server.stats import percentile, summarize, t975


@pytest.mark.parametrize("name", ["four_way_signalized", "t_junction_stop", "roundabout_two_lane"])
def test_fixtures_validate(fixture_data, name):
    req = SimulationRequest.model_validate(fixture_data(name))
    assert req.network.nodes and req.demand.origins


def test_rejects_reserved_id_separator(fixture_data):
    data = fixture_data("four_way_signalized")
    data["network"]["nodes"][0]["id"] = "c__x"
    with pytest.raises(ValidationError):
        SimulationRequest.model_validate(data)


def test_rejects_bad_vehicle_mix(fixture_data):
    data = fixture_data("four_way_signalized")
    data["demand"]["origins"][0]["mix"] = {"car": 0.5, "truck": 0.1, "bus": 0.1}
    with pytest.raises(ValidationError, match="sum to 1"):
        SimulationRequest.model_validate(data)


def test_rejects_unknown_node_reference(fixture_data):
    data = fixture_data("four_way_signalized")
    data["network"]["roads"][0]["to"] = "nowhere"
    with pytest.raises(ValidationError, match="unknown node"):
        SimulationRequest.model_validate(data)


def test_rejects_eidm_with_coarse_step(fixture_data):
    data = fixture_data("four_way_signalized")
    data["run"]["stepLengthS"] = 1.0
    with pytest.raises(ValidationError, match="EIDM"):
        SimulationRequest.model_validate(data)


def test_roundabout_needs_spec(fixture_data):
    data = fixture_data("roundabout_two_lane")
    del data["network"]["nodes"][0]["roundabout"]
    with pytest.raises(ValidationError, match="roundabout"):
        SimulationRequest.model_validate(data)


def test_split_polyline_preserves_length():
    poly = [(0.0, 0.0), (100.0, 0.0), (100.0, 50.0)]
    head, tail = geo.split_polyline(poly, 120.0)
    assert head[-1] == pytest.approx((100.0, 20.0))
    assert tail[0] == head[-1]
    assert geo.polyline_length(head) + geo.polyline_length(tail) == pytest.approx(150.0)


def test_exit_circle():
    p, rest = geo.exit_circle([(0.0, 0.0), (0.0, 100.0)], (0.0, 0.0), 30.0)
    assert p == pytest.approx((0.0, 30.0))
    assert rest[-1] == (0.0, 100.0)
    assert geo.exit_circle([(0.0, 0.0), (0.0, 10.0)], (0.0, 0.0), 30.0) is None


def test_arc_direction():
    ccw = geo.arc_points((0, 0), 10, 0.0, math.pi / 2, ccw=True)
    assert ccw[0] == pytest.approx((10, 0)) and ccw[-1] == pytest.approx((0, 10), abs=1e-9)
    assert ccw[len(ccw) // 2][0] > 0 and ccw[len(ccw) // 2][1] > 0  # through the first quadrant
    cw = geo.arc_points((0, 0), 10, 0.0, math.pi / 2, ccw=False)
    assert cw[len(cw) // 2][0] < 0  # the long way round, clockwise


def test_t_quantiles_and_ci():
    assert t975(1) == pytest.approx(12.706)
    assert t975(4) == pytest.approx(2.776)
    s = summarize([10.0, 12.0, 14.0])
    assert s["mean"] == pytest.approx(12.0)
    assert s["sd"] == pytest.approx(2.0)
    half = 4.303 * 2.0 / math.sqrt(3)
    assert s["ci95"] == pytest.approx([12.0 - half, 12.0 + half])
    assert summarize([None, 5.0])["n"] == 1
    assert percentile([0, 10], 50) == pytest.approx(5)


def _fcd(path, rows):
    header = "timestep_time;vehicle_id;vehicle_x;vehicle_y;vehicle_angle;vehicle_type;vehicle_speed;vehicle_pos;vehicle_lane\n"
    lines = [header] + [f"{t};{vid};0;0;0;car_0;{v};{pos};{lane}\n" for t, vid, v, pos, lane in rows]
    path.write_text("".join(lines), encoding="utf-8")


def test_queue_is_contiguous_from_stop_line(tmp_path):
    fcd = tmp_path / "fcd.csv"
    lane_len = 200.0
    _fcd(
        fcd,
        [
            # three standing cars from the stop line, 2.5 m gaps (5 m long cars)
            (10, "a", 0.0, 200.0, "e_0"),
            (10, "b", 0.0, 192.5, "e_0"),
            (10, "c", 0.0, 185.0, "e_0"),
            # a car just inserted at the far end of the lane: not part of the queue
            (10, "far", 0.0, 6.0, "e_0"),
        ],
    )
    series = approach_queue_series(fcd, [["e"]], {"e": lane_len}, {"e_0": lane_len}, {"car_0": "car"}, 0, 100)
    assert series[0] == [pytest.approx(20.0)]  # back of c: 200 - 185 + 5


def test_queue_breaks_on_moving_vehicle_and_large_gap(tmp_path):
    fcd = tmp_path / "fcd.csv"
    _fcd(
        fcd,
        [
            (1, "a", 0.0, 100.0, "e_0"),
            (1, "b", 12.0, 92.0, "e_0"),  # moving: queue ends after a
            (1, "c", 0.0, 84.0, "e_0"),
            (1, "x", 0.0, 100.0, "e_1"),
            (1, "y", 0.0, 60.0, "e_1"),  # 35 m gap behind x: separate stopped car
        ],
    )
    series = approach_queue_series(fcd, [["e"]], {"e": 100.0}, {"e_0": 100.0, "e_1": 100.0}, {"car_0": "car"}, 0, 10)
    assert series[0] == [pytest.approx(5.0)]


def test_queue_hysteresis_and_spill_into_upstream_piece(tmp_path):
    fcd = tmp_path / "fcd.csv"
    rows = []
    # t=1: everyone stopped. Downstream piece "d" (30 m) is full, queue continues on "u".
    for i, pos in enumerate([30.0, 22.5, 15.0, 7.5]):
        rows.append((1, f"d{i}", 0.0, pos, "d_0"))
    rows.append((1, "u0", 0.0, 100.0, "u_0"))
    rows.append((1, "u1", 0.0, 92.5, "u_0"))
    # t=2: u1 creeps at 7 km/h: still queued (has not exceeded 10 km/h)
    for i, pos in enumerate([30.0, 22.5, 15.0, 7.5]):
        rows.append((2, f"d{i}", 0.0, pos, "d_0"))
    rows.append((2, "u0", 0.0, 100.0, "u_0"))
    rows.append((2, "u1", 7 / 3.6, 92.5, "u_0"))
    _fcd(fcd, rows)
    lengths = {"d": 30.0, "u": 100.0}
    series = approach_queue_series(fcd, [["u", "d"]], lengths, {"d_0": 30.0, "u_0": 100.0}, {"car_0": "car"}, 0, 10)
    assert series[0][0] == pytest.approx(27.5 + 12.5)
    assert series[0][1] == pytest.approx(27.5 + 12.5)
