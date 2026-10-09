# Roadmap and feature status / خارطة الطريق وحالة الميزات

Legend: ✅ working and tested · 🟡 partial (limits stated) · ⬜ not started

The app never shows a feature that does not work. Items marked ⬜ are absent from the
UI.

## Phases

| Phase | Scope | Status |
|---|---|---|
| 1 | Tablet app, 2D road editor, junction design, lanes, real simulation engine, delay / queue / throughput | ✅ **delivered** |
| 2 | Time-varying demand and data import, signal phase editor, analytics (v/c, congestion duration, per-lane tables), scenario comparison view, PDF/Excel reports | ⬜ next |
| 3 | 3D view linked to the simulation (vehicles, signals, bridges/tunnels, day/night, weather), camera modes | ⬜ |
| 4 | AI assistant: bottleneck diagnosis and testable design proposals with uncertainty, each verified by simulation | ⬜ |
| 5 | Maps (OSM import, search, GIS/CAD import), PostGIS, local standards checks, performance work | ⬜ |

## Detailed status against the requirements

### 1. Platform
| Item | Status | Notes |
|---|---|---|
| Flutter app for Android tablets and iPad | ✅ | CI builds a release APK and an unsigned iOS app. Not yet tested on physical devices. |
| Multi-touch and stylus | ✅ | Two-finger pan/zoom; pen-only drawing mode |
| 3D rendering engine | ⬜ | Phase 3 |
| SUMO as the traffic engine | ✅ | SUMO 1.28 |
| Python server with a secure API | ✅ | FastAPI, token auth, strict validation. C++ not needed so far. |
| PostgreSQL/PostGIS | ⬜ | Phase 5. Server jobs are file-based for now. |
| Local storage and offline design | ✅ | JSON files with atomic writes and `.bak` recovery (not an SQL database yet) |
| Heavy simulation on the server | ✅ | |
| Arabic and English | ✅ | Arabic default (RTL), one-tap switch |
| Landscape layout | ✅ | Locked on Android and iPad |
| Engine separated from display | ✅ | Playback draws SUMO output only |

### 2. Street and road design tools
| Item | Status | Notes |
|---|---|---|
| Draw with finger or pen; straight and curved roads | ✅ | Road tool (straight, 15° angle snap) and Curve tool (freehand, smoothed) |
| One-way or two-way; lanes per direction; lane width | ✅ | |
| 3- and 4-leg junctions | ✅ | Created automatically where roads meet or cross; templates |
| Roundabouts of any size, multi-lane | ✅ | Radius, lanes, lane width, speed |
| Bridges and tunnels | 🟡 | Grade-separated crossings (no junction) and node elevations. 3D structures and clearances in phase 3. |
| Entrances/exits, acceleration/deceleration lanes | 🟡 | Can be drawn as merging/diverging roads and lane-count changes at split nodes. No dedicated ramp or taper tool yet. |
| Left/right turn lanes | ✅ | Turn bays with storage length to the stop line |
| U-turns | 🟡 | Allowed/forbidden per variant. Dedicated U-turn lanes or median openings not yet. |
| Service roads | 🟡 | Drawn as ordinary roads |
| Sidewalks and pedestrian crossings | ⬜ | Phase 2/3 together with pedestrian simulation |
| Speed limits | ✅ | Per road and per roundabout |
| Traffic signals | ✅ | Fixed-time plans generated from cycle / yellow / all-red / protected-left / layout. Phase editor in phase 2. |
| Traffic signs | 🟡 | Stop / give-way / all-way stop through junction control. Other signs ⬜. |
| Elevations and grades | 🟡 | Node elevation; grade shown per road |
| Measure distance, angle, area | ✅ | Measure tool |
| Drag-and-drop editing; undo/redo | ✅ | Nodes and curve points; 200-step history |
| Measuring grid and smart snapping | ✅ | Adaptive grid, node/road snapping, angle snap |

### 3. Real maps and import — ⬜ phase 5
- Search, map display, licensed import (OSM)
- Editing imported roads
- Original-vs-modified comparison
- 3D surroundings

The data model already supports variants (original vs modified).

### 4. Microscopic simulator
| Item | Status |
|---|---|
| Realistic acceleration/deceleration; reaction-time and headway differences | ✅ EIDM + driver profiles |
| Lane changing; junction entry/exit; roundabouts; merging | ✅ SUMO LC2013 / junction model (benchmarked, see VALIDATION.md) |
| Heavy vehicles; speed differences; signals; queue formation; spillback | ✅ |
| Incidents and lane closures | ⬜ phase 2 |
| Weather effects | ⬜ phase 3 |
| Buses | 🟡 As a vehicle class. Stops and routes ⬜. |
| Emergency vehicles; pedestrians at crossings | ⬜ |
| Calibration with real data | ⬜ Parameters exposed; calibration workflow in phase 2/5 |

### 5. Traffic demand
| Item | Status |
|---|---|
| veh/h, % cars / trucks / buses, directions, turning ratios | ✅ |
| Real vs assumed data, with the difference explained | ✅ Labelled through to the results |
| Average speed | 🟡 Via speed limits and the speed-factor distribution |
| Peak periods / time-varying demand; growth rates | ⬜ phase 2 |
| Simulation duration | ✅ |

### 6–7. Visualisation and simulation control
| Item | Status |
|---|---|
| 2D playback of SUMO trajectories with signal states, heat map, vehicle following | ✅ |
| 3D scene and camera modes (driver view, intersection camera…) | ⬜ phase 3 |
| Play, pause, resume, restart, speed ×0.25–×16, seek, step, replay; results saved with the project | ✅ These act on the recorded run. Live control of a running engine ⬜. |
| Change demand / signals / roads and re-run | ✅ Results are flagged "outdated" until re-run |

### 8. Analysis
| Item | Status |
|---|---|
| Travel time, delay, speed, throughput, queue lengths, stops | ✅ with 95 % CI |
| Per approach / per junction, LOS (HCM 6, indicative) | ✅ |
| Per lane | 🟡 In the heat map and result data; table ⬜ |
| Congestion duration; capacity utilisation (v/c) | ⬜ phase 2 |
| Before/after comparison | 🟡 Variants share seeds; comparison view ⬜ phase 2 |
| Congestion heat map | ✅ |

### 9. AI assistant — ⬜ phase 4
Every suggestion must be tested by simulation and stated with its uncertainty.

### 10. Design comparison
🟡 Multiple variants per project (duplicate / rename / switch). Automatic equal-condition
runs and a ranking view are phase 2.

### 11. Qatar settings
| Item | Status |
|---|---|
| Right-hand traffic; multi-lane roundabouts; expressways and service roads as roads | ✅ / 🟡 |
| Local signs and markings; Ashghal / QHDM design rules | ⬜ Requires the official documents. **No regulatory values are assumed.** Editor defaults are labelled as not being standards. |

### 12. Accuracy and verification
| Item | Status |
|---|---|
| Multiple seeds, CIs, documented assumptions, reliability statement | ✅ |
| Benchmarks against Webster / HCM | ✅ [VALIDATION.md](VALIDATION.md) |
| Calibration and comparison with observed counts, travel times and queues; error metrics (GEH etc.) | ⬜ phase 2/5 |
| Sensitivity tests | 🟡 Manual, through variants |
| Reliability report (PDF) | ⬜ phase 2 |

### 13–15. UI, files, performance
| Item | Status |
|---|---|
| Large canvas, hideable panel, properties, simulation, results, project list | ✅ |
| Map layer manager; comparison tool | ⬜ |
| Autosave, crash-safe storage | ✅ |
| CSV export of results | ✅ |
| PDF / Excel / GeoJSON / DXF / OpenDRIVE / LandXML; bilingual reports | ⬜ phase 2 and 5 |
| Level of detail | 🟡 Markings hidden when zoomed out |
| Device performance testing | ⬜ needs physical tablets |
