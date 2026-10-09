# Architecture / البنية التقنية

```
┌──────────────────────────── Tablet (Android / iPadOS) ────────────────────────────┐
│ Flutter app (app/)                                                                 │
│  ui/        projects · workspace (design | simulation) · panels · 2D playback      │
│  editor/    EditorController (undo/redo, autosave) · network_ops (snap/split/join) │
│  model/     Network · Demand · Settings · Project/Variants · request builder       │
│  services/  ProjectStore (local files, atomic) · SimulationApi (HTTP/JSON)         │
└───────────────────────────────────────┬────────────────────────────────────────────┘
                                        │ HTTPS + bearer token (JSON, gzip)
┌───────────────────────────────────────▼──────── Simulation server (server/) ───────┐
│ FastAPI                                                                            │
│  schemas      validated request contract (pydantic, unknown fields rejected)       │
│  network_builder  editor model → SUMO plain XML → netconvert (2-pass for bays)     │
│  demand       vType distributions (driver heterogeneity) + flows                   │
│  runner       N seeded SUMO processes in parallel                                  │
│  queues/analysis  MOEs from tripinfo, edge/lane data and FCD; CI; warnings         │
│  trajectory   replication-1 FCD + signal states for playback                        │
│  jobs         async job store (per-job working directory, TTL cleanup)             │
└────────────────────────────────────────────────────────────────────────────────────┘
```

## Principles

1. **The computation engine and the display are separate.** SUMO computes everything
   on the server. The tablet draws:
   - the network SUMO actually built (lane shapes from `net.xml`)
   - vehicle positions SUMO wrote (floating-car data)
   - signal states SUMO logged (`SaveTLSStates`)

   Interpolation between 0.4 s samples is visual only and never feeds any statistic.
2. **The design works offline.** Projects live on the device as JSON:
   - atomic writes (temp file + rename) and a `.bak` copy of the previous version
   - autosave 1.2 s after each change, and on leaving the workspace

   Only simulations and server-side validation need the network.
3. **One contract, tested from both sides.** The JSON in `shared/fixtures` is
   validated by the server tests and round-tripped by the app tests. The app also
   parses responses recorded from the real server. See [API.md](API.md).
4. **Coordinates** are local metres (x east, y north) in the editor, SUMO and
   playback (`--offset.disable-normalization`). Geographic referencing (WGS84 ↔
   local) arrives with map import in phase 5.

## Security

- Optional bearer token (`ROADFLOW_API_TOKEN`), compared in constant time.
- Every request is schema-validated with bounded sizes (≤ 2000 nodes, ≤ 4 h simulated,
  ≤ 30 replications); unknown fields are rejected.
- SUMO runs as a subprocess with an argument list (no shell), in a per-job directory.
- Deploy behind a TLS reverse proxy. The app warns when a non-local `http://` server is
  configured. Android allows cleartext only so that on-premises LAN servers can be
  used; iOS allows HTTP to local-network hosts only.

## Scaling

- `ROADFLOW_JOB_WORKERS` sets how many simulations run concurrently.
- `ROADFLOW_PARALLEL_REPS` sets how many SUMO processes each simulation uses.
- Large FCD files are deleted after analysis; only compact JSON artefacts are kept.
- Planned: PostgreSQL/PostGIS for server-side projects and map data (phase 5), and a
  job queue such as Redis or RQ for multi-node compute.

## App structure

| Path | Purpose |
|---|---|
| `lib/core/geometry.dart` | Vectors, polylines, offsets, intersections, smoothing, area |
| `lib/model/` | Immutable data model, JSON, validation, request building |
| `lib/editor/network_ops.dart` | Pure topology operations (unit-tested) |
| `lib/editor/editor_controller.dart` | Editing state, history, variants, autosave |
| `lib/services/` | Storage, settings, HTTP client, simulation orchestration |
| `lib/ui/canvas/` | Viewport and design canvas (gestures, painter) |
| `lib/ui/playback/` | Simulation playback painter and controls |
| `lib/ui/workspace/` | Workspace layout and side panels |
| `lib/l10n/` | Arabic / English strings (generated from `tool/gen_arb.py`) |

## Input handling

- Two fingers always pan and zoom.
- One finger or the pen uses the active tool.
- In **pen-only** mode a single finger pans and only the stylus draws (palm-friendly
  sketching).
- A mouse wheel zooms (useful for desktop testing).
