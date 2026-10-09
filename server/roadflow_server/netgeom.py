"""Read the SUMO network actually used in the simulation and export it for display.

The tablet renders *this* geometry during playback (not its own drawing), so the
displayed lanes are exactly the lanes the vehicles were simulated on.
"""

from __future__ import annotations

import math
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field

from .network_builder import BuiltNetwork


def _shape(s: str) -> list[list[float]]:
    pts = []
    for tok in s.split():
        parts = tok.split(",")
        pts.append([round(float(parts[0]), 2), round(float(parts[1]), 2)])
    return pts


@dataclass
class NetIndex:
    lane_speed: dict[str, float] = field(default_factory=dict)  # lane id -> speed limit m/s
    lane_length: dict[str, float] = field(default_factory=dict)
    edge_length: dict[str, float] = field(default_factory=dict)
    edge_lanes: dict[str, list[str]] = field(default_factory=dict)
    internal_owner: dict[str, str] = field(default_factory=dict)  # internal edge id -> incoming normal edge
    geometry: dict = field(default_factory=dict)


def read_network(built: BuiltNetwork) -> NetIndex:
    idx = NetIndex()
    root = ET.parse(built.net_file).getroot()
    editor_node_of = {sj: en for en, sjs in built.junction_groups.items() for sj in sjs}
    lanes_out: list[dict] = []
    xs: list[float] = []
    ys: list[float] = []
    for edge in root.iter("edge"):
        eid = edge.get("id")
        internal = edge.get("function") == "internal"
        lanes = []
        for lane in edge.iter("lane"):
            lid = lane.get("id")
            speed = float(lane.get("speed", "0"))
            length = float(lane.get("length", "0"))
            idx.lane_speed[lid] = speed
            idx.lane_length[lid] = length
            lanes.append(lid)
            if internal:
                continue
            shape = _shape(lane.get("shape", ""))
            for x, y in shape:
                xs.append(x)
                ys.append(y)
            info = built.edges.get(eid)
            lanes_out.append(
                {
                    "id": lid,
                    "edge": eid,
                    "road": info.road_id if info else None,
                    "direction": info.direction if info else None,
                    "role": info.role if info else None,
                    "index": int(lane.get("index", "0")),
                    "width": float(lane.get("width", "3.2")),
                    "speedKmh": round(speed * 3.6, 1),
                    "shape": shape,
                }
            )
        idx.edge_lanes[eid] = lanes
        if lanes:
            idx.edge_length[eid] = max(idx.lane_length[lane_id] for lane_id in lanes)

    # Internal edges belong to the approach whose incoming edge feeds them.
    via_owner: dict[str, str] = {}
    connections = list(root.iter("connection"))
    for c in connections:
        via = c.get("via")
        if via and not c.get("from", "").startswith(":"):
            via_owner[via.rsplit("_", 1)[0]] = c.get("from")
    changed = True
    while changed:  # chained internal lanes (e.g. waiting position for left turns)
        changed = False
        for c in connections:
            frm, via = c.get("from", ""), c.get("via")
            if frm.startswith(":") and via:
                via_edge = via.rsplit("_", 1)[0]
                if frm in via_owner and via_edge not in via_owner:
                    via_owner[via_edge] = via_owner[frm]
                    changed = True
    idx.internal_owner = via_owner

    junctions_out = []
    for j in root.iter("junction"):
        if j.get("type") == "internal":
            continue
        shape = _shape(j.get("shape", ""))
        if len(shape) < 3:
            continue
        junctions_out.append(
            {"id": j.get("id"), "editorNode": editor_node_of.get(j.get("id")), "type": j.get("type"), "shape": shape}
        )

    signals_out = []
    lane_shapes = {ln["id"]: ln["shape"] for ln in lanes_out}
    for c in connections:
        tl = c.get("tl")
        if not tl:
            continue
        from_lane = f"{c.get('from')}_{c.get('fromLane')}"
        shape = lane_shapes.get(from_lane)
        if not shape or len(shape) < 2:
            continue
        (x0, y0), (x1, y1) = shape[-2], shape[-1]
        signals_out.append(
            {
                "tl": tl,
                "linkIndex": int(c.get("linkIndex", "0")),
                "fromLane": from_lane,
                "toLane": f"{c.get('to')}_{c.get('toLane')}",
                "dir": c.get("dir"),
                "stop": [x1, y1],
                "heading": round(math.degrees(math.atan2(y1 - y0, x1 - x0)), 1),
            }
        )

    programs = []
    for tl in root.iter("tlLogic"):
        programs.append(
            {
                "id": tl.get("id"),
                "type": tl.get("type"),
                "offset": float(tl.get("offset", "0")),
                "phases": [{"duration": float(p.get("duration")), "state": p.get("state")} for p in tl.iter("phase")],
            }
        )

    idx.geometry = {
        "lanes": lanes_out,
        "junctions": junctions_out,
        "signals": signals_out,
        "tlPrograms": programs,
        "bounds": [min(xs), min(ys), max(xs), max(ys)] if xs else [0, 0, 0, 0],
        "drivingSide": "left" if root.get("lefthand") == "true" else "right",
    }
    return idx
