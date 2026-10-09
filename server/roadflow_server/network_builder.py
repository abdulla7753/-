"""Convert the editor's road model into a SUMO network via plain XML + netconvert.

Naming conventions for generated SUMO ids (editor ids never contain "__"):

* ``<road>__f`` / ``<road>__b``            main edge of the forward / backward direction
* ``<road>__f__p<k>``                      k-th piece when a direction is split for turn bays
* ``<road>__f__s<k>``                      split node between pieces
* ``<node>__rb__<road>__<s|e>``            roundabout entry/exit node for a road start/end
* ``<node>__ring__<k>``                    k-th circulating edge of a roundabout
"""

from __future__ import annotations

import math
import subprocess
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

from . import geometry as geo
from .schemas import Direction, Network, NodeControl, Road, SignalSettings
from .sumo_tools import binary

MIN_PIECE_LENGTH_M = 10.0


class NetworkBuildError(Exception):
    def __init__(self, messages: list[str]):
        super().__init__("; ".join(messages))
        self.messages = messages


@dataclass
class EdgeInfo:
    sumo_id: str
    road_id: str | None  # None for roundabout ring edges
    direction: str  # "forward" | "backward" | "ring"
    role: str  # "main" | "bay" | "ring"
    from_node: str  # editor node id at the upstream end of the road direction
    to_node: str  # editor node id the direction leads into
    lanes: int
    speed_ms: float
    length_m: float


@dataclass
class Approach:
    """A road direction entering an editor node (junction, signal or roundabout)."""

    node_id: str
    road_id: str
    direction: str
    edges: list[str]  # upstream -> downstream, last edge ends at the junction
    lanes_at_stopline: int


@dataclass
class BuiltNetwork:
    workdir: Path
    net_file: Path
    edges: dict[str, EdgeInfo]
    origin_edge: dict[str, str]  # boundary editor node -> first edge leaving it
    destination_edge: dict[str, str]  # boundary editor node -> last edge entering it
    approaches: list[Approach]
    junction_groups: dict[str, list[str]]  # editor node -> SUMO junction ids
    controls: dict[str, str]  # editor node -> control type
    warnings: list[str] = field(default_factory=list)


def _f(v: float) -> str:
    return f"{v:.3f}"


def _shape_str(points: list[geo.Point]) -> str:
    return " ".join(f"{_f(x)},{_f(y)}" for x, y in points)


class _Builder:
    def __init__(
        self, net: Network, signals: SignalSettings, workdir: Path, bay_offset: dict[tuple[str, str], float] | None = None
    ):
        self.net = net
        # Extra length per (road, direction) so bays are measured from the stop line,
        # which netconvert places some metres before the node centre.
        self.bay_offset = bay_offset or {}
        self.bay_targets: dict[tuple[str, str], tuple[str, float]] = {}
        self.signals = signals
        self.workdir = workdir
        self.nodes = {n.id: n for n in net.nodes}
        self.degree: dict[str, int] = {n.id: 0 for n in net.nodes}
        for r in net.roads:
            self.degree[r.from_] += 1
            self.degree[r.to] += 1
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.xml_nodes: list[dict[str, str]] = []
        self.xml_edges: list[tuple[dict[str, str], list[dict[str, str]]]] = []
        self.xml_connections: list[dict[str, str]] = []
        self.roundabouts: list[list[str]] = []
        self.edges: dict[str, EdgeInfo] = {}
        self.origin_edge: dict[str, str] = {}
        self.destination_edge: dict[str, str] = {}
        self.approaches: list[Approach] = []
        self.junction_groups: dict[str, list[str]] = {}
        # (road id, "s"|"e") -> (sumo node id, position) replacing a road end at a roundabout
        self.ring_attach: dict[tuple[str, str], tuple[str, geo.Point]] = {}
        self.trimmed: dict[str, list[geo.Point]] = {}

    # ------------------------------------------------------------------ nodes
    def build(self) -> None:
        for n in self.net.nodes:
            if self.degree[n.id] == 0:
                self.warnings.append(f"node {n.id} is not connected to any road and was ignored")
        self.trimmed = {r.id: self._full_polyline(r) for r in self.net.roads}
        for r in self.net.roads:
            if geo.polyline_length(self.trimmed[r.id]) < 1.0:
                self.errors.append(f"road {r.id} is shorter than 1 m")
        for n in self.net.nodes:
            if self.degree[n.id] == 0:
                continue
            if n.control == NodeControl.ROUNDABOUT:
                self._roundabout(n)
            else:
                node_type = n.control.value
                if self.degree[n.id] == 1 and n.control == NodeControl.TRAFFIC_LIGHT:
                    self.warnings.append(f"node {n.id}: a dead-end cannot be signalised; using priority")
                    node_type = "priority"
                self.xml_nodes.append({"id": n.id, "x": _f(n.x), "y": _f(n.y), "z": _f(n.z), "type": node_type})
                self.junction_groups[n.id] = [n.id]
        if self.errors:
            return
        for r in self.net.roads:
            self._road(r)

    def _full_polyline(self, r: Road) -> list[geo.Point]:
        a, b = self.nodes[r.from_], self.nodes[r.to]
        return [(a.x, a.y)] + [tuple(p) for p in r.shape] + [(b.x, b.y)]  # type: ignore[misc]

    def _roundabout(self, n) -> None:
        spec = n.roundabout
        center = (n.x, n.y)
        attachments: list[tuple[float, str]] = []
        for r in self.net.roads:
            for end in ("s", "e"):
                if (end == "s" and r.from_ != n.id) or (end == "e" and r.to != n.id):
                    continue
                poly = self.trimmed[r.id] if end == "s" else list(reversed(self.trimmed[r.id]))
                hit = geo.exit_circle(poly, center, spec.radius_m)
                if hit is None:
                    self.errors.append(f"road {r.id} is too short to reach outside roundabout {n.id} (radius {spec.radius_m} m)")
                    continue
                p, rest = hit
                if geo.polyline_length(rest) < MIN_PIECE_LENGTH_M:
                    self.errors.append(f"road {r.id}: less than {MIN_PIECE_LENGTH_M} m left outside roundabout {n.id}")
                    continue
                self.trimmed[r.id] = rest if end == "s" else list(reversed(rest))
                node_id = f"{n.id}__rb__{r.id}__{end}"
                self.ring_attach[(r.id, end)] = (node_id, p)
                attachments.append((geo.angle_of(center, p), node_id))
                self.xml_nodes.append({"id": node_id, "x": _f(p[0]), "y": _f(p[1]), "z": _f(n.z), "type": "priority"})
        if len(attachments) < 2:
            self.errors.append(f"roundabout {n.id} needs at least two connected roads")
            return
        attachments.sort()
        min_arc = min(
            ((attachments[(k + 1) % len(attachments)][0] - attachments[k][0]) % (2 * math.pi)) * spec.radius_m
            for k in range(len(attachments))
        )
        if min_arc < 8.0:
            self.errors.append(f"roundabout {n.id}: two roads meet the circle less than 8 m apart; increase the radius")
            return
        ccw = self.net.driving_side == "right"  # counter-clockwise circulation for right-hand traffic
        ring_ids: list[str] = []
        m = len(attachments)
        for k in range(m):
            a, b = (attachments[k], attachments[(k + 1) % m]) if ccw else (attachments[(k + 1) % m], attachments[k])
            edge_id = f"{n.id}__ring__{k}"
            shape = geo.arc_points(center, spec.radius_m, a[0], b[0], ccw=ccw)
            speed = spec.speed_limit_kmh / 3.6
            self.xml_edges.append(
                (
                    {
                        "id": edge_id,
                        "from": a[1],
                        "to": b[1],
                        "numLanes": str(spec.lanes),
                        "speed": _f(speed),
                        "width": _f(spec.lane_width_m),
                        "shape": _shape_str(shape),
                        "spreadType": "center",
                        "priority": "20",
                    },
                    [],
                )
            )
            self.edges[edge_id] = EdgeInfo(
                edge_id, None, "ring", "ring", n.id, n.id, spec.lanes, speed, geo.polyline_length(shape)
            )
            ring_ids.append(edge_id)
        self.roundabouts.append(ring_ids)
        self.junction_groups[n.id] = [node_id for _, node_id in attachments]

    # ------------------------------------------------------------------ roads
    def _road(self, r: Road) -> None:
        poly = self.trimmed[r.id]
        start = self.ring_attach.get((r.id, "s"), (r.from_, None))[0]
        end = self.ring_attach.get((r.id, "e"), (r.to, None))[0]
        two_way = r.forward.lanes > 0 and r.backward.lanes > 0
        spread = "right" if two_way else "center"
        if r.forward.lanes > 0:
            self._direction(r, "forward", "f", r.forward, poly, start, end, r.from_, r.to, spread)
        if r.backward.lanes > 0:
            self._direction(r, "backward", "b", r.backward, list(reversed(poly)), end, start, r.to, r.from_, spread)

    def _direction(
        self,
        r: Road,
        direction: str,
        tag: str,
        spec: Direction,
        poly: list[geo.Point],
        start_node: str,
        end_node: str,
        from_editor: str,
        to_editor: str,
        spread: str,
    ) -> None:
        speed = r.speed_limit_kmh / 3.6
        total = geo.polyline_length(poly)
        base = f"{r.id}__{tag}"
        # Breakpoints (distance from the stop line) where bays begin, longest first.
        bays: list[tuple[float, str, int]] = []
        if spec.left_bay:
            bays.append((spec.left_bay.length_m, "left", spec.left_bay.lanes))
        if spec.right_bay:
            bays.append((spec.right_bay.length_m, "right", spec.right_bay.lanes))
        bays.sort(reverse=True)
        offset = self.bay_offset.get((r.id, direction), 0.0)
        if bays and total - bays[0][0] - offset < MIN_PIECE_LENGTH_M:
            self.errors.append(f"road {r.id} ({direction}): turn bay of {bays[0][0]:.0f} m does not fit in a {total:.0f} m road")
            return
        # Pieces: (polyline, right lanes added, left lanes added)
        pieces: list[tuple[list[geo.Point], int, int]] = []
        remaining = poly
        added_r = added_l = 0
        for length, side, lanes in bays:
            cut_at = geo.polyline_length(remaining) - length - offset
            # A second bay within MIN_PIECE_LENGTH_M of the first starts at the same split.
            if cut_at >= MIN_PIECE_LENGTH_M:
                head, remaining = geo.split_polyline(remaining, cut_at)
                pieces.append((head, added_r, added_l))
            if side == "right":
                added_r += lanes
            else:
                added_l += lanes
        pieces.append((remaining, added_r, added_l))

        node_ids = [start_node]
        for k in range(1, len(pieces)):
            split_id = f"{base}__s{k}"
            p = pieces[k][0][0]
            z = self.nodes[from_editor].z
            self.xml_nodes.append({"id": split_id, "x": _f(p[0]), "y": _f(p[1]), "z": _f(z), "type": "priority"})
            node_ids.append(split_id)
        node_ids.append(end_node)

        edge_ids: list[str] = []
        for k, (shape, ar, al) in enumerate(pieces):
            edge_id = base if len(pieces) == 1 else f"{base}__p{k}"
            lanes = spec.lanes + ar + al
            attrs = {
                "id": edge_id,
                "from": node_ids[k],
                "to": node_ids[k + 1],
                "numLanes": str(lanes),
                "speed": _f(speed),
                "width": _f(r.lane_width_m),
                "shape": _shape_str(shape),
                "spreadType": spread,
            }
            if r.priority is not None:
                attrs["priority"] = str(r.priority)
            if r.name:
                attrs["name"] = r.name
            self.xml_edges.append((attrs, []))
            role = "main" if k == 0 else "bay"
            self.edges[edge_id] = EdgeInfo(
                edge_id, r.id, direction, role, from_editor, to_editor, lanes, speed, geo.polyline_length(shape)
            )
            edge_ids.append(edge_id)
        if bays:
            self.bay_targets[(r.id, direction)] = (edge_ids[-1], bays[-1][0])
        # Explicit lane connections across bay splits: through lanes keep their
        # position, new right lanes branch from the rightmost lane, new left
        # lanes from the leftmost lane (lane 0 is the rightmost lane in SUMO).
        for k in range(len(pieces) - 1):
            _, ar0, al0 = pieces[k]
            _, ar1, al1 = pieces[k + 1]
            n0 = spec.lanes + ar0 + al0
            shift = ar1 - ar0
            for i in range(n0):
                self._connect(edge_ids[k], edge_ids[k + 1], i, i + shift)
            for j in range(shift):
                self._connect(edge_ids[k], edge_ids[k + 1], 0, j)
            for j in range(al1 - al0):
                self._connect(edge_ids[k], edge_ids[k + 1], n0 - 1, n0 + shift + j)

        if self.degree[from_editor] == 1:
            self.origin_edge[from_editor] = edge_ids[0]
        if self.degree[to_editor] == 1:
            self.destination_edge[to_editor] = edge_ids[-1]
        target = self.nodes[to_editor]
        if (
            self.degree[to_editor] >= 3
            or target.control in (NodeControl.TRAFFIC_LIGHT, NodeControl.ROUNDABOUT)
            or (self.degree[to_editor] == 2 and target.control != NodeControl.PRIORITY)
        ):
            self.approaches.append(Approach(to_editor, r.id, direction, edge_ids, spec.lanes + added_r + added_l))

    def _connect(self, a: str, b: str, fl: int, tl: int) -> None:
        self.xml_connections.append({"from": a, "to": b, "fromLane": str(fl), "toLane": str(tl)})

    # ------------------------------------------------------------------ output
    def write(self) -> tuple[Path, Path, Path]:
        nod = ET.Element("nodes")
        for attrs in self.xml_nodes:
            ET.SubElement(nod, "node", attrs)
        edg = ET.Element("edges")
        for attrs, _ in self.xml_edges:
            ET.SubElement(edg, "edge", attrs)
        for ring in self.roundabouts:
            ET.SubElement(edg, "roundabout", {"edges": " ".join(ring)})
        con = ET.Element("connections")
        for attrs in self.xml_connections:
            ET.SubElement(con, "connection", attrs)
        paths = (self.workdir / "net.nod.xml", self.workdir / "net.edg.xml", self.workdir / "net.con.xml")
        for tree, path in zip((nod, edg, con), paths, strict=True):
            ET.indent(tree)
            ET.ElementTree(tree).write(path, encoding="utf-8", xml_declaration=True)
        return paths


def netconvert_args(net: Network, signals: SignalSettings) -> list[str]:
    args = [
        "--offset.disable-normalization", "true",
        "--junctions.corner-detail", "5",
        "--no-turnarounds", "false" if net.allow_u_turns else "true",
        "--tls.default-type", "static",
        "--tls.cycle.time", str(signals.cycle_time_s),
        "--tls.layout", signals.layout,
        "--tls.left-green.time", str(signals.left_turn_green_s),
        "--tls.allred.time", str(signals.all_red_time_s),
    ]  # fmt: skip
    if signals.yellow_time_s is not None:
        args += ["--tls.yellow.time", str(signals.yellow_time_s)]
    if net.driving_side == "left":
        args += ["--lefthand", "true"]
    return args


def _netconvert(b: _Builder, net: Network, signals: SignalSettings, workdir: Path, timeout_s: float) -> tuple[Path, str]:
    nod, edg, con = b.write()
    net_file = workdir / "net.net.xml"
    cmd = [
        binary("netconvert"),
        "--node-files", str(nod),
        "--edge-files", str(edg),
        "--connection-files", str(con),
        "--output-file", str(net_file),
        *netconvert_args(net, signals),
    ]  # fmt: skip
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_s, cwd=workdir)
    log = (proc.stdout or "") + (proc.stderr or "")
    (workdir / "netconvert.log").write_text(log, encoding="utf-8")
    if proc.returncode != 0 or not net_file.exists():
        errors = [ln.strip() for ln in log.splitlines() if ln.strip().startswith("Error")] or [log.strip()[-2000:]]
        raise NetworkBuildError(errors)
    return net_file, log


def _bay_errors(b: _Builder, net_file: Path) -> dict[tuple[str, str], float]:
    """Desired minus built storage length of every turn bay (measured along lane 0 to the stop line)."""
    lengths = {}
    for edge in ET.parse(net_file).getroot().iter("edge"):
        lane = edge.find("lane")
        if lane is not None:
            lengths[edge.get("id")] = float(lane.get("length", "0"))
    return {key: target - lengths.get(edge_id, target) for key, (edge_id, target) in b.bay_targets.items()}


def build_network(net: Network, signals: SignalSettings, workdir: Path, timeout_s: float = 120.0) -> BuiltNetwork:
    workdir.mkdir(parents=True, exist_ok=True)
    offsets: dict[tuple[str, str], float] = {}
    for _ in range(3):
        b = _Builder(net, signals, workdir, offsets)
        b.build()
        if b.errors:
            raise NetworkBuildError(b.errors)
        net_file, log = _netconvert(b, net, signals, workdir, timeout_s)
        errors = _bay_errors(b, net_file)
        if all(abs(e) < 1.0 for e in errors.values()):
            break
        offsets = {k: offsets.get(k, 0.0) + e for k, e in errors.items()}
    warnings = b.warnings + [ln.strip() for ln in log.splitlines() if ln.strip().startswith("Warning")][:50]
    return BuiltNetwork(
        workdir=workdir,
        net_file=net_file,
        edges=b.edges,
        origin_edge=b.origin_edge,
        destination_edge=b.destination_edge,
        approaches=b.approaches,
        junction_groups=b.junction_groups,
        controls={n.id: n.control.value for n in net.nodes},
        warnings=warnings,
    )
