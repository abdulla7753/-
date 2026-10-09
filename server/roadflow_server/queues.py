"""Back-of-queue measurement from SUMO floating-car data.

SUMO's own queue-output measures from the stop line to the *last* slow vehicle on
the lane, so a single car accelerating from an insertion point at the far end of
the lane reads as a full-lane queue. We instead use the queue-counter definition
common in microsimulation practice (e.g. the PTV Vissim defaults):

* a vehicle enters the queued state below 5 km/h and leaves it above 10 km/h;
* a queue starts at the stop line and continues upstream through queued vehicles
  whose front is at most 20 m behind the back of the previous queued vehicle;
* the queue length is the distance from the stop line to the back of the last
  vehicle in that chain; when a road piece is completely queued the measurement
  continues into the upstream piece of the same approach (turn bays).
"""

from __future__ import annotations

import csv
import math
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from .demand import CLASS_DEFAULTS

QUEUE_ENTER_MS = 5 / 3.6
QUEUE_LEAVE_MS = 10 / 3.6
MAX_GAP_M = 20.0


@dataclass
class FcdRow:
    vid: str
    lane: str
    pos: float
    speed: float
    vtype: str
    x: float
    y: float
    angle: float


def iter_fcd(path: Path):
    """Yield (time, rows) per timestep from a SUMO FCD CSV file."""
    if not path.exists():
        return
    with path.open(newline="", encoding="utf-8") as fh:
        reader = csv.reader(fh, delimiter=";")
        header = next(reader, None)
        if not header:
            return
        col = {name: i for i, name in enumerate(header)}
        ti, vi = col["timestep_time"], col.get("vehicle_id")
        li, pi, si, yi = col.get("vehicle_lane"), col.get("vehicle_pos"), col.get("vehicle_speed"), col.get("vehicle_type")
        xi, yyi, ai = col.get("vehicle_x"), col.get("vehicle_y"), col.get("vehicle_angle")
        current_t = None
        rows: list[FcdRow] = []
        for rec in reader:
            if not rec:
                continue
            t = float(rec[ti])
            if current_t is not None and t != current_t:
                yield current_t, rows
                rows = []
            current_t = t
            if vi is None or not rec[vi]:
                continue
            rows.append(
                FcdRow(
                    vid=rec[vi],
                    lane=rec[li] if li is not None else "",
                    pos=float(rec[pi]) if pi is not None and rec[pi] else 0.0,
                    speed=float(rec[si]) if si is not None and rec[si] else 0.0,
                    vtype=rec[yi] if yi is not None else "",
                    x=float(rec[xi]) if xi is not None and rec[xi] else 0.0,
                    y=float(rec[yyi]) if yyi is not None and rec[yyi] else 0.0,
                    angle=float(rec[ai]) if ai is not None and rec[ai] else 0.0,
                )
            )
        if current_t is not None:
            yield current_t, rows


def _lane_queue(vehicles: list[tuple[float, float]], start_allowance: float = MAX_GAP_M) -> float:
    """Contiguous queue length on one lane.

    ``vehicles`` holds (front distance to the lane end, back distance) sorted by front
    distance; moving vehicles carry back = -1. The first queued vehicle must start
    within ``start_allowance`` of the lane end.
    """
    queue = 0.0
    prev_back = 0.0
    allowance = start_allowance
    for front, back in vehicles:
        if back < 0 or front - prev_back > allowance:
            break
        queue = prev_back = back
        allowance = MAX_GAP_M
    return queue


def approach_queue_series(
    fcd: Path,
    approaches: list[list[str]],
    edge_length: dict[str, float],
    lane_length: dict[str, float],
    variant_class: dict[str, str],
    warmup: float,
    end: float,
) -> list[list[float]]:
    """Queue length (m) per approach for every FCD timestep inside [warmup, end]."""
    approach_edges = {e for edges in approaches for e in edges}
    lengths = {cls: d["length"] for cls, d in CLASS_DEFAULTS.items()}
    queued: set[str] = set()
    series: list[list[float]] = [[] for _ in approaches]
    for t, rows in iter_fcd(fcd):
        in_window = warmup <= t <= end
        # edge -> lane -> [(front distance to lane end, back distance or -1 when moving)]
        per_edge: dict[str, dict[str, list[tuple[float, float]]]] = defaultdict(lambda: defaultdict(list))
        for r in rows:
            if r.speed < QUEUE_ENTER_MS:
                queued.add(r.vid)
            elif r.speed > QUEUE_LEAVE_MS:
                queued.discard(r.vid)
            if not in_window or not r.lane or r.lane.startswith(":"):
                continue
            edge = r.lane.rsplit("_", 1)[0]
            if edge not in approach_edges:
                continue
            front = max(0.0, lane_length.get(r.lane, edge_length.get(edge, 0.0)) - r.pos)
            veh_len = lengths.get(variant_class.get(r.vtype, ""), 5.0)
            per_edge[edge][r.lane].append((front, front + veh_len if r.vid in queued else -1.0))
        if not in_window:
            continue
        for lanes in per_edge.values():
            for vehicles in lanes.values():
                vehicles.sort()
        for ai, edges in enumerate(approaches):
            total = 0.0
            allowance = MAX_GAP_M
            for e in reversed(edges):
                lanes = per_edge.get(e, {})
                qe = max((_lane_queue(v, allowance) for v in lanes.values()), default=0.0)
                total += qe
                # Continue upstream only while the gap budget to the next queued vehicle
                # (empty space left at the upstream end of this piece) is not exhausted.
                slack = edge_length.get(e, math.inf) - qe
                allowance = (MAX_GAP_M if qe > 0 else allowance) - slack
                if allowance < 0:
                    break
            series[ai].append(total)
    return series
