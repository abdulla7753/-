"""Vehicle types (driver heterogeneity) and traffic demand as SUMO route files."""

from __future__ import annotations

import random
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

from .network_builder import BuiltNetwork
from .schemas import Demand, DriverModel, RunSettings

# SUMO's documented vClass defaults (docs: Vehicle_Type_Parameter_Defaults, SUMO 1.28).
# Heterogeneity is sampled *around* these values; the values themselves are not
# calibrated to Qatar or any other local fleet.
CLASS_DEFAULTS = {
    "car": {"vClass": "passenger", "accel": 2.6, "decel": 4.5, "minGap": 2.5, "length": 5.0, "width": 1.8},
    "truck": {"vClass": "truck", "accel": 1.3, "decel": 4.0, "minGap": 2.5, "length": 7.1, "width": 2.4},
    "bus": {"vClass": "bus", "accel": 1.2, "decel": 4.0, "minGap": 2.5, "length": 12.0, "width": 2.5},
}
CLASSES = tuple(CLASS_DEFAULTS)


class DemandError(Exception):
    def __init__(self, messages: list[str]):
        super().__init__("; ".join(messages))
        self.messages = messages


@dataclass
class FlowInfo:
    flow_id: str
    origin: str
    destination: str
    vclass: str
    veh_per_hour: float


def _truncnorm(rng: random.Random, mean: float, cv: float, lo: float, hi: float) -> float:
    if cv <= 0:
        return mean
    for _ in range(100):
        v = rng.gauss(mean, mean * cv)
        if lo <= v <= hi:
            return v
    return min(max(mean, lo), hi)


def _reaction_times(drivers: DriverModel, step: float) -> list[float]:
    """Admissible action-step lengths: multiples of the simulation step inside the configured range."""
    values = []
    k = 1
    while k * step <= drivers.reaction_time_max_s + 1e-9:
        if k * step >= drivers.reaction_time_min_s - 1e-9:
            values.append(round(k * step, 6))
        k += 1
    return values or [step]


def vtype_elements(drivers: DriverModel, run: RunSettings, seed: int) -> tuple[list[ET.Element], dict[str, str]]:
    """Return vTypeDistribution elements and a map variant-id -> class."""
    elements: list[ET.Element] = []
    variant_class: dict[str, str] = {}
    step = float(run.step_length_s)
    reactions = _reaction_times(drivers, step)
    for ci, cls in enumerate(CLASSES):
        d = CLASS_DEFAULTS[cls]
        rng = random.Random(seed * 7919 + ci)
        dist = ET.Element("vTypeDistribution", {"id": f"{cls}_dist"})
        n = drivers.variants_per_class if drivers.heterogeneity else 1
        for k in range(n):
            vid = f"{cls}_{k}"
            het = drivers.heterogeneity
            reaction = rng.choice(reactions) if het else reactions[0]
            # With action steps, a desired headway shorter than the reaction interval is
            # unsafe in SUMO (hard braking / collisions), so tau is bounded by it.
            min_tau = 0.3 if drivers.car_follow_model == "EIDM" else max(0.3, reaction)
            tau = max(_truncnorm(rng, drivers.tau_mean_s, drivers.tau_cv if het else 0, min_tau, 3.0), min_tau)
            accel = _truncnorm(rng, d["accel"], drivers.accel_cv if het else 0, 0.5 * d["accel"], 1.6 * d["accel"])
            decel = _truncnorm(rng, d["decel"], drivers.decel_cv if het else 0, 2.0, 6.0)
            min_gap = _truncnorm(rng, d["minGap"], drivers.min_gap_cv if het else 0, 1.0, 5.0)
            attrs = {
                "id": vid,
                "vClass": d["vClass"],
                "carFollowModel": drivers.car_follow_model,
                "tau": f"{tau:.3f}",
                "accel": f"{accel:.3f}",
                "decel": f"{decel:.3f}",
                "minGap": f"{min_gap:.3f}",
                "length": f"{d['length']:.2f}",
                "width": f"{d['width']:.2f}",
                "speedFactor": f"normc({drivers.speed_factor_mean:.3f},{drivers.speed_factor_dev:.3f},0.2,2.0)",
                "impatience": f"{drivers.impatience:.3f}",
                "probability": "1",
            }
            if not drivers.stop_sign_full_stop:
                attrs["jmStopSignWait"] = "0"
            if drivers.car_follow_model == "EIDM":
                # EIDM models reaction time itself and is incompatible with action steps.
                attrs["treaction"] = f"{reaction:.3f}"
            else:
                attrs["actionStepLength"] = f"{reaction:.3f}"
            ET.SubElement(dist, "vType", attrs)
            variant_class[vid] = cls
        elements.append(dist)
    return elements, variant_class


def write_routes(
    built: BuiltNetwork, demand: Demand, drivers: DriverModel, run: RunSettings, seed: int, path: Path
) -> tuple[list[FlowInfo], dict[str, str]]:
    errors: list[str] = []
    root = ET.Element("routes")
    vtypes, variant_class = vtype_elements(drivers, run, seed)
    root.extend(vtypes)
    flows: list[FlowInfo] = []
    for oi, origin in enumerate(demand.origins):
        if origin.flow_veh_per_hour <= 0:
            continue
        src = built.origin_edge.get(origin.node)
        if src is None:
            errors.append(f"origin {origin.node} is not a road end with lanes leaving it")
            continue
        for di, dest in enumerate(origin.destinations):
            if dest.share <= 0:
                continue
            dst = built.destination_edge.get(dest.node)
            if dst is None:
                errors.append(f"destination {dest.node} is not a road end with lanes entering it")
                continue
            if dest.node == origin.node and src == dst:
                errors.append(f"origin {origin.node} cannot be its own destination")
                continue
            for cls in CLASSES:
                frac = getattr(origin.mix, cls)
                vph = origin.flow_veh_per_hour * dest.share * frac
                if vph <= 0:
                    continue
                fid = f"o{oi}_d{di}_{cls}"
                attrs = {
                    "id": fid,
                    "type": f"{cls}_dist",
                    "begin": "0",
                    "end": f"{run.duration_s:.1f}",
                    "from": src,
                    "to": dst,
                    "departLane": "best",
                    "departSpeed": "max",
                }
                if demand.arrivals == "poisson":
                    attrs["period"] = f"exp({vph / 3600.0:.8f})"
                else:
                    attrs["vehsPerHour"] = f"{vph:.4f}"
                ET.SubElement(root, "flow", attrs)
                flows.append(FlowInfo(fid, origin.node, dest.node, cls, vph))
    if errors:
        raise DemandError(errors)
    if not flows:
        raise DemandError(["demand is empty: no origin has a positive flow"])
    ET.indent(root)
    ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)
    return flows, variant_class


def check_reachability(built: BuiltNetwork, demand: Demand) -> list[str]:
    """Verify every origin/destination pair with demand has a drivable path in the built network."""
    import sumolib

    net = sumolib.net.readNet(str(built.net_file), withInternal=False)
    problems = []
    for origin in demand.origins:
        if origin.flow_veh_per_hour <= 0 or origin.node not in built.origin_edge:
            continue
        src = net.getEdge(built.origin_edge[origin.node])
        for dest in origin.destinations:
            if dest.share <= 0 or dest.node not in built.destination_edge:
                continue
            dst = net.getEdge(built.destination_edge[dest.node])
            path, _ = net.getShortestPath(src, dst, vClass="passenger")
            if path is None:
                problems.append(f"no drivable path from {origin.node} to {dest.node}")
    return problems
