"""Benchmarks of the simulation set-up against textbook traffic-engineering relationships.

These are plausibility checks of the *default model configuration*, not a
calibration to local conditions. Run ``python -m roadflow_server.benchmarks`` to
regenerate the table in docs/VALIDATION.md.

* Signalised through movement vs Webster's (1958) delay formula.
* Minor-street capacity at a give-way / stop junction vs the HCM 6th Ed.
  potential-capacity (Harders) equation with base critical headway 6.2 s and
  follow-up headway 3.3 s (minor-street right turn onto a one-lane major road).
* Single-lane roundabout entry capacity vs HCM 6th Ed. Eq. 22-1:
  c = 1380 * exp(-1.02e-3 * v_c).
"""

from __future__ import annotations

import math
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

from .jobs import Job, JobManager
from .schemas import SimulationRequest

CAR = {"car": 1, "truck": 0, "bus": 0}


@dataclass
class BenchmarkResult:
    name: str
    condition: str
    reference: float
    simulated: float
    unit: str
    reference_source: str

    @property
    def ratio(self) -> float:
        return self.simulated / self.reference if self.reference else math.nan


def _run(data: dict, root: Path) -> Job:
    req = SimulationRequest.model_validate(data)
    manager = JobManager(root, parallel_replications=4)
    job = Job(id=f"b{time.time_ns()}", created=time.time(), request=req, workdir=root / f"b{time.time_ns()}")
    manager._run(job)
    if job.status != "done":
        raise RuntimeError(f"benchmark run failed: {job.errors}")
    return job


def _run_settings(replications: int) -> dict:
    return {"durationS": 3000, "warmupS": 600, "replications": replications, "trajectory": {"enabled": False}}


def webster(root: Path, flow_per_lane: float = 200.0, replications: int = 5) -> BenchmarkResult:
    """Two-lane signalised approach, through traffic only, 90 s cycle (36 s green + 4 s yellow)."""

    def arm(rid: str, a: str) -> dict:
        return {"id": rid, "from": a, "to": "c", "speedLimitKmh": 60, "forward": {"lanes": 2}, "backward": {"lanes": 2}}

    data = {
        "network": {
            "nodes": [
                {"id": "c", "x": 0, "y": 0, "control": "traffic_light"},
                {"id": "n", "x": 0, "y": 300},
                {"id": "s", "x": 0, "y": -300},
                {"id": "e", "x": 300, "y": 0},
                {"id": "w", "x": -300, "y": 0},
            ],
            "roads": [arm("rn", "n"), arm("rs", "s"), arm("re", "e"), arm("rw", "w")],
        },
        "signals": {"cycleTimeS": 90},
        "demand": {
            "origins": [
                {"node": "n", "flowVehPerHour": 2 * flow_per_lane, "mix": CAR, "destinations": [{"node": "s", "share": 1}]}
            ]
        },
        "run": _run_settings(replications),
    }
    job = _run(data, root)
    c, g, s = 90.0, 37.0, 1800.0 / 3600.0  # effective green: 36 s + 4 s yellow - ~3 s lost time
    q = flow_per_lane / 3600.0
    lam = g / c
    x = q / (s * lam)
    d = c * (1 - lam) ** 2 / (2 * (1 - lam * x)) + x**2 / (2 * q * (1 - x)) - 0.65 * (c / q**2) ** (1 / 3) * x ** (2 + 5 * lam)
    sim = job.result["summary"]["avgDelayS"]["mean"]
    return BenchmarkResult(
        "Signalised approach delay",
        f"{flow_per_lane:.0f} veh/h/lane, C = 90 s, g ≈ 37 s",
        d,
        sim,
        "s/veh",
        "Webster (1958), saturation flow 1800 veh/h/lane",
    )


def minor_street_capacity(root: Path, major_flow: float, control: str = "priority", replications: int = 3) -> BenchmarkResult:
    data = {
        "network": {
            "nodes": [
                {"id": "j", "x": 0, "y": 0, "control": control},
                {"id": "w", "x": -400, "y": 0},
                {"id": "e", "x": 400, "y": 0},
                {"id": "s", "x": 0, "y": -300},
            ],
            "roads": [
                {
                    "id": "m1",
                    "from": "w",
                    "to": "j",
                    "speedLimitKmh": 60,
                    "priority": 3,
                    "forward": {"lanes": 1},
                    "backward": {"lanes": 0},
                },
                {
                    "id": "m2",
                    "from": "j",
                    "to": "e",
                    "speedLimitKmh": 60,
                    "priority": 3,
                    "forward": {"lanes": 1},
                    "backward": {"lanes": 0},
                },
                {
                    "id": "mi",
                    "from": "s",
                    "to": "j",
                    "speedLimitKmh": 40,
                    "priority": 1,
                    "forward": {"lanes": 1},
                    "backward": {"lanes": 0},
                },
            ],
        },
        "demand": {
            "origins": [
                {"node": "w", "flowVehPerHour": max(major_flow, 1.0), "mix": CAR, "destinations": [{"node": "e", "share": 1}]},
                {"node": "s", "flowVehPerHour": 1100, "mix": CAR, "destinations": [{"node": "e", "share": 1}]},
            ]
        },
        "run": _run_settings(replications),
    }
    job = _run(data, root)
    tc, tf, vc = 6.2, 3.3, major_flow
    ref = 3600 / tf if vc <= 0 else vc * math.exp(-vc * tc / 3600) / (1 - math.exp(-vc * tf / 3600))
    sim = next(a for a in job.result["approaches"] if a["road"] == "mi")["metrics"]["throughputVehPerHour"]["mean"]
    label = "give-way" if control == "priority" else "stop"
    return BenchmarkResult(
        f"Minor-street capacity ({label})",
        f"major flow {major_flow:.0f} veh/h, saturated minor right turn",
        ref,
        sim,
        "veh/h",
        "HCM 6th Ed. potential capacity, t_c = 6.2 s, t_f = 3.3 s",
    )


def roundabout_entry_capacity(root: Path, circulating: float, replications: int = 3) -> BenchmarkResult:
    def arm(rid: str, a: str) -> dict:
        return {"id": rid, "from": a, "to": "r", "speedLimitKmh": 50, "forward": {"lanes": 1}, "backward": {"lanes": 1}}

    data = {
        "network": {
            "nodes": [
                {
                    "id": "r", "x": 0, "y": 0, "control": "roundabout",
                    "roundabout": {"radiusM": 20, "lanes": 1, "laneWidthM": 5.0, "speedLimitKmh": 30},
                },
                {"id": "n", "x": 0, "y": 300},
                {"id": "s", "x": 0, "y": -300},
                {"id": "e", "x": 300, "y": 0},
                {"id": "w", "x": -300, "y": 0},
            ],
            "roads": [arm("rn", "n"), arm("rs", "s"), arm("re", "e"), arm("rw", "w")],
        },
        "demand": {
            "origins": [
                # North -> east passes in front of the south entry (counter-clockwise circulation).
                {"node": "n", "flowVehPerHour": max(circulating, 1.0), "mix": CAR, "destinations": [{"node": "e", "share": 1}]},
                {"node": "s", "flowVehPerHour": 1600, "mix": CAR, "destinations": [{"node": "n", "share": 1}]},
            ]
        },
        "run": _run_settings(replications),
    }  # fmt: skip
    job = _run(data, root)
    ref = 1380 * math.exp(-1.02e-3 * circulating)
    sim = next(a for a in job.result["approaches"] if a["road"] == "rs")["metrics"]["throughputVehPerHour"]["mean"]
    return BenchmarkResult(
        "Roundabout entry capacity",
        f"single lane, circulating {circulating:.0f} veh/h",
        ref,
        sim,
        "veh/h",
        "HCM 6th Ed. Eq. 22-1",
    )


def run_all(root: Path) -> list[BenchmarkResult]:
    out = [webster(root)]
    for vc in (0, 400, 800):
        out.append(minor_street_capacity(root, vc))
    out.append(minor_street_capacity(root, 400, control="priority_stop"))
    for vc in (0, 400, 800):
        out.append(roundabout_entry_capacity(root, vc))
    return out


def markdown(results: list[BenchmarkResult]) -> str:
    lines = [
        "| Benchmark | Condition | Reference | Simulated | Ratio | Reference source |",
        "|---|---|---:|---:|---:|---|",
    ]
    for r in results:
        lines.append(
            f"| {r.name} | {r.condition} | {r.reference:.1f} {r.unit} | {r.simulated:.1f} {r.unit} | {r.ratio:.2f} | {r.reference_source} |"
        )
    return "\n".join(lines)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as tmp:
        print(markdown(run_all(Path(tmp))))
