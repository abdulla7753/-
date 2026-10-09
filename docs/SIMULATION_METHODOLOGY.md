# Simulation methodology / منهجية المحاكاة

Every result in RoadFlow AI comes from a microscopic simulation run on the server.
Nothing is pre-scripted or estimated in the app. This document defines what is
simulated and how each reported number is computed.

## 1. Engine

- **Eclipse SUMO 1.28.0** (microscopic, time-step based, open source, EPL-2.0).
  The version used is stored in every result.
- Every vehicle is simulated individually. The tablet only *replays* SUMO's
  floating-car data; the rendering never influences the computation.

## 2. From drawing to SUMO network

| Editor concept | SUMO representation |
|---|---|
| Node (junction / road end) | `node` with type `priority`, `priority_stop`, `traffic_light`, `allway_stop` or `right_before_left` |
| Road with forward/backward lanes | One edge per direction (`<road>__f`, `<road>__b`); two-way roads use `spreadType=right`, one-way roads `center` |
| Turn bay | The direction is split into pieces; the downstream piece has extra lanes. Explicit lane connections keep through lanes, branch right bays from the rightmost lane and left bays from the leftmost. The built storage length matches the request **to the stop line** within 1 m (two-pass build). |
| Roundabout node | Ring nodes where each road crosses the circle; one-way ring edges, counter-clockwise for right-hand traffic and clockwise for left-hand; a SUMO `roundabout` declaration gives circulating traffic priority |
| Grade-separated crossing | Roads drawn with "junctions at crossings" off cross without a node, so they do not interact |
| Elevation | Node `z` is passed to SUMO |

netconvert generates lane-to-movement assignments and the fixed-time signal plans,
with these options:
- cycle time
- yellow time (or derived from approach speed)
- all-red time
- protected-left green time
- layout: `opposites` or `incoming`

The plan actually used is returned with the results and shown during playback.

## 3. Traffic demand

- Origins and destinations are road ends. A share matrix per origin defines the
  turning movements.
- Each origin–destination–class combination is a SUMO flow with **Poisson arrivals**
  (exponential headways) or uniform headways. SUMO routes vehicles along the fastest
  path.
- The vehicle mix is car / truck / bus. Class dimensions and acceleration are SUMO's
  documented defaults:
  - car: 5.0 m, 2.6 m/s²
  - truck: 7.1 m, 1.3 m/s²
  - bus: 12 m, 1.2 m/s²
- The demand **source is recorded** as *observed* or *assumed* and is printed on
  every result. Template projects use explicitly assumed demand.

## 4. Driver behaviour

- **Car following:** EIDM by default (Extended Intelligent Driver Model: IDM plus
  reaction time, estimation errors and jerk limits). IDM and Krauss are selectable.
- **Heterogeneity:** 10 driver profiles per class are sampled per seed:
  - desired headway τ: mean 1.0 s, CV 0.2
  - acceleration: CV 0.1; deceleration: CV 0.1
  - standstill gap: CV 0.2
  - reaction interval: 0.5–1.0 s
  - speed factor: N(1, 0.1)

  These spreads are **assumptions** and are listed in every result. With action-step
  reaction times, τ is bounded below by the reaction time to avoid unsafe following.
- **Lane changing:** SUMO LC2013.
- **Gap acceptance:** SUMO junction model with base impatience 0.5. Stop signs use
  give-way gap behaviour unless "strict full stop" is enabled. These values come from
  the benchmarks in [VALIDATION.md](VALIDATION.md); they are not local calibration.

## 5. Run design

- **Warm-up** (default 10 min) fills the network and is excluded from all statistics.
- **Replications** (default 5) use seeds `baseSeed … baseSeed+n-1`. Using the same
  seeds for two design variants (common random numbers) makes their comparison
  sharper.
- **Time step:** 0.2 s by default; EIDM requires ≤ 0.5 s.

## 6. Measures of effectiveness

| Measure | Definition |
|---|---|
| Average delay | Mean of (SUMO `timeLoss` + `departDelay`) over **measured** completed vehicles: time lost against driving the route at the vehicle's desired speed, plus time spent waiting to enter the network. |
| Measured vehicles | Scheduled departure after the warm-up and at least two 90th-percentile trip durations before the end (capped at half the window). This stops late starters from being counted as stuck. |
| Travel time | Insertion to arrival. |
| Average speed | Space-mean speed: total distance / total travel time. |
| Stops | SUMO `waitingCount`: times the speed fell to ≤ 0.1 m/s. |
| Throughput | Vehicles arriving during the measurement window, per hour. |
| Approach delay | Time loss on the approach pieces (incl. bays) plus inside the junction, divided by vehicles discharged. Acceleration after the junction exit is excluded. |
| Queue | Contiguous back of queue from the stop line: a vehicle is queued below 5 km/h until it exceeds 10 km/h, with at most 20 m between queued vehicles. Measured per lane at every trajectory sample (1 s, or the playback period), maximised over the approach lanes, and continued into the upstream piece when a piece is full. Reported as mean, 95th percentile and maximum. |
| Intersection delay | Discharge-weighted mean of its approach delays. |
| LOS | **Indicative.** HCM 6th Ed. delay thresholds applied to simulated delay. Signalised: 10/20/35/55/80 s; unsignalised and roundabouts: 10/15/25/35/50 s. Microsimulation delay is not identical to HCM control delay. |
| Lane speed ratio (heat map) | Mean lane speed / lane speed limit over the measurement window. |
| Confidence interval | 95 % Student-t interval of the replication means. |

## 7. Data-quality warnings and reliability

Each run reports:
- teleports (gridlock), collisions, emergency stops and emergency braking
- unfinished trips (> 5 % → over-capacity warning)
- an entry backlog (demand that could not enter)
- queues filling ≥ 90 % of a modelled approach
- CI half-width > 10 % of the mean, or fewer than 5 replications
- assumed demand, and always the uncalibrated status

The reliability label is **indicative** for an uncalibrated model and **low** when
serious run issues occur.

## 8. Not yet modelled (see the [roadmap](ROADMAP.md))

- Pedestrians and crossings
- Incidents and lane closures
- Weather
- Bus stops and emergency-vehicle priority
- Time-varying demand
- Actuated signals
- Calibration against field data
