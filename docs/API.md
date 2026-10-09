# Simulation server API (v1)

Base URL is configurable in the app. If `ROADFLOW_API_TOKEN` is set, every `/v1`
request needs `Authorization: Bearer <token>`. JSON field names are camelCase.
Unknown fields are rejected (HTTP 422).

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Server, schema and SUMO version; whether a token is required |
| POST | `/v1/networks/build` | Build the design with netconvert only. Returns lane geometry, signal plans, approaches and warnings, or 422 with `{"detail": {"errors": [...]}}` |
| POST | `/v1/simulations` | Submit a simulation (202 with `jobId`) |
| GET | `/v1/simulations/{id}` | Status `queued \| building \| running \| analysing \| done \| failed`, `progress` 0–1, `errors`, and `result` when done |
| GET | `/v1/simulations/{id}/network` | Network geometry SUMO built (lanes, junctions, signal links, signal programs, bounds) |
| GET | `/v1/simulations/{id}/trajectory` | Replication-1 vehicle positions and signal state changes |
| DELETE | `/v1/simulations/{id}` | Delete the job and its files |

## Simulation request

Complete examples: [`shared/fixtures/`](../shared/fixtures).

```jsonc
{
  "schemaVersion": 1,
  "label": "Doha – existing",
  "network": {
    "drivingSide": "right",            // right | left
    "allowUTurns": false,
    "nodes": [
      {"id": "c", "x": 0, "y": 0, "z": 0, "control": "traffic_light"},
      // control: priority | priority_stop | traffic_light | allway_stop | right_before_left | roundabout
      // roundabout nodes also need: "roundabout": {"radiusM", "lanes", "laneWidthM", "speedLimitKmh"}
      {"id": "n", "x": 0, "y": 250}
    ],
    "roads": [
      {"id": "rn", "from": "n", "to": "c", "shape": [[x, y], ...],     // intermediate points only
       "laneWidthM": 3.65, "speedLimitKmh": 60, "priority": 3,         // priority optional
       "forward":  {"lanes": 2, "leftBay": {"lanes": 1, "lengthM": 60}, "rightBay": null},
       "backward": {"lanes": 2}}
    ]
  },
  "signals": {"cycleTimeS": 90, "yellowTimeS": null, "allRedTimeS": 0, "layout": "opposites", "leftTurnGreenS": 6},
  "demand": {
    "source": "observed",              // observed | assumed – printed on every result
    "sourceNote": "manual count 07:00-08:00",
    "arrivals": "poisson",             // poisson | uniform
    "origins": [
      {"node": "n", "flowVehPerHour": 600, "mix": {"car": 0.9, "truck": 0.08, "bus": 0.02},
       "destinations": [{"node": "s", "share": 0.6}, {"node": "e", "share": 0.2}, {"node": "w", "share": 0.2}]}
    ]
  },
  "drivers": {"carFollowModel": "EIDM", "heterogeneity": true, "impatience": 0.5, "stopSignFullStop": false,
              "reactionTimeMinS": 0.5, "reactionTimeMaxS": 1.0},
  "run": {"durationS": 3600, "warmupS": 600, "stepLengthS": 0.2, "replications": 5, "baseSeed": 1,
          "trajectory": {"enabled": true, "periodS": 0.4, "beginS": 600, "maxDurationS": 900}}
}
```

Ids: `[A-Za-z0-9][A-Za-z0-9_-]{0,63}` without `__` (reserved for generated SUMO ids).

## Result (inside the `done` status)

- `summary.<metric>`: `{mean, sd, ci95: [lo, hi], n, values: [per replication]}`. Metrics:
  - delay: `avgDelayS`, `avgTimeLossS`, `avgEntryDelayS`, `avgDelayInclUnfinishedS`
  - trips: `avgTravelTimeS`, `avgSpeedKmh`, `avgStops`
  - volume: `throughputVehPerHour`, `vehiclesCompleted`
  - queues: `maxQueueM`, `worstApproachAvgQueueM`, `worstApproachP95QueueM`
  - completion: `unfinishedShare`
- `nodes[]`: per junction delay, throughput, control and indicative `los`.
- `approaches[]`: per approach delay, average / 95th-percentile / maximum queue,
  throughput, `los`, lanes at the stop line and modelled length.
- `movements[]`: per origin → destination vehicles, delay, travel time, stops.
- `lanes[]`: mean speed, speed ratio, occupancy (heat map).
- `warnings[]`: `{code, severity: high|medium|info, en, ar}`.
- `reliability`: `{calibrated, level: indicative|low, en, ar}`.
- `assumptions[]`: `{en, ar}`; `definitions`: metric definitions.
- `engine`, `run` (seeds, warm-up, demand source), `engineCounters` (SUMO statistics),
  `requestHash`.

## Trajectory

```jsonc
{"periodS": 0.4, "beginS": 600, "endS": 1500, "stride": 5,
 "fields": ["vehicle", "x", "y", "angleDeg", "speedMs"],   // x,y = front bumper; angle clockwise from north
 "vehicles": [{"id": "o0_d1_car.3", "cls": "car", "length": 5.0, "width": 1.8}],
 "times": [600.0, 600.4, ...],
 "frames": [[0, 12.3, -4.1, 90.0, 13.2, 1, ...], ...],
 "signals": [{"t": 600.0, "tl": "c", "state": "GGgrrrGGgrrr"}, ...]}
```
