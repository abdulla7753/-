"""End-to-end tests that build networks with netconvert and run real SUMO simulations.

Besides plumbing, these check that results behave like traffic: conservation of
vehicles, free-flow travel times, monotonic response to demand, reproducibility
with fixed seeds and agreement with Webster's delay formula for a simple case.
"""

from __future__ import annotations

import math
import xml.etree.ElementTree as ET

import pytest

from roadflow_server.network_builder import NetworkBuildError, build_network
from roadflow_server.schemas import SimulationRequest


def _mean(job, metric):
    return job.result["summary"][metric]["mean"]


def test_four_way_signalized_end_to_end(run_sync, fixture_data):
    job = run_sync(fixture_data("four_way_signalized"))
    assert job.status == "done", job.errors
    r = job.result
    c = r["engineCounters"]
    # Conservation: every generated vehicle was inserted or is still waiting to be.
    assert c["vehicles.loaded"] == c["vehicles.inserted"] + c["vehicles.waiting"]
    assert c["teleports.total"] == 0 and c["safety.collisions"] == 0
    # Undersaturated: throughput matches the 2000 veh/h demand within sampling noise.
    assert _mean(job, "throughputVehPerHour") == pytest.approx(2000, rel=0.12)
    assert 5 < _mean(job, "avgDelayS") < 60
    assert _mean(job, "avgStops") > 0.3  # a signal stops a good share of vehicles
    assert len(r["approaches"]) == 4
    assert all(a["los"] in "ABCDEF" for a in r["approaches"])
    assert r["nodes"][0]["control"] == "traffic_light"
    assert {m["origin"] for m in r["movements"]} == {"n", "s", "e", "w"}
    assert r["reliability"]["calibrated"] is False
    assert any(w["code"] == "uncalibrated" for w in r["warnings"])
    assert r["assumptions"] and r["definitions"]["avgDelayS"]
    assert (job.workdir / "trajectory.json").exists() and (job.workdir / "network.json").exists()


def test_turn_bay_split_and_lane_connections(tmp_path, fixture_data):
    req = SimulationRequest.model_validate(fixture_data("four_way_signalized"))
    built = build_network(req.network, req.signals, tmp_path / "net")
    root = ET.parse(built.net_file).getroot()
    lanes = {e.get("id"): len(e.findall("lane")) for e in root.iter("edge") if e.get("function") != "internal"}
    assert lanes["rn__f__p0"] == 2 and lanes["rn__f__p1"] == 3  # 60 m left-turn bay
    conns = {
        (c.get("fromLane"), c.get("toLane"))
        for c in root.iter("connection")
        if c.get("from") == "rn__f__p0" and c.get("to") == "rn__f__p1"
    }
    assert conns == {("0", "0"), ("1", "1"), ("1", "2")}
    bay_len = float(root.find(".//edge[@id='rn__f__p1']/lane").get("length"))
    assert bay_len == pytest.approx(60, abs=1.0)  # storage length measured to the stop line
    approach = next(a for a in built.approaches if a.road_id == "rn")
    assert approach.edges == ["rn__f__p0", "rn__f__p1"] and approach.lanes_at_stopline == 3
    assert built.origin_edge["n"] == "rn__f__p0" and built.destination_edge["n"] == "rn__b"


def test_bay_longer_than_road_is_rejected(tmp_path, fixture_data):
    data = fixture_data("four_way_signalized")
    data["network"]["roads"][0]["forward"]["leftBay"]["lengthM"] = 400
    req = SimulationRequest.model_validate(data)
    with pytest.raises(NetworkBuildError, match="does not fit"):
        build_network(req.network, req.signals, tmp_path / "net")


@pytest.mark.parametrize("side,ccw", [("right", True), ("left", False)])
def test_roundabout_circulation_direction(tmp_path, fixture_data, side, ccw):
    data = fixture_data("roundabout_two_lane")
    data["network"]["drivingSide"] = side
    req = SimulationRequest.model_validate(data)
    built = build_network(req.network, req.signals, tmp_path / "net")
    root = ET.parse(built.net_file).getroot()
    rings = [e for e in root.iter("edge") if "__ring__" in e.get("id", "") and e.get("function") != "internal"]
    assert len(rings) == 4
    for e in rings:
        pts = [tuple(map(float, p.split(","))) for p in e.find("lane").get("shape").split()]
        (x0, y0), (x1, y1) = pts[0], pts[-1]
        cross = x0 * y1 - y0 * x1  # roundabout centre is the origin
        assert (cross > 0) == ccw
    assert root.find("roundabout") is not None


def test_roundabout_runs_cleanly(run_sync, fixture_data):
    job = run_sync(fixture_data("roundabout_two_lane"))
    assert job.status == "done", job.errors
    c = job.result["engineCounters"]
    assert c["teleports.total"] == 0 and c["safety.collisions"] == 0
    assert c["safety.emergencyStops"] == 0
    assert _mean(job, "throughputVehPerHour") == pytest.approx(1800, rel=0.15)
    assert job.result["nodes"][0]["control"] == "roundabout"


def test_t_junction_minor_road_waits_longer(run_sync, fixture_data):
    data = fixture_data("t_junction_stop")
    data["run"]["replications"] = 5
    job = run_sync(data)
    assert job.status == "done", job.errors
    ap = {a["road"]: a for a in job.result["approaches"]}
    # The stop-controlled minor approach must give way to the major road.
    assert ap["minor"]["metrics"]["avgDelayS"]["mean"] > ap["main1"]["metrics"]["avgDelayS"]["mean"]


def test_free_flow_travel_time(run_sync):
    data = {
        "network": {
            "nodes": [{"id": "a", "x": 0, "y": 0}, {"id": "b", "x": 1000, "y": 0}],
            "roads": [
                {"id": "r", "from": "a", "to": "b", "speedLimitKmh": 60, "forward": {"lanes": 1}, "backward": {"lanes": 1}}
            ],
        },
        "demand": {
            "origins": [
                {
                    "node": "a",
                    "flowVehPerHour": 60,
                    "mix": {"car": 1, "truck": 0, "bus": 0},
                    "destinations": [{"node": "b", "share": 1}],
                }
            ]
        },
        "run": {"durationS": 1800, "warmupS": 120, "replications": 2, "trajectory": {"enabled": False}},
    }
    job = run_sync(data)
    assert job.status == "done", job.errors
    # Isolated vehicles drive at the speed limit times their individual speed factor (mean 1.0).
    assert _mean(job, "avgSpeedKmh") == pytest.approx(60, rel=0.1)
    assert _mean(job, "avgDelayS") < 3.0
    assert _mean(job, "avgStops") == pytest.approx(0, abs=0.05)


def test_same_seed_reproduces_and_new_seed_differs(run_sync, fixture_data):
    data = fixture_data("t_junction_stop")
    data["run"].update(replications=1, trajectory={"enabled": False})
    a = run_sync(data)
    b = run_sync(data)
    data["run"]["baseSeed"] = 99
    c = run_sync(data)
    assert _mean(a, "avgDelayS") == _mean(b, "avgDelayS")
    assert a.result["summary"]["vehiclesCompleted"]["mean"] == b.result["summary"]["vehiclesCompleted"]["mean"]
    assert _mean(a, "avgDelayS") != _mean(c, "avgDelayS")


def test_delay_and_queues_grow_with_demand(run_sync, fixture_data):
    results = []
    for factor in (0.5, 1.3):
        data = fixture_data("four_way_signalized")
        data["run"]["trajectory"] = {"enabled": False}
        for o in data["demand"]["origins"]:
            o["flowVehPerHour"] *= factor
        job = run_sync(data)
        assert job.status == "done", job.errors
        results.append(job)
    low, high = results
    assert _mean(high, "avgDelayS") > _mean(low, "avgDelayS")
    assert _mean(high, "worstApproachAvgQueueM") > _mean(low, "worstApproachAvgQueueM")
    assert _mean(high, "throughputVehPerHour") > _mean(low, "throughputVehPerHour")


def test_oversaturation_is_flagged(run_sync, fixture_data):
    data = fixture_data("four_way_signalized")
    data["run"].update(replications=2, trajectory={"enabled": False})
    for o in data["demand"]["origins"]:
        o["flowVehPerHour"] *= 2.5
    job = run_sync(data)
    assert job.status == "done", job.errors
    codes = {w["code"] for w in job.result["warnings"]}
    assert "entry-backlog" in codes or "oversaturation" in codes
    assert job.result["reliability"]["level"] == "low"
    assert job.result["nodes"][0]["los"] == "F"


def test_webster_benchmark_single_signalised_approach(run_sync, fixture_data):
    """Undersaturated through movement on one approach vs Webster's (1958) delay formula.

    Cycle C = 90 s with 36 s green + 4 s yellow for the north-south group; with ~3 s lost
    time the effective green is ~37 s. Saturation flow is taken as 1800 veh/h/lane, a common
    planning value; the simulated delay also includes acceleration/deceleration losses that
    Webster's model idealises, so agreement within 30 % is the expectation, not equality.
    """
    data = fixture_data("four_way_signalized")
    data["run"].update(replications=5, durationS=3600, warmupS=600, trajectory={"enabled": False})
    data["demand"]["origins"] = [
        {"node": "n", "flowVehPerHour": 400, "mix": {"car": 1, "truck": 0, "bus": 0}, "destinations": [{"node": "s", "share": 1}]}
    ]
    job = run_sync(data)
    assert job.status == "done", job.errors
    C, g, s = 90.0, 37.0, 1800.0 / 3600.0
    q = 400.0 / 3600.0 / 2  # per lane
    lam = g / C
    X = q / (s * lam)
    d = C * (1 - lam) ** 2 / (2 * (1 - lam * X)) + X**2 / (2 * q * (1 - X)) - 0.65 * (C / q**2) ** (1 / 3) * X ** (2 + 5 * lam)
    sim = _mean(job, "avgDelayS")
    print(f"Webster {d:.1f} s vs simulated {sim:.1f} s")
    assert sim == pytest.approx(d, rel=0.3)


def test_unreachable_destination_fails_with_message(run_sync):
    data = {
        "network": {
            "nodes": [{"id": "a", "x": 0, "y": 0}, {"id": "b", "x": 500, "y": 0}],
            "roads": [
                {"id": "r", "from": "a", "to": "b", "speedLimitKmh": 50, "forward": {"lanes": 1}, "backward": {"lanes": 0}}
            ],
        },
        "demand": {
            "origins": [
                {
                    "node": "b",
                    "flowVehPerHour": 100,
                    "mix": {"car": 1, "truck": 0, "bus": 0},
                    "destinations": [{"node": "a", "share": 1}],
                }
            ]
        },
        "run": {"durationS": 300, "warmupS": 60, "replications": 1},
    }
    job = run_sync(data)
    assert job.status == "failed"
    assert any("origin b" in e for e in job.errors)


def test_trajectory_matches_engine_output(run_sync, fixture_data):
    data = fixture_data("t_junction_stop")
    data["run"]["replications"] = 1
    job = run_sync(data)
    import json

    traj = json.loads((job.workdir / "trajectory.json").read_text())
    assert traj["stride"] == 5 and traj["vehicles"]
    assert traj["periodS"] == pytest.approx(0.4)
    assert traj["times"][1] - traj["times"][0] == pytest.approx(traj["periodS"], abs=1e-6)
    # Every frame entry is a vehicle index plus x, y, angle, speed inside the network bounds.
    net = json.loads((job.workdir / "network.json").read_text())
    x0, y0, x1, y1 = net["bounds"]
    for frame in traj["frames"][:200]:
        for k in range(0, len(frame), 5):
            assert 0 <= frame[k] < len(traj["vehicles"])
            assert x0 - 5 <= frame[k + 1] <= x1 + 5 and y0 - 5 <= frame[k + 2] <= y1 + 5
            assert 0 <= frame[k + 4] < 30
    assert math.isclose(traj["endS"], 300.0)
