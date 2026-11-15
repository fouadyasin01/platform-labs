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
