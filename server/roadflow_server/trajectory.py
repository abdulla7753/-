"""Compact vehicle trajectories and signal states for playback on the tablet.

Playback shows replication 0 exactly as SUMO simulated it: positions come from
SUMO's floating-car-data output, signal colours from SaveTLSStates.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

from .demand import CLASS_DEFAULTS
from .queues import iter_fcd
from .runner import ReplicationRun, fcd_period
from .schemas import SimulationRequest


def build_trajectory(req: SimulationRequest, rep: ReplicationRun) -> dict:
    tr = req.run.trajectory
    begin = tr.begin_s
    end = min(req.run.duration_s, begin + tr.max_duration_s)
    vehicles: list[dict] = []
    index: dict[str, int] = {}
    times: list[float] = []
    frames: list[list[float]] = []
    for t, rows in iter_fcd(rep.fcd):
        if t > end + 1e-9:
            break
        if t + 1e-9 < begin:
            continue
        frame: list[float] = []
        for r in rows:
            i = index.get(r.vid)
            if i is None:
                cls = rep.variant_class.get(r.vtype) or r.vtype.split("_")[0]
                d = CLASS_DEFAULTS.get(cls, CLASS_DEFAULTS["car"])
                i = len(vehicles)
                index[r.vid] = i
                vehicles.append({"id": r.vid, "cls": cls, "length": d["length"], "width": d["width"]})
            frame.extend((i, round(r.x, 2), round(r.y, 2), round(r.angle, 1), round(r.speed, 2)))
        times.append(round(t, 3))
        frames.append(frame)
    return {
        "replication": rep.index,
        "seed": rep.seed,
        "periodS": fcd_period(req, True),
        "beginS": begin,
        "endS": end,
        "stride": 5,
        "fields": ["vehicle", "x", "y", "angleDeg", "speedMs"],
        "angleConvention": "SUMO: degrees clockwise from north",
        "vehicles": vehicles,
        "times": times,
        "frames": frames,
        "signals": signal_changes(rep.tls, begin, end),
    }


def signal_changes(path: Path, begin: float, end: float) -> list[dict]:
    """Signal state per traffic light, only when it changes (plus the state at ``begin``)."""
    out: list[dict] = []
    last: dict[str, str] = {}
    pending_initial: dict[str, dict] = {}
    if not path.exists():
        return out
    for _, el in ET.iterparse(path, events=("end",)):
        if el.tag != "tlsState":
            continue
        t = float(el.get("time", "0"))
        tl = el.get("id", "")
        state = el.get("state", "")
        if t < begin:
            pending_initial[tl] = {"t": begin, "tl": tl, "state": state}
            last[tl] = state
        elif t <= end:
            if tl in pending_initial:
                out.append(pending_initial.pop(tl))
            if last.get(tl) != state:
                out.append({"t": t, "tl": tl, "state": state})
                last[tl] = state
        el.clear()
    out.extend(pending_initial.values())
    out.sort(key=lambda e: e["t"])
    return out
