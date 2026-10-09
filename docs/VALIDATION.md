# Validation and accuracy / التحقق والدقة

> **Status:** the model is **not calibrated** against field data. Every result screen
> says so. The checks below show that the *default configuration* behaves like
> accepted traffic-engineering relationships. They are not a claim of accuracy for
> any real site. No accuracy percentage such as "99 %" is claimed anywhere.

## 1. What is verified automatically

| Layer | How | Where |
|---|---|---|
| Physics plausibility | Free-flow speed equals the speed limit within 10 %; delay and queues rise with demand; vehicles are conserved (`loaded = inserted + waiting`) | `server/tests/test_simulation.py` |
| Reproducibility | The same seed gives identical results, and a different seed gives different results | `test_same_seed_reproduces_and_new_seed_differs` |
| Geometry | Turn bays have the requested storage length measured to the stop line (±1 m); roundabouts circulate counter-clockwise for right-hand traffic and clockwise for left-hand traffic | `test_turn_bay_split_and_lane_connections`, `test_roundabout_circulation_direction` |
| Queue definition | Contiguous back of queue (enter < 5 km/h, leave > 10 km/h, max gap 20 m); spillback into upstream pieces | `server/tests/test_units.py` |
| Over-capacity detection | Entry backlog, unfinished trips and queue spill are flagged; reliability drops to "low" | `test_oversaturation_is_flagged` |
| Benchmarks vs theory | See section 2 | `server/tests/test_benchmarks.py` |
| App ↔ server contract | Shared JSON fixtures are validated by the server and round-tripped by the app; recorded real server responses are parsed by the app | `shared/fixtures`, `app/test/request_contract_test.dart`, `app/test/workspace_flow_test.dart` |
| End-to-end | The real app (web build) drives the real server: create project → simulate → results → playback | `e2e/web_flow.mjs` |

## 2. Benchmarks against textbook relationships

Produced by `python -m roadflow_server.benchmarks` with SUMO 1.28.0, EIDM, the default
driver variability and the defaults described in section 3:

| Benchmark | Condition | Reference | Simulated | Ratio | Reference source |
|---|---|---:|---:|---:|---|
| Signalised approach delay | 200 veh/h/lane, C = 90 s, g ≈ 37 s | 18.4 s/veh | 16.8 s/veh | 0.91 | Webster (1958), saturation flow 1800 veh/h/lane |
| Minor-street capacity (give-way) | major flow 0 veh/h, saturated minor right turn | 1090.9 veh/h | 1028.5 veh/h | 0.94 | HCM 6th Ed. potential capacity, t_c = 6.2 s, t_f = 3.3 s |
| Minor-street capacity (give-way) | major flow 400 veh/h | 654.3 veh/h | 658.5 veh/h | 1.01 | same |
| Minor-street capacity (give-way) | major flow 800 veh/h | 388.1 veh/h | 400.0 veh/h | 1.03 | same |
| Minor-street capacity (stop) | major flow 400 veh/h | 654.3 veh/h | 658.5 veh/h | 1.01 | same |
| Roundabout entry capacity | single lane, circulating 0 veh/h | 1380.0 veh/h | 1365.0 veh/h | 0.99 | HCM 6th Ed. Eq. 22-1 |
| Roundabout entry capacity | circulating 400 veh/h | 917.7 veh/h | 847.5 veh/h | 0.92 | same |
| Roundabout entry capacity | circulating 800 veh/h | 610.2 veh/h | 413.0 veh/h | **0.68** | same |

**Known limitation:** at high circulating flows, single-lane roundabout entries are
conservative (about 30 % below HCM at 800 veh/h circulating). Treat roundabout
capacities near saturation with caution until they are calibrated locally.

## 3. Decisions taken because of these benchmarks

1. **SUMO's default gap acceptance is far too conservative.** With SUMO's defaults
   (`impatience = 0`), minor-street capacity was 15–20 % of HCM and roundabout entry
   capacity 30–64 %. A two-way-stop T-junction that HCM rates around LOS D (~33 s)
   showed delays above 1000 s.
   *Decision:* the default base `impatience` is **0.5** (a documented SUMO vType
   parameter). Higher values over-shot the give-way capacity, by up to 34 % at 0.75.
   The value is editable in the app.
2. **SUMO's strict stop sign** (every vehicle halts) discharges a stop-controlled
   queue at about 45 % of the HCM follow-up rate, even with no conflicting traffic.
   HCM analyses stop and give-way approaches with the same field-calibrated gap
   parameters. *Decision:* by default stop signs use give-way gap behaviour
   (`jmStopSignWait = 0`). "Strict full stop" is a switch in the app.
3. **IDM vs EIDM.** Plain IDM in SUMO produced emergency stops in multi-lane
   roundabouts (34 per test run) and hundreds of emergency-braking events with some
   collisions at stop-controlled junctions. *Decision:* EIDM (Extended IDM, Salles et
   al. 2020) is the default; IDM and Krauss stay selectable. EIDM requires a time step
   ≤ 0.5 s, so the default step is 0.2 s.
4. **SUMO's built-in queue output** measures from the stop line to the *last* slow
   vehicle anywhere on the lane, so a single car starting at the far end reported a
   293 m "queue". *Decision:* queues are measured from vehicle trajectories with the
   contiguous back-of-queue definition above.
5. **Turn-bay length** was first measured from the junction centre. A 60 m bay gave
   only 44.7 m of storage. *Decision:* the network is built twice, and splits are moved
   so the built storage length matches the request to the stop line within 1 m.

## 4. What calibration will add (phases 2 and 5)

Calibration uses observed counts, travel times and queue lengths:
- car-following: headway (tau), reaction time, acceleration
- gap acceptance: impatience, timegaps
- desired speeds

Validation targets, for example GEH < 5 for 85 % of counts and travel times within
±15 %, will be reported per study. Until that exists, results are labelled
**indicative**.

## 5. Re-running

```bash
cd server
pytest -q                                # all tests including benchmarks (~1.5 min)
python -m roadflow_server.benchmarks     # regenerates the table above
```
