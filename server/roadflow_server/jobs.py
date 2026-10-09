"""Simulation job orchestration: build -> simulate replications -> analyse -> store."""

from __future__ import annotations

import hashlib
import json
import logging
import shutil
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

from . import sumo_tools
from .analysis import aggregate, analyse_replication, definitions, quality_assessment
from .demand import DemandError, check_reachability
from .netgeom import read_network
from .network_builder import BuiltNetwork, NetworkBuildError, build_network
from .runner import SimulationError, run_replications
from .schemas import BuildRequest, SimulationRequest
from .trajectory import build_trajectory

log = logging.getLogger("roadflow.jobs")


def request_hash(req: SimulationRequest) -> str:
    canonical = json.dumps(req.model_dump(mode="json", by_alias=True), sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def assumptions(req: SimulationRequest, built: BuiltNetwork) -> list[dict]:
    d, s, r = req.drivers, req.signals, req.run
    has_tl = any(c == "traffic_light" for c in built.controls.values())
    items = [
        (
            f"Microscopic simulation with Eclipse SUMO {sumo_tools.version()}; car-following model {d.car_follow_model}, "
            "lane changing LC2013, SUMO default junction (gap-acceptance) model.",
            f"محاكاة مجهرية باستخدام Eclipse SUMO {sumo_tools.version()}؛ نموذج تتبع المركبات {d.car_follow_model}، "
            "نموذج تغيير المسارات LC2013، ونموذج التقاطعات (قبول الفجوات) الافتراضي في SUMO.",
        ),
        (
            "Vehicle dimensions and acceleration/deceleration are SUMO's documented vClass defaults "
            "(car 5.0 m, truck 7.1 m, bus 12 m); they are not calibrated to the local fleet.",
            "أبعاد المركبات وقيم التسارع والتباطؤ هي القيم الافتراضية الموثقة في SUMO "
            "(سيارة 5.0 م، شاحنة 7.1 م، حافلة 12 م)؛ غير معايرة على الأسطول المحلي.",
        ),
        (
            (
                f"Driver heterogeneity: {d.variants_per_class} driver profiles per class with desired time headway "
                f"mean {d.tau_mean_s} s (CV {d.tau_cv}), accel CV {d.accel_cv}, decel CV {d.decel_cv}, "
                f"standstill gap CV {d.min_gap_cv}, reaction interval {d.reaction_time_min_s}-{d.reaction_time_max_s} s, "
                f"speed factor N({d.speed_factor_mean}, {d.speed_factor_dev}). These spreads are assumptions."
            )
            if d.heterogeneity
            else "Driver heterogeneity disabled: one driver profile per vehicle class.",
            (
                f"تباين السائقين: {d.variants_per_class} نمطًا لكل فئة، بمتوسط فاصل زمني مرغوب {d.tau_mean_s} ث "
                f"(معامل اختلاف {d.tau_cv})، وزمن استجابة بين {d.reaction_time_min_s} و{d.reaction_time_max_s} ث. "
                "هذه الانتشارات افتراضات."
            )
            if d.heterogeneity
            else "تباين السائقين معطّل: نمط سائق واحد لكل فئة.",
        ),
        (
            f"Gap acceptance: SUMO junction model with base impatience {d.impatience} "
            + ("and strict full stops at stop signs. " if d.stop_sign_full_stop else "and stop signs modelled with give-way gap behaviour (no enforced full halt). ")
            + "These settings were chosen so minor-street and roundabout entry capacities approximate HCM 6th Ed. "
            "relationships in the benchmark suite (docs/VALIDATION.md); they are not calibrated to local driver behaviour.",
            f"قبول الفجوات: نموذج التقاطعات في SUMO مع نفاد صبر أساسي {d.impatience} "
            + ("وتوقف كامل إلزامي عند لافتات التوقف. " if d.stop_sign_full_stop else "ونمذجة لافتات التوقف بسلوك إفساح الطريق (دون فرض توقف كامل). ")
            + "اختيرت هذه القيم لتقارب الطاقة الاستيعابية للطرق الفرعية ومداخل الدوارات علاقاتِ دليل HCM الإصدار السادس في مجموعة الاختبارات المرجعية "
            "(docs/VALIDATION.md)؛ وهي غير معايرة على سلوك السائقين المحلي.",
        ),
        (
            f"Vehicle arrivals: {'Poisson (random exponential headways)' if req.demand.arrivals == 'poisson' else 'uniform headways'}; "
            f"demand source: {req.demand.source}.",
            f"وصول المركبات: {'عشوائي وفق توزيع بواسون' if req.demand.arrivals == 'poisson' else 'فواصل منتظمة'}؛ "
            f"مصدر الطلب: {'مرصود' if req.demand.source == 'observed' else 'افتراضي'}.",
        ),
        (
            f"Simulation {r.duration_s:.0f} s with {r.warmup_s:.0f} s warm-up excluded from statistics; "
            f"time step {r.step_length_s} s; {r.replications} replication(s) with seeds {r.base_seed}..{r.base_seed + r.replications - 1}.",
            f"مدة المحاكاة {r.duration_s:.0f} ث، مع استبعاد فترة إحماء {r.warmup_s:.0f} ث من الإحصاءات؛ "
            f"خطوة زمنية {r.step_length_s} ث؛ {r.replications} تكرار ببذور {r.base_seed}..{r.base_seed + r.replications - 1}.",
        ),
        (
            "Lane-to-movement assignment at junctions is generated automatically by netconvert "
            f"(U-turns {'allowed' if req.network.allow_u_turns else 'not allowed'}).",
            "تخصيص المسارات لحركات الانعطاف في التقاطعات يُولَّد آليًا بواسطة netconvert "
            f"(الالتفاف للخلف {'مسموح' if req.network.allow_u_turns else 'غير مسموح'}).",
        ),
    ]
    if has_tl:
        items.append(
            (
                f"Signals: fixed-time plans generated automatically (cycle {s.cycle_time_s} s, layout '{s.layout}', "
                f"yellow {'auto from approach speed' if s.yellow_time_s is None else f'{s.yellow_time_s} s'}, "
                f"all-red {s.all_red_time_s} s, protected-left green {s.left_turn_green_s} s). Not optimised and not field timings.",
                f"الإشارات: خطط زمنية ثابتة مولدة آليًا (دورة {s.cycle_time_s} ث، تخطيط '{s.layout}'، "
                f"أحمر شامل {s.all_red_time_s} ث). غير محسّنة وليست التوقيتات الميدانية.",
            )
        )
    return [{"en": en, "ar": ar} for en, ar in items]


@dataclass
class Job:
    id: str
    created: float
    request: SimulationRequest
    workdir: Path
    status: str = "queued"  # queued | building | running | analysing | done | failed
    progress: float = 0.0
    message: str = ""
    errors: list[str] = field(default_factory=list)
    result: dict | None = None
    finished: float | None = None

    def public(self, include_result: bool = True) -> dict:
        out = {
            "jobId": self.id,
            "status": self.status,
            "progress": round(self.progress, 3),
            "message": self.message,
            "errors": self.errors,
            "createdAt": self.created,
            "finishedAt": self.finished,
            "label": self.request.label,
        }
        if include_result and self.result is not None:
            out["result"] = self.result
        return out


class JobManager:
    def __init__(
        self, root: Path, workers: int = 1, parallel_replications: int = 2, ttl_s: float = 24 * 3600, max_jobs: int = 200
    ):
        self.root = root
        self.root.mkdir(parents=True, exist_ok=True)
        self.parallel_replications = parallel_replications
        self.ttl_s = ttl_s
        self.max_jobs = max_jobs
        self.jobs: dict[str, Job] = {}
        self.lock = threading.Lock()
        self.pool = ThreadPoolExecutor(max_workers=workers, thread_name_prefix="sim")

    # ----------------------------------------------------------------- public
    def submit(self, req: SimulationRequest) -> Job:
        self._cleanup()
        job_id = uuid.uuid4().hex
        job = Job(job_id, time.time(), req, self.root / job_id)
        with self.lock:
            if len(self.jobs) >= self.max_jobs:
                raise RuntimeError("job store is full; delete old jobs")
            self.jobs[job_id] = job
        self.pool.submit(self._run, job)
        return job

    def get(self, job_id: str) -> Job | None:
        with self.lock:
            return self.jobs.get(job_id)

    def delete(self, job_id: str) -> bool:
        with self.lock:
            job = self.jobs.pop(job_id, None)
        if job is None:
            return False
        shutil.rmtree(job.workdir, ignore_errors=True)
        return True

    def artefact(self, job: Job, name: str) -> Path | None:
        p = job.workdir / name
        return p if p.exists() else None

    def build_only(self, req: BuildRequest) -> dict:
        workdir = self.root / f"build_{uuid.uuid4().hex}"
        try:
            built = build_network(req.network, req.signals, workdir)
            net = read_network(built)
            return {"geometry": net.geometry, "warnings": built.warnings, "approaches": _approaches_json(built)}
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    # --------------------------------------------------------------- pipeline
    def _run(self, job: Job) -> None:
        req = job.request
        try:
            job.status, job.message = "building", "Building SUMO network"
            built = build_network(req.network, req.signals, job.workdir / "net")
            net = read_network(built)
            problems = check_reachability(built, req.demand)
            if problems:
                raise DemandError(problems)
            job.status, job.message, job.progress = "running", "Running replications", 0.05

            def progress(done: int, total: int) -> None:
                job.progress = 0.05 + 0.8 * done / total
                job.message = f"Replication {done}/{total} finished"

            reps = run_replications(req, built, job.workdir, self.parallel_replications, progress)
            job.status, job.message = "analysing", "Computing measures of effectiveness"
            rep_metrics = [analyse_replication(req, built, net, r) for r in reps]
            agg = aggregate(req, built, rep_metrics)
            quality = quality_assessment(req, agg)
            if req.run.trajectory.enabled:
                traj = build_trajectory(req, reps[0])
                _write_json(job.workdir / "trajectory.json", traj)
            _write_json(job.workdir / "network.json", net.geometry)
            job.result = {
                "requestHash": request_hash(req),
                "engine": {
                    "name": "Eclipse SUMO",
                    "version": sumo_tools.version(),
                    "carFollowModel": req.drivers.car_follow_model,
                    "laneChangeModel": "LC2013",
                },
                "run": {
                    "durationS": req.run.duration_s,
                    "warmupS": req.run.warmup_s,
                    "replications": req.run.replications,
                    "seeds": [r.seed for r in reps],
                    "losMethod": req.run.los_method,
                    "demandSource": req.demand.source,
                },
                **agg,
                **quality,
                "buildWarnings": built.warnings,
                "assumptions": assumptions(req, built),
                "definitions": definitions(),
                "hasTrajectory": req.run.trajectory.enabled,
            }
            _write_json(job.workdir / "result.json", job.result)
            job.status, job.message, job.progress = "done", "Finished", 1.0
        except (NetworkBuildError, DemandError) as e:
            job.status, job.errors, job.message = "failed", e.messages, "Invalid design or demand"
        except SimulationError as e:
            job.status, job.errors, job.message = "failed", [str(e)], "Simulation failed"
        except Exception as e:  # noqa: BLE001 - surface unexpected failures to the client
            log.exception("job %s crashed", job.id)
            job.status, job.errors, job.message = "failed", [f"{type(e).__name__}: {e}"], "Internal error"
        finally:
            job.finished = time.time()
            self._prune_workdir(job)

    def _prune_workdir(self, job: Job) -> None:
        """Keep only what the API serves (and the logs); raw SUMO output can be large."""
        for rep_dir in job.workdir.glob("rep_*"):
            for name in ("fcd.csv",):
                (rep_dir / name).unlink(missing_ok=True)

    def _cleanup(self) -> None:
        now = time.time()
        with self.lock:
            expired = [j for j in self.jobs.values() if j.finished and now - j.finished > self.ttl_s]
        for j in expired:
            self.delete(j.id)


def _approaches_json(built: BuiltNetwork) -> list[dict]:
    return [
        {"node": a.node_id, "road": a.road_id, "direction": a.direction, "edges": a.edges, "lanesAtStopLine": a.lanes_at_stopline}
        for a in built.approaches
    ]


def _write_json(path: Path, data: dict) -> None:
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    tmp.replace(path)
