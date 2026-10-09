from __future__ import annotations

import copy
import json
import time
from pathlib import Path

import pytest

from roadflow_server.jobs import Job, JobManager
from roadflow_server.schemas import SimulationRequest

FIXTURES = Path(__file__).resolve().parents[2] / "shared" / "fixtures"


def load_fixture(name: str) -> dict:
    return json.loads((FIXTURES / f"{name}.json").read_text(encoding="utf-8"))


@pytest.fixture
def fixture_data():
    return lambda name: copy.deepcopy(load_fixture(name))


@pytest.fixture
def manager(tmp_path) -> JobManager:
    return JobManager(tmp_path / "jobs", parallel_replications=4)


@pytest.fixture
def run_sync(manager):
    """Run the full pipeline synchronously and return the finished job."""

    def _run(data: dict) -> Job:
        req = SimulationRequest.model_validate(data)
        job = Job(id=f"t{time.time_ns()}", created=time.time(), request=req, workdir=manager.root / f"t{time.time_ns()}")
        manager._run(job)
        return job

    return _run
