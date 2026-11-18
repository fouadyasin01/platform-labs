from datetime import UTC, datetime
from uuid import uuid4

from ai_sre.models import Incident, Investigation


def create_incident(client):
    payload = {
        "receiver": "ai-sre",
        "status": "firing",
        "alerts": [
            {
                "status": "firing",
                "labels": {
                    "alertname": "HighCPUUsage",
                    "severity": "critical",
                    "namespace": "microchat-prod",
                },
                "annotations": {
                    "summary": "High CPU usage detected",
                },
                "startsAt": "2026-11-15T22:00:00Z",
                "fingerprint": "incident-api-test-001",
            }
        ],
    }

    response = client.post("/webhooks/alertmanager", json=payload)
    assert response.status_code == 200

    return response.json()["incident_ids"][0]


def test_list_incidents(client):
    incident_id = create_incident(client)

    response = client.get("/incidents")

    assert response.status_code == 200
    assert isinstance(response.json(), list)
    assert any(item["id"] == incident_id for item in response.json())


def test_get_incident(client):
    incident_id = create_incident(client)

    response = client.get(f"/incidents/{incident_id}")

    assert response.status_code == 200
    assert response.json()["id"] == incident_id
    assert response.json()["alertname"] == "HighCPUUsage"


def test_get_nonexistent_incident(client):
    response = client.get("/incidents/nonexistent-id")

    assert response.status_code == 404


def test_update_incident_status(client):
    incident_id = create_incident(client)

    response = client.patch(
        f"/incidents/{incident_id}/status",
        json={"status": "investigating"},
    )

    assert response.status_code == 200
    assert response.json()["incident_status"] == "investigating"


def test_update_incident_with_invalid_status(client):
    incident_id = create_incident(client)

    response = client.patch(
        f"/incidents/{incident_id}/status",
        json={"status": "invalid"},
    )

    assert response.status_code == 422


def test_update_nonexistent_incident(client):
    response = client.patch(
        "/incidents/nonexistent-id/status",
        json={"status": "resolved"},
    )

    assert response.status_code == 404


def test_incident_can_have_multiple_investigations(db_session):
    incident = Incident(
        id=str(uuid4()),
        fingerprint=str(uuid4()),
        alert_status="firing",
        incident_status="investigating",
        alertname="HighCPUUsage",
        severity="critical",
        namespace="microchat-prod",
        summary="High CPU usage detected",
        starts_at=datetime.now(UTC),
        created_at=datetime.now(UTC),
    )

    investigation_1 = Investigation(
        id=str(uuid4()),
        status="completed",
        findings={"observation": "CPU usage is above 90%"},
        root_cause="Possible CPU-intensive workload",
        confidence=0.65,
    )

    investigation_2 = Investigation(
        id=str(uuid4()),
        status="completed",
        findings={"observation": "Excessive API requests detected"},
        root_cause="Excessive incoming requests",
        confidence=0.92,
    )

    incident.investigations = [investigation_1, investigation_2]

    db_session.add(incident)
    db_session.commit()

    incident_id = incident.id

    # Force SQLAlchemy to reload the relationship from the database.
    db_session.expire(incident, ["investigations"])

    saved_incident = db_session.get(Incident, incident_id)

    assert saved_incident is not None
    assert len(saved_incident.investigations) == 2

    assert {
        investigation.root_cause for investigation in saved_incident.investigations
    } == {
        "Possible CPU-intensive workload",
        "Excessive incoming requests",
    }
