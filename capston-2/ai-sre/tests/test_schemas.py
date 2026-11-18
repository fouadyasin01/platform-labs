import pytest
from pydantic import ValidationError

from ai_sre.schemas import (
    AlertmanagerWebhook,
    Evidence,
    InvestigationContext,
    InvestigationEnvironment,
    InvestigationIncidentContext,
    InvestigationReport,
    RootCause,
)


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


def test_investigation_context_accepts_valid_data():
    context = InvestigationContext(
        investigation_id="inv-123",
        incident=InvestigationIncidentContext(
            incident_id="inc-123",
            alertname="HighCPUUsage",
            severity="critical",
            namespace="microchat-prod",
            summary="High CPU usage detected",
            status="firing",
        ),
        environment=InvestigationEnvironment(
            platform="kubernetes",
            environment="production",
            cluster="eks-prod",
            service="microchat",
        ),
        capabilities=["metrics", "logs", "kubernetes"],
    )

    assert context.investigation_id == "inv-123"
    assert context.incident.alertname == "HighCPUUsage"
    assert context.environment.cluster == "eks-prod"
    assert "metrics" in context.capabilities


def test_investigation_context_accepts_missing_environment():
    context = InvestigationContext(
        investigation_id="inv-124",
        incident=InvestigationIncidentContext(
            incident_id="inc-124",
            alertname="ServiceUnavailable",
            severity="warning",
            namespace="default",
            summary="Service is unavailable",
            status="firing",
        ),
        capabilities=["metrics", "logs"],
    )

    assert context.environment.platform is None
    assert context.environment.cluster is None
    assert context.environment.service is None
    assert context.capabilities == ["metrics", "logs"]


def test_evidence_accepts_valid_data():
    evidence = Evidence(
        source="prometheus",
        observation="CPU utilization reached 95% for 10 minutes",
        resource="deployment/microchat-api",
    )

    assert evidence.source == "prometheus"
    assert "95%" in evidence.observation
    assert evidence.resource == "deployment/microchat-api"
    assert evidence.timestamp is None


def test_root_cause_accepts_valid_data():
    root_cause = RootCause(
        description="Database connection pool exhaustion caused requests to fail",
        status="probable",
        confidence=0.85,
    )

    assert root_cause.description.startswith("Database connection pool")
    assert root_cause.status == "probable"
    assert root_cause.confidence == 0.85


@pytest.mark.parametrize("confidence", [-0.1, 1.1])
def test_root_cause_rejects_invalid_confidence(confidence):
    with pytest.raises(ValidationError):
        RootCause(
            description="Possible database connection failure",
            status="probable",
            confidence=confidence,
        )


def test_investigation_report_accepts_valid_data():
    report = InvestigationReport(
        summary="High CPU utilization caused API latency.",
        evidence=[
            Evidence(
                source="prometheus",
                observation="CPU utilization reached 95% for 10 minutes",
                resource="deployment/microchat-api",
            ),
            Evidence(
                source="loki",
                observation="Requests started timing out during the CPU spike",
                resource="microchat-api",
            ),
        ],
        root_cause=RootCause(
            description="CPU saturation caused request processing delays",
            status="probable",
            confidence=0.85,
        ),
        recommendation="Investigate CPU-intensive operations and consider scaling.",
    )

    assert report.summary == "High CPU utilization caused API latency."
    assert len(report.evidence) == 2
    assert report.root_cause.status == "probable"
    assert report.recommendation.startswith("Investigate CPU-intensive")
