"""HTTP API of the RoadFlow AI simulation server.

Run locally:  uvicorn roadflow_server.main:app --host 0.0.0.0 --port 8000
Configuration (environment variables):
  ROADFLOW_API_TOKEN       if set, every /v1 request needs "Authorization: Bearer <token>"
  ROADFLOW_DATA_DIR        job working directory (default ./data)
  ROADFLOW_JOB_WORKERS     simulations processed concurrently (default 1)
  ROADFLOW_PARALLEL_REPS   SUMO processes per simulation (default: CPU count)
  ROADFLOW_CORS_ORIGINS    comma-separated origins allowed by CORS (default "*")
In production put the server behind a TLS-terminating reverse proxy (HTTPS only).
"""

from __future__ import annotations

import hmac
import os
from pathlib import Path

from fastapi import Depends, FastAPI, Header, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import FileResponse

from . import __version__, sumo_tools
from .jobs import JobManager
from .network_builder import NetworkBuildError
from .schemas import SCHEMA_VERSION, BuildRequest, SimulationRequest


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except ValueError:
        return default


API_TOKEN = os.environ.get("ROADFLOW_API_TOKEN") or None
manager = JobManager(
    Path(os.environ.get("ROADFLOW_DATA_DIR", "data")).resolve(),
    workers=_env_int("ROADFLOW_JOB_WORKERS", 1),
    parallel_replications=_env_int("ROADFLOW_PARALLEL_REPS", os.cpu_count() or 2),
)

app = FastAPI(title="RoadFlow AI simulation server", version=__version__)
app.add_middleware(GZipMiddleware, minimum_size=2048)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in os.environ.get("ROADFLOW_CORS_ORIGINS", "*").split(",") if o.strip()],
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


def require_token(authorization: str | None = Header(default=None)) -> None:
    if API_TOKEN is None:
        return
    expected = f"Bearer {API_TOKEN}"
    if not authorization or not hmac.compare_digest(authorization.encode(), expected.encode()):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "missing or invalid API token")


@app.get("/health")
def health() -> dict:
    try:
        engine = sumo_tools.version()
        ok = True
    except Exception as e:  # noqa: BLE001
        engine, ok = str(e), False
    return {
        "status": "ok" if ok else "degraded",
        "server": __version__,
        "schemaVersion": SCHEMA_VERSION,
        "engine": {"name": "Eclipse SUMO", "version": engine},
        "authRequired": API_TOKEN is not None,
    }


@app.post("/v1/networks/build", dependencies=[Depends(require_token)])
def build_network(req: BuildRequest) -> dict:
    """Validate a design by building it with netconvert; returns the generated lane geometry and signal plans."""
    try:
        return manager.build_only(req)
    except NetworkBuildError as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, {"errors": e.messages}) from e


@app.post("/v1/simulations", status_code=status.HTTP_202_ACCEPTED, dependencies=[Depends(require_token)])
def create_simulation(req: SimulationRequest) -> dict:
    try:
        job = manager.submit(req)
    except RuntimeError as e:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, str(e)) from e
    return job.public()


def _job(job_id: str):
    job = manager.get(job_id)
    if job is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "unknown job")
    return job


@app.get("/v1/simulations/{job_id}", dependencies=[Depends(require_token)])
def get_simulation(job_id: str) -> dict:
    return _job(job_id).public()


def _artefact(job_id: str, name: str) -> FileResponse:
    job = _job(job_id)
    if job.status != "done":
        raise HTTPException(status.HTTP_409_CONFLICT, f"job is {job.status}")
    path = manager.artefact(job, name)
    if path is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"{name} not available for this job")
    return FileResponse(path, media_type="application/json")


@app.get("/v1/simulations/{job_id}/network", dependencies=[Depends(require_token)])
def get_network(job_id: str) -> FileResponse:
    return _artefact(job_id, "network.json")


@app.get("/v1/simulations/{job_id}/trajectory", dependencies=[Depends(require_token)])
def get_trajectory(job_id: str) -> FileResponse:
    return _artefact(job_id, "trajectory.json")


@app.delete("/v1/simulations/{job_id}", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(require_token)])
def delete_simulation(job_id: str) -> None:
    if not manager.delete(job_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "unknown job")
