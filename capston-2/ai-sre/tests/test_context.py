from datetime import UTC, datetime
from uuid import uuid4

from ai_sre.models import Incident, Investigation
from ai_sre.worker.context import build_investigation_context


def test_build_investigation_context(db_session):
    incident = Incident(
        id=str(uuid4()),
        fingerprint="test-fingerprint",
        alert_status="firing",
        incident_status="investigating",
        alertname="HighCPUUsage",
        severity="critical",
        namespace="microchat-prod",
        summary="CPU usage exceeded 90%",
        starts_at=datetime.now(UTC),
        created_at=datetime.now(UTC),
    )

    investigation = Investigation(
        id=str(uuid4()),
        status="running",
    )

    incident.investigations.append(investigation)

    db_session.add(incident)
    db_session.commit()

    context = build_investigation_context(
        db_session,
        investigation.id,
    )

    assert context.investigation_id == investigation.id

    assert context.incident.incident_id == incident.id
    assert context.incident.alertname == "HighCPUUsage"
    assert context.incident.severity == "critical"
    assert context.incident.namespace == "microchat-prod"
    assert context.incident.summary == "CPU usage exceeded 90%"
    assert context.incident.status == "investigating"
    assert context.incident.fingerprint == "test-fingerprint"

    assert context.environment.platform is None
    assert context.environment.environment is None
    assert context.environment.cluster is None
    assert context.environment.service is None

    assert context.capabilities == []
