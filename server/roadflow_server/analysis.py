"""Turn raw SUMO outputs into engineering measures of effectiveness.

Every number returned here is computed from simulation output files. Definitions
are documented in docs/SIMULATION_METHODOLOGY.md and repeated in the result's
``definitions`` block so a report can never lose them.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass, field

from .netgeom import NetIndex
from .network_builder import BuiltNetwork
from .queues import approach_queue_series
from .runner import ReplicationRun
from .schemas import SimulationRequest
from .stats import percentile, summarize

# HCM 6th Edition LOS thresholds on average delay per vehicle (s/veh), upper bounds for A..E.
HCM6_SIGNALIZED = (10, 20, 35, 55, 80)  # Exhibit 19-8
HCM6_UNSIGNALIZED = (10, 15, 25, 35, 50)  # Exhibits 20-2 / 21-8 (TWSC/AWSC) and 22-8 (roundabouts)


def hcm_los(delay_s: float | None, control: str) -> str | None:
    if delay_s is None:
        return None
    bounds = HCM6_SIGNALIZED if control == "traffic_light" else HCM6_UNSIGNALIZED
    for letter, ub in zip("ABCDE", bounds, strict=True):
        if delay_s <= ub:
            return letter
    return "F"


@dataclass
class Trip:
    vid: str
    flow: str
    desired_depart: float
    depart: float
    depart_delay: float
    arrival: float  # -1 when not arrived
    duration: float
    route_length: float
    time_loss: float
    stops: int
    vtype: str
    departed: bool


def _f(el: ET.Element, name: str, default: float = 0.0) -> float:
    v = el.get(name)
    if v is None or v == "":
        return default
    try:
        return float(v)
    except ValueError:
        return default


def parse_tripinfo(path, end_time: float) -> list[Trip]:
    """Parse tripinfo incl. unfinished and never-inserted vehicles.

    For vehicles that never entered, SUMO writes depart=-1 and the time waited so
    far as departDelay, so their scheduled departure is ``end_time - departDelay``.
    """
    trips: list[Trip] = []
    for _, el in ET.iterparse(path, events=("end",)):
        if el.tag != "tripinfo":
            continue
        vid = el.get("id", "")
        depart = _f(el, "depart", -1)
        depart_delay = _f(el, "departDelay", 0)
        departed = depart >= 0
        desired = (depart - depart_delay) if departed else end_time - depart_delay
        trips.append(
            Trip(
                vid=vid,
                flow=vid.rsplit(".", 1)[0],
                desired_depart=desired,
                depart=depart,
                depart_delay=depart_delay,
                arrival=_f(el, "arrival", -1),
                duration=_f(el, "duration"),
                route_length=_f(el, "routeLength"),
                time_loss=_f(el, "timeLoss"),
                stops=int(_f(el, "waitingCount")),
                vtype=el.get("vType", ""),
                departed=departed,
            )
        )
        el.clear()
    return trips


def parse_statistics(path) -> dict:
    root = ET.parse(path).getroot()
    out: dict = {}
    for tag, keys in (
        ("vehicles", ("loaded", "inserted", "running", "waiting")),
        ("teleports", ("total", "jam", "yield", "wrongLane")),
        ("safety", ("collisions", "emergencyStops", "emergencyBraking")),
    ):
        el = root.find(tag)
        out[tag] = {k: int(float(el.get(k, "0"))) for k in keys} if el is not None else {k: 0 for k in keys}
    return out


def parse_meandata(path) -> dict[str, dict[str, float]]:
    """edgeData / laneData with a single interval -> id -> attributes."""
    out: dict[str, dict[str, float]] = {}
    try:
        for _, el in ET.iterparse(path, events=("end",)):
            if el.tag in ("edge", "lane"):
                out[el.get("id")] = {k: float(v) for k, v in el.attrib.items() if k != "id" and _isnum(v)}
    except FileNotFoundError:
        pass
    return out


def _isnum(v: str) -> bool:
    try:
        float(v)
        return True
    except ValueError:
        return False


@dataclass
class RepMetrics:
    summary: dict[str, float | None]
    approaches: dict[tuple[str, str, str], dict[str, float | None]]
    movements: dict[tuple[str, str], dict[str, float | None]]
    lanes: dict[str, dict[str, float | None]]
    stats: dict
    counts: dict[str, int] = field(default_factory=dict)


def _mean(xs: list[float]) -> float | None:
    return sum(xs) / len(xs) if xs else None


def analyse_replication(req: SimulationRequest, built: BuiltNetwork, net: NetIndex, rep: ReplicationRun) -> RepMetrics:
    warmup, end = req.run.warmup_s, req.run.duration_s
    window_h = (end - warmup) / 3600.0
    flow_info = {f.flow_id: f for f in rep.flows}
    trips = parse_tripinfo(rep.tripinfo, end)
    stats = parse_statistics(rep.statistics)

    # Trip-based measures use vehicles scheduled to depart after the warm-up and early
    # enough to finish a normal trip before the end; otherwise vehicles that merely
    # started late would look like vehicles stuck in congestion.
    finished_durations = sorted(t.duration for t in trips if t.departed and t.arrival >= 0)
    tail = min(2.0 * percentile(finished_durations, 90) if finished_durations else 0.0, (end - warmup) / 2.0)
    cutoff = end - tail
    measured = [t for t in trips if warmup <= t.desired_depart <= cutoff]
    completed = [t for t in measured if t.departed and t.arrival >= 0]
    unfinished = [t for t in measured if t.departed and t.arrival < 0]
    undeparted = [t for t in measured if not t.departed]
    arrivals_in_window = [t for t in trips if t.arrival >= warmup]

    delays = [t.time_loss + t.depart_delay for t in completed]
    all_delays = [t.time_loss + t.depart_delay for t in measured]  # lower bound incl. unfinished
    total_len = sum(t.route_length for t in completed)
    total_dur = sum(t.duration for t in completed)

    approaches_out: dict[tuple[str, str, str], dict[str, float | None]] = {}
    queue_series = approach_queue_series(
        rep.fcd, [ap.edges for ap in built.approaches], net.edge_length, net.lane_length, rep.variant_class, warmup, end
    )
    edge_data = parse_meandata(rep.edgedata)
    approach_queue_max: list[float] = []
    approach_queue_mean: list[float] = []
    approach_queue_p95: list[float] = []
    internal_by_edge: dict[str, list[str]] = defaultdict(list)
    for internal, owner in net.internal_owner.items():
        internal_by_edge[owner].append(internal)

    for ap, values in zip(built.approaches, queue_series, strict=True):
        values.sort()
        qmean = sum(values) / len(values) if values else 0.0
        qmax = values[-1] if values else 0.0
        q95 = percentile(values, 95)
        approach_queue_mean.append(qmean)
        approach_queue_max.append(qmax)
        approach_queue_p95.append(q95)

        last = ap.edges[-1]
        loss = sum(edge_data.get(e, {}).get("timeLoss", 0.0) for e in ap.edges)
        loss += sum(edge_data.get(i, {}).get("timeLoss", 0.0) for i in internal_by_edge.get(last, []))
        discharged = edge_data.get(last, {}).get("left", 0.0)
        delay = loss / discharged if discharged > 0 else None
        approaches_out[(ap.node_id, ap.road_id, ap.direction)] = {
            "avgDelayS": delay,
            "avgQueueM": qmean,
            "p95QueueM": q95,
            "maxQueueM": qmax,
            "throughputVehPerHour": discharged / window_h if window_h > 0 else None,
            "vehiclesDischarged": discharged,
        }

    movements: dict[tuple[str, str], list[Trip]] = defaultdict(list)
    for t in completed:
        f = flow_info.get(t.flow)
        if f:
            movements[(f.origin, f.destination)].append(t)
    movements_out = {
        k: {
            "vehicles": float(len(v)),
            "avgDelayS": _mean([t.time_loss + t.depart_delay for t in v]),
            "avgTravelTimeS": _mean([t.duration for t in v]),
            "avgStops": _mean([float(t.stops) for t in v]),
        }
        for k, v in movements.items()
    }

    lanes_out: dict[str, dict[str, float | None]] = {}
    for lane_id, d in parse_meandata(rep.lanedata).items():
        if lane_id.startswith(":"):
            continue
        limit = net.lane_speed.get(lane_id)
        speed = d.get("speed")
        sampled = d.get("sampledSeconds", 0.0)
        if speed is None or not sampled:
            continue
        lanes_out[lane_id] = {
            "speedKmh": speed * 3.6,
            "speedRatio": (speed / limit) if limit else None,
            "occupancyPct": d.get("occupancy"),
            "densityVehPerKm": d.get("density"),
            "timeLossPerVehS": (d.get("timeLoss", 0.0) / d["left"]) if d.get("left") else None,
            "sampledSeconds": sampled,
        }

    summary = {
        "avgDelayS": _mean(delays),
        "avgTimeLossS": _mean([t.time_loss for t in completed]),
        "avgEntryDelayS": _mean([t.depart_delay for t in completed]),
        "avgDelayInclUnfinishedS": _mean(all_delays),
        "avgTravelTimeS": _mean([t.duration for t in completed]),
        "avgSpeedKmh": (total_len / total_dur * 3.6) if total_dur > 0 else None,
        "avgStops": _mean([float(t.stops) for t in completed]),
        "throughputVehPerHour": len(arrivals_in_window) / window_h if window_h > 0 else None,
        "vehiclesCompleted": float(len(completed)),
        "maxQueueM": max(approach_queue_max) if approach_queue_max else None,
        "worstApproachAvgQueueM": max(approach_queue_mean) if approach_queue_mean else None,
        "worstApproachP95QueueM": max(approach_queue_p95) if approach_queue_p95 else None,
        "unfinishedShare": (len(unfinished) + len(undeparted)) / len(measured) if measured else None,
    }
    counts = {
        "measured": len(measured),
        "completed": len(completed),
        "unfinished": len(unfinished),
        "undeparted": len(undeparted),
    }
    return RepMetrics(summary, approaches_out, movements_out, lanes_out, stats, counts)


def aggregate(req: SimulationRequest, built: BuiltNetwork, reps: list[RepMetrics]) -> dict:
    summary = {k: summarize([r.summary.get(k) for r in reps]) for k in reps[0].summary}

    approaches = []
    for ap in built.approaches:
        key = (ap.node_id, ap.road_id, ap.direction)
        metrics = {
            m: summarize([r.approaches.get(key, {}).get(m) for r in reps])
            for m in ("avgDelayS", "avgQueueM", "p95QueueM", "maxQueueM", "throughputVehPerHour")
        }
        control = built.controls.get(ap.node_id, "priority")
        approaches.append(
            {
                "node": ap.node_id,
                "road": ap.road_id,
                "direction": ap.direction,
                "control": control,
                "lanesAtStopLine": ap.lanes_at_stopline,
                "lengthM": round(sum(built.edges[e].length_m for e in ap.edges), 1),
                "metrics": metrics,
                "los": hcm_los(metrics["avgDelayS"]["mean"], control),
            }
        )

    # Per-node (intersection) delay: discharge-weighted mean of its approaches, per replication.
    nodes = []
    for node_id in dict.fromkeys(ap.node_id for ap in built.approaches):
        keys = [(a.node_id, a.road_id, a.direction) for a in built.approaches if a.node_id == node_id]
        per_rep = []
        for r in reps:
            num = den = 0.0
            for k in keys:
                a = r.approaches.get(k)
                if a and a["avgDelayS"] is not None and a["vehiclesDischarged"]:
                    num += a["avgDelayS"] * a["vehiclesDischarged"]
                    den += a["vehiclesDischarged"]
            per_rep.append(num / den if den > 0 else None)
        delay = summarize(per_rep)
        control = built.controls.get(node_id, "priority")
        nodes.append(
            {
                "node": node_id,
                "control": control,
                "avgDelayS": delay,
                "los": hcm_los(delay["mean"], control),
                "throughputVehPerHour": summarize(
                    [sum((r.approaches.get(k) or {}).get("throughputVehPerHour") or 0.0 for k in keys) for r in reps]
                ),
            }
        )

    movements = []
    all_keys = dict.fromkeys(k for r in reps for k in r.movements)
    for key in all_keys:
        movements.append(
            {
                "origin": key[0],
                "destination": key[1],
                "metrics": {
                    m: summarize([r.movements.get(key, {}).get(m) for r in reps])
                    for m in ("vehicles", "avgDelayS", "avgTravelTimeS", "avgStops")
                },
            }
        )

    lanes = []
    lane_ids = dict.fromkeys(k for r in reps for k in r.lanes)
    for lid in lane_ids:
        entry: dict = {"lane": lid}
        for m in ("speedKmh", "speedRatio", "occupancyPct", "timeLossPerVehS"):
            vals = [r.lanes.get(lid, {}).get(m) for r in reps]
            vals = [v for v in vals if v is not None]
            entry[m] = sum(vals) / len(vals) if vals else None
        lanes.append(entry)

    totals = defaultdict(int)
    for r in reps:
        for group, values in r.stats.items():
            for k, v in values.items():
                totals[f"{group}.{k}"] += v
        for k, v in r.counts.items():
            totals[f"trips.{k}"] += v
    return {
        "summary": summary,
        "nodes": nodes,
        "approaches": approaches,
        "movements": movements,
        "lanes": lanes,
        "engineCounters": dict(totals),
    }


def quality_assessment(req: SimulationRequest, agg: dict) -> dict:
    """Warnings and a reliability statement derived from the run itself."""
    warnings: list[dict] = []
    c = agg["engineCounters"]
    n_rep = req.run.replications

    def warn(code: str, severity: str, en: str, ar: str) -> None:
        warnings.append({"code": code, "severity": severity, "en": en, "ar": ar})

    if c.get("teleports.total", 0) > 0:
        warn(
            "teleports", "high",
            f"{c['teleports.total']} vehicle teleports (gridlock/blocked lanes) occurred across replications; "
            "results near the affected locations are unreliable.",
            f"حدثت {c['teleports.total']} عملية نقل قسري للمركبات (اختناق تام أو مسارات مغلقة)؛ النتائج قرب هذه المواقع غير موثوقة.",
        )  # fmt: skip
    if c.get("safety.collisions", 0) > 0:
        warn(
            "collisions", "high",
            f"{c['safety.collisions']} collisions were detected; check geometry, lane connections and signal clearance.",
            f"تم رصد {c['safety.collisions']} تصادمًا؛ راجع الهندسة وربط المسارات وزمن إخلاء الإشارات.",
        )  # fmt: skip
    if c.get("safety.emergencyStops", 0) > 0:
        warn(
            "emergency-stops", "medium",
            f"{c['safety.emergencyStops']} emergency stops across replications: vehicles could not reach the lane they needed "
            "in time (short weaving sections, turn bays or roundabout segments). Review lane arrangement at those locations.",
            f"{c['safety.emergencyStops']} توقفًا اضطراريًا عبر التكرارات: لم تتمكن مركبات من الوصول إلى المسار المطلوب في الوقت المناسب "
            "(مقاطع تداخل قصيرة أو جيوب انعطاف أو أجزاء دوار). راجع ترتيب المسارات في تلك المواقع.",
        )  # fmt: skip
    if c.get("safety.emergencyBraking", 0) > 0:
        warn(
            "emergency-braking", "info",
            f"{c['safety.emergencyBraking']} emergency-braking events (deceleration at the vehicle's emergency limit) across replications.",
            f"{c['safety.emergencyBraking']} حالة كبح طارئ (تباطؤ عند الحد الأقصى للطوارئ) عبر التكرارات.",
        )  # fmt: skip
    share = agg["summary"]["unfinishedShare"]["mean"]
    if share is not None and share > 0.05:
        warn(
            "oversaturation", "high",
            f"{share * 100:.1f}% of measured vehicles did not finish their trip (still queued or never entered). "
            "Average delay of completed vehicles underestimates the true delay; the network is likely over capacity.",
            f"{share * 100:.1f}% من المركبات المقاسة لم تكمل رحلتها (ما زالت في الطابور أو لم تدخل الشبكة). "
            "متوسط التأخير للمركبات المكتملة أقل من التأخير الحقيقي؛ غالبًا تجاوز الطلب الطاقة الاستيعابية.",
        )  # fmt: skip
    waiting = c.get("vehicles.waiting", 0)
    if waiting > 0:
        warn(
            "entry-backlog", "high",
            f"{waiting} vehicles (summed over replications) were still waiting to enter the network at the end: "
            "demand exceeds what the design can serve or queues reach the model boundary. Extend the approach roads "
            "so queues stay inside the model; delays of these vehicles are not in the averages.",
            f"{waiting} مركبة (مجموع التكرارات) كانت ما تزال تنتظر الدخول إلى الشبكة عند النهاية: الطلب يتجاوز ما يخدمه التصميم "
            "أو أن الطوابير وصلت إلى حدود النموذج. مدّد الطرق المؤدية حتى تبقى الطوابير داخل النموذج؛ تأخير هذه المركبات غير مشمول في المتوسطات.",
        )  # fmt: skip
    for ap in agg["approaches"]:
        p95 = ap["metrics"]["p95QueueM"]["mean"]
        length = ap.get("lengthM")
        if p95 is not None and length and p95 >= 0.9 * length:
            warn(
                "queue-spill", "high",
                f"Queue on approach {ap['road']} into {ap['node']} fills {p95 / length * 100:.0f}% of the modelled approach "
                f"({length:.0f} m) at the 95th percentile; the real queue may be longer than the model can show.",
                f"الطابور على المدخل {ap['road']} إلى {ap['node']} يملأ {p95 / length * 100:.0f}% من طول المدخل المنمذج "
                f"({length:.0f} م) عند المئين 95؛ قد يكون الطابور الحقيقي أطول مما يمكن للنموذج إظهاره.",
            )  # fmt: skip
    delay = agg["summary"]["avgDelayS"]
    if delay["ci95"] and delay["mean"]:
        rel = (delay["ci95"][1] - delay["mean"]) / delay["mean"]
        if rel > 0.10:
            warn(
                "precision", "medium",
                f"The 95% confidence interval of average delay is ±{rel * 100:.0f}% of the mean; run more replications.",
                f"فترة الثقة 95% لمتوسط التأخير تساوي ±{rel * 100:.0f}% من المتوسط؛ زِد عدد التكرارات.",
            )  # fmt: skip
    if n_rep < 5:
        warn(
            "few-replications", "medium",
            f"Only {n_rep} replication(s); at least 5 random seeds are recommended before drawing conclusions.",
            f"عدد التكرارات {n_rep} فقط؛ يوصى بخمس بذور عشوائية على الأقل قبل استخلاص النتائج.",
        )  # fmt: skip
    if req.demand.source == "assumed":
        warn(
            "assumed-demand", "info",
            "Traffic demand is an assumed scenario, not observed counts.",
            "الطلب المروري سيناريو افتراضي وليس أعدادًا مرصودة.",
        )  # fmt: skip
    warn(
        "uncalibrated", "info",
        "Driver-behaviour parameters are SUMO defaults with assumed variability; the model has not been calibrated "
        "or validated against field data, so results are indicative and not engineering-approved.",
        "معاملات سلوك السائقين هي القيم الافتراضية لـ SUMO مع تباين مفترض؛ لم تتم معايرة النموذج أو التحقق منه ببيانات ميدانية، "
        "لذلك النتائج استرشادية وغير معتمدة هندسيًا.",
    )  # fmt: skip
    high = any(w["severity"] == "high" for w in warnings)
    return {
        "warnings": warnings,
        "reliability": {
            "calibrated": False,
            "level": "low" if high else "indicative",
            "en": "Indicative only: uncalibrated model" + (", with serious run issues (see warnings)" if high else ""),
            "ar": "استرشادية فقط: نموذج غير معاير" + ("، مع مشكلات جوهرية في التشغيل (انظر التحذيرات)" if high else ""),
        },
    }


def definitions() -> dict:
    return {
        "avgDelayS": "Mean over completed measured vehicles of (SUMO timeLoss + departDelay): time lost against driving "
        "the whole route at the vehicle's desired speed, plus time waiting to enter the network.",
        "avgTravelTimeS": "Mean trip duration from insertion to arrival of completed measured vehicles.",
        "avgSpeedKmh": "Space-mean speed: total distance / total travel time of completed measured vehicles.",
        "avgStops": "Mean number of times a vehicle's speed dropped to 0.1 m/s or less (SUMO waitingCount).",
        "throughputVehPerHour": "Vehicles arriving at their destination during the measurement window, per hour.",
        "queue": "Back of queue from the stop line: a contiguous chain of queued vehicles (enter < 5 km/h, leave > 10 km/h, "
        "gaps of at most 20 m), measured per lane every FCD sample and maximised over the approach lanes; "
        "continues into the upstream road piece when a piece is full.",
        "approachDelay": "Time loss accumulated on the approach (incl. turn bays and the junction interior) divided by "
        "vehicles discharged; excludes acceleration downstream of the junction exit.",
        "measuredVehicles": "Vehicles scheduled to depart after the warm-up and at least two 90th-percentile trip durations "
        "before the end (capped at half the window), so that late starters are not counted as unfinished.",
        "los": "Indicative Level of Service using HCM 6th Edition delay thresholds applied to simulated delay. "
        "Microsimulation delay is not identical to HCM control delay.",
        "ci95": "95% confidence interval of the mean across replications (Student t).",
    }
