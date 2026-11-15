def test_firing_alert_creates_incident(client):
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
                "fingerprint": "test-firing-001",
            }
        ],
    }

    response = client.post("/webhooks/alertmanager", json=payload)

    assert response.status_code == 200

    data = response.json()

    assert data["incidents_created"] == 1
    assert data["incidents_updated"] == 0
    assert data["unmatched_resolved"] == 0
    assert len(data["incident_ids"]) == 1


def test_repeated_firing_alert_updates_existing_incident(client):
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
                "startsAt": "2026-11-15T22:30:00Z",
                "fingerprint": "test-dedup-001",
            }
        ],
    }

    first_response = client.post(
        "/webhooks/alertmanager",
        json=payload,
    )

    second_response = client.post(
        "/webhooks/alertmanager",
        json=payload,
    )

    assert first_response.status_code == 200
    assert second_response.status_code == 200

    first_data = first_response.json()
    second_data = second_response.json()

    assert first_data["incidents_created"] == 1
    assert second_data["incidents_created"] == 0
    assert second_data["incidents_updated"] == 1

    assert first_data["incident_ids"][0] == second_data["incident_ids"][0]


def test_resolved_alert_updates_existing_incident(client):
    firing_payload = {
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
                "startsAt": "2026-11-15T23:00:00Z",
                "fingerprint": "test-resolved-001",
            }
        ],
    }

    resolved_payload = {
        **firing_payload,
        "status": "resolved",
        "alerts": [
            {
                **firing_payload["alerts"][0],
                "status": "resolved",
                "annotations": {
                    "summary": "High CPU usage recovered",
                },
                "endsAt": "2026-11-15T23:15:00Z",
            }
        ],
    }

    client.post("/webhooks/alertmanager", json=firing_payload)

    response = client.post(
        "/webhooks/alertmanager",
        json=resolved_payload,
    )

    assert response.status_code == 200

    data = response.json()

    assert data["incidents_created"] == 0
    assert data["incidents_updated"] == 1
    assert data["unmatched_resolved"] == 0

    incident_response = client.get(f"/incidents/{data['incident_ids'][0]}")

    incident = incident_response.json()


    assert incident["alert_status"] == "resolved"
    assert incident["incident_status"] == "open"
    assert incident["summary"] == "High CPU usage recovered"


def test_unmatched_resolved_alert_does_not_create_incident(client):
    payload = {
        "receiver": "ai-sre",
        "status": "resolved",
        "alerts": [
            {
                "status": "resolved",
                "labels": {
                    "alertname": "HighMemoryUsage",
                    "severity": "warning",
                    "namespace": "microchat-prod",
                },
                "annotations": {
                    "summary": "Memory usage recovered",
                },
                "startsAt": "2026-11-15T23:30:00Z",
                "endsAt": "2026-11-15T23:45:00Z",
                "fingerprint": "unmatched-resolved-001",
            }
        ],
    }

    response = client.post("/webhooks/alertmanager", json=payload)

    assert response.status_code == 200

    data = response.json()

    assert data["incidents_created"] == 0
    assert data["incidents_updated"] == 0
    assert data["unmatched_resolved"] == 1
    assert data["incident_ids"] == []


def test_new_alert_occurrence_creates_new_incident(client):
    base_payload = {
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
                "fingerprint": "recurring-alert-001",
            }
        ],
    }

    first_payload = {
        **base_payload,
        "alerts": [
            {
                **base_payload["alerts"][0],
                "startsAt": "2026-11-15T20:00:00Z",
            }
        ],
    }

    second_payload = {
        **base_payload,
        "alerts": [
            {
                **base_payload["alerts"][0],
                "startsAt": "2026-11-15T23:00:00Z",
            }
        ],
    }

    first_response = client.post(
        "/webhooks/alertmanager",
        json=first_payload,
    )

    second_response = client.post(
        "/webhooks/alertmanager",
        json=second_payload,
    )

    assert first_response.status_code == 200
    assert second_response.status_code == 200

    first_data = first_response.json()
    second_data = second_response.json()

    assert first_data["incidents_created"] == 1
    assert second_data["incidents_created"] == 1

    assert first_data["incident_ids"][0] != second_data["incident_ids"][0]
