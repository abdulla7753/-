"""Request/response schemas shared with the RoadFlow AI tablet app.

The JSON contract is documented in ``docs/API.md``. All lengths are metres,
all times seconds, speeds km/h at the API boundary (converted to m/s for SUMO).
Coordinates are a local planar system in metres (x = east, y = north).
"""

from __future__ import annotations

import math
from enum import StrEnum
from typing import Annotated, Literal

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, field_validator, model_validator
from pydantic.alias_generators import to_camel

SCHEMA_VERSION = 1


def _check_id(v: str) -> str:
    # Ids end up inside SUMO ids, where the builder uses "__" as a separator.
    if "__" in v or v.endswith("_"):
        raise ValueError("ids must not contain '__' or end with '_'")
    return v


IdStr = Annotated[str, Field(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$"), AfterValidator(_check_id)]


class ApiModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, extra="forbid")


class NodeControl(StrEnum):
    PRIORITY = "priority"  # major road has right of way, minor road yields
    PRIORITY_STOP = "priority_stop"  # minor road must stop, then yield
    TRAFFIC_LIGHT = "traffic_light"
    ALLWAY_STOP = "allway_stop"
    RIGHT_BEFORE_LEFT = "right_before_left"
    ROUNDABOUT = "roundabout"


class RoundaboutSpec(ApiModel):
    radius_m: float = Field(ge=8.0, le=150.0, description="Radius to the centreline of the circulating roadway")
    lanes: int = Field(ge=1, le=4)
    lane_width_m: float = Field(default=4.0, ge=2.5, le=6.0)
    speed_limit_kmh: float = Field(ge=10.0, le=80.0)


class Node(ApiModel):
    id: IdStr
    x: float
    y: float
    z: float = 0.0
    control: NodeControl = NodeControl.PRIORITY
    roundabout: RoundaboutSpec | None = None

    @model_validator(mode="after")
    def _roundabout_spec(self) -> Node:
        if self.control == NodeControl.ROUNDABOUT and self.roundabout is None:
            raise ValueError(f"node {self.id}: control 'roundabout' requires a roundabout spec")
        return self


class TurnBay(ApiModel):
    lanes: int = Field(ge=1, le=3)
    length_m: float = Field(ge=10.0, le=500.0)


class Direction(ApiModel):
    lanes: int = Field(ge=0, le=8)
    left_bay: TurnBay | None = None
    right_bay: TurnBay | None = None

    @model_validator(mode="after")
    def _bays_need_lanes(self) -> Direction:
        if self.lanes == 0 and (self.left_bay or self.right_bay):
            raise ValueError("turn bays need at least one through lane in that direction")
        return self


class Road(ApiModel):
    id: IdStr
    from_: IdStr = Field(alias="from")
    to: IdStr
    shape: list[tuple[float, float]] = Field(
        default_factory=list, description="Intermediate shape points (excluding the end nodes)"
    )
    lane_width_m: float = Field(default=3.65, ge=2.5, le=5.5)
    speed_limit_kmh: float = Field(ge=5.0, le=140.0)
    forward: Direction
    backward: Direction
    priority: int | None = Field(default=None, ge=1, le=20)
    name: str | None = Field(default=None, max_length=120)

    @model_validator(mode="after")
    def _check(self) -> Road:
        if self.from_ == self.to:
            raise ValueError(f"road {self.id}: from and to must differ")
        if self.forward.lanes + self.backward.lanes == 0:
            raise ValueError(f"road {self.id}: needs at least one lane")
        return self


class Network(ApiModel):
    driving_side: Literal["right", "left"] = "right"
    allow_u_turns: bool = False
    nodes: list[Node] = Field(min_length=2, max_length=2000)
    roads: list[Road] = Field(min_length=1, max_length=4000)

    @model_validator(mode="after")
    def _refs(self) -> Network:
        ids = [n.id for n in self.nodes]
        if len(set(ids)) != len(ids):
            raise ValueError("duplicate node ids")
        road_ids = [r.id for r in self.roads]
        if len(set(road_ids)) != len(road_ids):
            raise ValueError("duplicate road ids")
        known = set(ids)
        for r in self.roads:
            for ref in (r.from_, r.to):
                if ref not in known:
                    raise ValueError(f"road {r.id} references unknown node {ref}")
        for n in self.nodes:
            if not (math.isfinite(n.x) and math.isfinite(n.y) and math.isfinite(n.z)):
                raise ValueError(f"node {n.id}: non-finite coordinates")
        return self


class SignalSettings(ApiModel):
    """Parameters for the fixed-time plan netconvert generates for every signalised node.

    Phase 1 does not let the user edit individual phases; the generated plan is
    returned with the results so the engineer can see exactly what was simulated.
    """

    cycle_time_s: int = Field(default=90, ge=30, le=240)
    yellow_time_s: int | None = Field(default=None, ge=2, le=8, description="None = derived by SUMO from approach speed")
    all_red_time_s: int = Field(default=0, ge=0, le=6)
    layout: Literal["opposites", "incoming"] = "opposites"
    left_turn_green_s: int = Field(default=6, ge=0, le=60, description="Protected left phase when turn lanes exist; 0 disables")


class VehicleMix(ApiModel):
    car: float = Field(ge=0.0, le=1.0)
    truck: float = Field(ge=0.0, le=1.0)
    bus: float = Field(ge=0.0, le=1.0)

    @model_validator(mode="after")
    def _sum(self) -> VehicleMix:
        total = self.car + self.truck + self.bus
        if abs(total - 1.0) > 1e-3:
            raise ValueError(f"vehicle mix must sum to 1 (got {total:.4f})")
        return self


class DestinationShare(ApiModel):
    node: IdStr
    share: float = Field(ge=0.0, le=1.0)


class Origin(ApiModel):
    node: IdStr
    flow_veh_per_hour: float = Field(ge=0.0, le=12000.0)
    mix: VehicleMix
    destinations: list[DestinationShare] = Field(min_length=1)

    @model_validator(mode="after")
    def _shares(self) -> Origin:
        total = sum(d.share for d in self.destinations)
        if self.flow_veh_per_hour > 0 and abs(total - 1.0) > 1e-3:
            raise ValueError(f"origin {self.node}: destination shares must sum to 1 (got {total:.4f})")
        return self


class Demand(ApiModel):
    # Provenance is carried into the results so assumed demand is never presented as observed.
    source: Literal["observed", "assumed"] = "assumed"
    source_note: str | None = Field(default=None, max_length=500)
    arrivals: Literal["poisson", "uniform"] = "poisson"
    origins: list[Origin] = Field(min_length=1)


class DriverModel(ApiModel):
    # EIDM (Salles et al. 2020) extends IDM with reaction time, estimation errors and
    # jerk limits. Plain IDM in SUMO uses very conservative lane-change gap acceptance
    # and produced emergency stops in multi-lane roundabout tests, so EIDM is the default.
    car_follow_model: Literal["IDM", "EIDM", "Krauss"] = "EIDM"
    heterogeneity: bool = True
    variants_per_class: int = Field(default=10, ge=1, le=50)
    # Coefficients of variation applied around SUMO's documented vClass defaults.
    tau_mean_s: float = Field(default=1.0, ge=0.3, le=3.0)
    tau_cv: float = Field(default=0.2, ge=0.0, le=0.6)
    accel_cv: float = Field(default=0.1, ge=0.0, le=0.5)
    decel_cv: float = Field(default=0.1, ge=0.0, le=0.5)
    min_gap_cv: float = Field(default=0.2, ge=0.0, le=0.6)
    speed_factor_mean: float = Field(default=1.0, ge=0.5, le=1.5)
    speed_factor_dev: float = Field(default=0.1, ge=0.0, le=0.4)
    reaction_time_min_s: float = Field(default=0.5, ge=0.1, le=3.0)
    reaction_time_max_s: float = Field(default=1.0, ge=0.1, le=3.0)
    # Gap acceptance at give-way / stop / roundabout entries (SUMO junction model).
    # 0.5 brings minor-street and roundabout entry capacities close to HCM 6th Ed.
    # values in the benchmark suite (docs/VALIDATION.md); SUMO's default 0 gives
    # 15-30 % of those capacities. It is a stand-in until local calibration.
    impatience: float = Field(default=0.5, ge=0.0, le=1.0)
    # SUMO's strict stop (every vehicle halts at the line) discharges stop-controlled
    # queues at ~45 % of the HCM follow-up rate; by default stop signs use the
    # field-calibrated give-way gap behaviour, as HCM does for both control types.
    stop_sign_full_stop: bool = False

    @model_validator(mode="after")
    def _range(self) -> DriverModel:
        if self.reaction_time_max_s < self.reaction_time_min_s:
            raise ValueError("reactionTimeMaxS must be >= reactionTimeMinS")
        return self


class TrajectorySettings(ApiModel):
    enabled: bool = True
    period_s: float = Field(default=0.5, ge=0.1, le=5.0)
    begin_s: float = Field(default=0.0, ge=0.0)
    max_duration_s: float = Field(default=900.0, ge=10.0, le=3600.0)


class RunSettings(ApiModel):
    duration_s: float = Field(default=3600.0, ge=60.0, le=4 * 3600.0)
    warmup_s: float = Field(default=600.0, ge=0.0, le=3600.0)
    step_length_s: Literal[0.1, 0.2, 0.25, 0.5, 1.0] = 0.2
    replications: int = Field(default=5, ge=1, le=30)
    base_seed: int = Field(default=1, ge=0, le=2**31 - 1000)
    los_method: Literal["HCM6"] = "HCM6"
    trajectory: TrajectorySettings = Field(default_factory=TrajectorySettings)

    @model_validator(mode="after")
    def _warmup(self) -> RunSettings:
        if self.warmup_s >= self.duration_s:
            raise ValueError("warmupS must be shorter than durationS")
        return self


class SimulationRequest(ApiModel):
    schema_version: int = SCHEMA_VERSION
    label: str | None = Field(default=None, max_length=200)
    network: Network
    signals: SignalSettings = Field(default_factory=SignalSettings)
    demand: Demand
    drivers: DriverModel = Field(default_factory=DriverModel)
    run: RunSettings = Field(default_factory=RunSettings)

    @field_validator("schema_version")
    @classmethod
    def _version(cls, v: int) -> int:
        if v != SCHEMA_VERSION:
            raise ValueError(f"unsupported schemaVersion {v}; server speaks {SCHEMA_VERSION}")
        return v

    @model_validator(mode="after")
    def _model_step(self) -> SimulationRequest:
        if self.drivers.car_follow_model == "EIDM" and self.run.step_length_s > 0.5:
            raise ValueError("EIDM needs a time step of 0.5 s or less (SUMO documentation)")
        if self.run.trajectory.period_s < self.run.step_length_s:
            raise ValueError("trajectory periodS cannot be shorter than the simulation step")
        return self


class BuildRequest(ApiModel):
    schema_version: int = SCHEMA_VERSION
    network: Network
    signals: SignalSettings = Field(default_factory=SignalSettings)
