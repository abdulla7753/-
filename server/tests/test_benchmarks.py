"""The default model configuration must stay close to textbook relationships.

Tolerances reflect what the benchmark table in docs/VALIDATION.md shows; a change
in SUMO or in our defaults that moves results outside them must be investigated.
"""

from __future__ import annotations

import pytest

from roadflow_server import benchmarks as bm


def test_webster_signal_delay(tmp_path):
    r = bm.webster(tmp_path, replications=4)
    assert r.ratio == pytest.approx(1.0, abs=0.25)


@pytest.mark.parametrize("major", [0, 400, 800])
def test_minor_street_capacity_close_to_hcm(tmp_path, major):
    r = bm.minor_street_capacity(tmp_path, major, replications=2)
    assert r.ratio == pytest.approx(1.0, abs=0.2), r


def test_stop_control_default_matches_give_way_gap_behaviour(tmp_path):
    r = bm.minor_street_capacity(tmp_path, 400, control="priority_stop", replications=2)
    assert r.ratio == pytest.approx(1.0, abs=0.2), r


@pytest.mark.parametrize("circ,low", [(0, 0.85), (400, 0.8), (800, 0.55)])
def test_roundabout_entry_capacity(tmp_path, circ, low):
    # Known limitation: SUMO is conservative at high circulating flows (ratio ~0.7 at 800 veh/h).
    r = bm.roundabout_entry_capacity(tmp_path, circ, replications=2)
    assert low <= r.ratio <= 1.15, r
