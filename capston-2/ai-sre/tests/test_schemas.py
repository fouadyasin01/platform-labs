import pytest
from pydantic import ValidationError

from ai_sre.schemas import AlertmanagerWebhook


def make_payload(status: str) -> dict:
    return {
        "receiver": "ai-sre",
        "status": status,
        "alerts": [
            {
                "status": status,
                "startsAt": "2026-11-15T10:00:00Z",
                "endsAt": "2026-11-15T10:15:00Z",
                "fingerprint": "abc123",
                "labels": {
                    "alertname": "HighCPUUsage",
                    "severity": "critical",
                    "namespace": "microchat-prod",
                },
                "annotations": {"summary": "High CPU usage detected"},
            }
        ],
    }


@pytest.mark.parametrize("status", ["firing", "resolved"])
def test_alertmanager_webhook_accepts_valid_status(status):
    webhook = AlertmanagerWebhook.model_validate(make_payload(status))

    assert webhook.status == status
    assert webhook.alerts[0].status == status
    assert webhook.alerts[0].fingerprint == "abc123"


def test_alertmanager_webhook_rejects_invalid_status():
    payload = make_payload("unknown")

    with pytest.raises(ValidationError):
        AlertmanagerWebhook.model_validate(payload)
