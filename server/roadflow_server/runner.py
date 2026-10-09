"""Run SUMO replications for a simulation request."""

from __future__ import annotations

import subprocess
import xml.etree.ElementTree as ET
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from .demand import FlowInfo, write_routes
from .network_builder import BuiltNetwork
from .schemas import SimulationRequest
from .sumo_tools import binary


class SimulationError(Exception):
    pass


@dataclass
class ReplicationRun:
    index: int
    seed: int
    workdir: Path
    flows: list[FlowInfo]
    variant_class: dict[str, str]
    has_trajectory: bool

    @property
    def tripinfo(self) -> Path:
        return self.workdir / "tripinfo.xml"

    @property
    def statistics(self) -> Path:
        return self.workdir / "statistics.xml"

    @property
    def lanedata(self) -> Path:
        return self.workdir / "lanedata.xml"

    @property
    def edgedata(self) -> Path:
        return self.workdir / "edgedata.xml"

    @property
    def fcd(self) -> Path:
        return self.workdir / "fcd.csv"

    @property
    def tls(self) -> Path:
        return self.workdir / "tls.xml"


def _write_additional(req: SimulationRequest, path: Path) -> None:
    run = req.run
    root = ET.Element("additional")
    common = {"begin": f"{run.warmup_s:.1f}", "end": f"{run.duration_s:.1f}", "excludeEmpty": "true"}
    ET.SubElement(root, "laneData", {"id": "lanes", "file": "lanedata.xml", **common})
    ET.SubElement(root, "edgeData", {"id": "edges", "file": "edgedata.xml", "withInternal": "true", **common})
    ET.SubElement(root, "timedEvent", {"type": "SaveTLSStates", "dest": "tls.xml"})
    ET.indent(root)
    ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)


def fcd_period(req: SimulationRequest, for_trajectory: bool) -> float:
    """FCD sampling period actually used: the requested period rounded to a whole number of steps."""
    step = float(req.run.step_length_s)
    wanted = req.run.trajectory.period_s if for_trajectory else 1.0
    return round(max(1, round(wanted / step)) * step, 6)


def sumo_command(req: SimulationRequest, built: BuiltNetwork, rep: ReplicationRun) -> list[str]:
    run = req.run
    cmd = [
        binary("sumo"),
        "--net-file", str(built.net_file),
        "--route-files", "routes.rou.xml",
        "--additional-files", "additional.add.xml",
        "--begin", "0",
        "--end", f"{run.duration_s:.1f}",
        "--step-length", str(run.step_length_s),
        "--seed", str(rep.seed),
        "--tripinfo-output", "tripinfo.xml",
        "--tripinfo-output.write-unfinished", "true",
        "--tripinfo-output.write-undeparted", "true",
        "--statistic-output", "statistics.xml",
        "--no-step-log", "true",
        "--duration-log.disable", "true",
        "--xml-validation", "never",
        "--threads", "1",
    ]  # fmt: skip
    if req.drivers.car_follow_model != "EIDM":
        # Reaction times are modelled with action steps, which SUMO requires to use
        # the ballistic position update (it would otherwise switch it on with a warning).
        cmd += ["--step-method.ballistic", "true"]
    # Floating-car data drives both the queue analysis (every replication) and the
    # playback of replication 0, which is sampled at the requested trajectory period.
    period = fcd_period(req, rep.has_trajectory)
    cmd += [
        "--fcd-output", "fcd.csv",
        "--fcd-output.attributes", "x,y,angle,speed,lane,pos,type",
        "--device.fcd.period", f"{period:g}",
    ]  # fmt: skip
    return cmd


def run_replications(
    req: SimulationRequest,
    built: BuiltNetwork,
    workdir: Path,
    max_parallel: int,
    on_progress: Callable[[int, int], None] | None = None,
    timeout_s: float = 3600.0,
) -> list[ReplicationRun]:
    reps: list[ReplicationRun] = []
    for i in range(req.run.replications):
        seed = req.run.base_seed + i
        rep_dir = workdir / f"rep_{i}"
        rep_dir.mkdir(parents=True, exist_ok=True)
        flows, variant_class = write_routes(built, req.demand, req.drivers, req.run, seed, rep_dir / "routes.rou.xml")
        _write_additional(req, rep_dir / "additional.add.xml")
        reps.append(ReplicationRun(i, seed, rep_dir, flows, variant_class, i == 0 and req.run.trajectory.enabled))

    done = 0

    def _one(rep: ReplicationRun) -> ReplicationRun:
        proc = subprocess.run(sumo_command(req, built, rep), capture_output=True, text=True, timeout=timeout_s, cwd=rep.workdir)
        (rep.workdir / "sumo.log").write_text((proc.stdout or "") + (proc.stderr or ""), encoding="utf-8")
        if proc.returncode != 0:
            errors = [ln for ln in (proc.stderr or "").splitlines() if ln.startswith("Error")]
            raise SimulationError(
                f"SUMO failed in replication {rep.index}: " + ("; ".join(errors) or (proc.stderr or "")[-1500:])
            )
        return rep

    with ThreadPoolExecutor(max_workers=max(1, min(max_parallel, len(reps)))) as pool:
        for _ in pool.map(_one, reps):
            done += 1
            if on_progress:
                on_progress(done, len(reps))
    return reps
