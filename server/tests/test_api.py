from __future__ import annotations

import time

import pytest
from fastapi.testclient import TestClient

from roadflow_server import main


@pytest.fixture
def client(manager, monkeypatch):
    monkeypatch.setattr(main, "manager", manager)
    monkeypatch.setattr(main, "API_TOKEN", None)
    return TestClient(main.app)


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok" and body["schemaVersion"] == 1
    assert body["engine"]["version"]


def test_build_returns_geometry(client, fixture_data):
    data = fixture_data("four_way_signalized")
    r = client.post("/v1/networks/build", json={"network": data["network"], "signals": data["signals"]})
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body["geometry"]["lanes"]) > 10
    assert body["geometry"]["tlPrograms"][0]["phases"]
    assert {a["road"] for a in body["approaches"]} == {"rn", "rs", "re", "rw"}


def test_build_reports_design_errors(client, fixture_data):
    data = fixture_data("roundabout_two_lane")
    data["network"]["nodes"][0]["roundabout"]["radiusM"] = 140  # larger than the 250 m arms allow with spacing
    data["network"]["nodes"][1]["y"] = 100
    r = client.post("/v1/networks/build", json={"network": data["network"]})
    assert r.status_code == 422
    assert "roundabout" in str(r.json())


def test_simulation_lifecycle(client, fixture_data):
    data = fixture_data("t_junction_stop")
    data["run"]["replications"] = 2
    r = client.post("/v1/simulations", json=data)
    assert r.status_code == 202, r.text
    job_id = r.json()["jobId"]
    deadline = time.time() + 120
    while time.time() < deadline:
        body = client.get(f"/v1/simulations/{job_id}").json()
        if body["status"] in ("done", "failed"):
            break
        time.sleep(0.3)
    assert body["status"] == "done", body
    assert body["result"]["summary"]["avgDelayS"]["n"] == 2
    net = client.get(f"/v1/simulations/{job_id}/network")
    traj = client.get(f"/v1/simulations/{job_id}/trajectory", headers={"Accept-Encoding": "gzip"})
    assert net.status_code == 200 and traj.status_code == 200
    assert traj.json()["frames"]
    assert client.delete(f"/v1/simulations/{job_id}").status_code == 204
    assert client.get(f"/v1/simulations/{job_id}").status_code == 404


def test_invalid_request_is_rejected(client, fixture_data):
    data = fixture_data("t_junction_stop")
    data["demand"]["origins"][0]["destinations"][0]["share"] = 0.3
    r = client.post("/v1/simulations", json=data)
    assert r.status_code == 422


def test_token_required_when_configured(client, monkeypatch, fixture_data):
    monkeypatch.setattr(main, "API_TOKEN", "s3cret")
    data = fixture_data("t_junction_stop")
    assert client.post("/v1/networks/build", json={"network": data["network"]}).status_code == 401
    bad = {"Authorization": "Bearer nope"}
    assert client.post("/v1/networks/build", json={"network": data["network"]}, headers=bad).status_code == 401
    ok = {"Authorization": "Bearer s3cret"}
    assert client.post("/v1/networks/build", json={"network": data["network"]}, headers=ok).status_code == 200
    assert client.get("/health").json()["authRequired"] is True
