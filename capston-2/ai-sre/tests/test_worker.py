from datetime import UTC, datetime, timedelta
from uuid import uuid4

from conftest import TestingSessionLocal
from sqlalchemy import select

from ai_sre.models import Incident, Investigation
from ai_sre.worker.claims import claim_next_investigation
from ai_sre.worker.runner import run_once


def test_claim_next_investigation(db_session):
    incident = Incident(
        id=str(uuid4()),
        alert_status="firing",
        incident_status="open",
        alertname="HighCPUUsage",
        severity="critical",
        namespace="microchat-prod",
        created_at=datetime.now(UTC),
    )

    investigation = Investigation(
        id=str(uuid4()),
        status="pending",
    )

    incident.investigations.append(investigation)

    db_session.add(incident)
    db_session.commit()

    claimed = claim_next_investigation(db_session)

    assert claimed is not None
    assert claimed.id == investigation.id
    assert claimed.status == "running"
    assert claimed.started_at is not None


def test_claim_returns_none_when_no_pending_investigation(db_session):
    claimed = claim_next_investigation(db_session)

    assert claimed is None


def test_worker_skips_investigation_locked_by_another_worker():
    now = datetime.now(UTC)

    incident = Incident(
        id=str(uuid4()),
        alert_status="firing",
        incident_status="open",
        alertname="HighCPUUsage",
        severity="critical",
        namespace="microchat-prod",
        created_at=now,
    )

    first = Investigation(
        id=str(uuid4()),
        status="pending",
        created_at=now,
    )

    second = Investigation(
        id=str(uuid4()),
        status="pending",
        created_at=now + timedelta(seconds=1),
    )

    incident.investigations = [first, second]

    setup_session = TestingSessionLocal()
    worker_a_session = TestingSessionLocal()
    worker_b_session = TestingSessionLocal()

    try:
        setup_session.add(incident)
        setup_session.commit()

        # Worker A locks the oldest pending investigation.
        locked = worker_a_session.scalar(
            select(Investigation)
            .where(Investigation.status == "pending")
            .order_by(Investigation.created_at.asc())
            .limit(1)
            .with_for_update()
        )

        assert locked is not None
        assert locked.id == first.id

        # Worker B must skip the locked investigation.
        claimed = claim_next_investigation(worker_b_session)

        assert claimed is not None
        assert claimed.id == second.id
        assert claimed.id != locked.id

    finally:
        worker_a_session.rollback()
        worker_a_session.close()
        worker_b_session.close()

        setup_session.delete(incident)
        setup_session.commit()
        setup_session.close()


def test_run_once_completes_investigation(db_session):
    incident = Incident(
        id=str(uuid4()),
        alert_status="firing",
        incident_status="open",
        alertname="HighCPUUsage",
        severity="critical",
        namespace="microchat-prod",
        created_at=datetime.now(UTC),
    )

    investigation = Investigation(
        id=str(uuid4()),
        status="pending",
    )

    incident.investigations.append(investigation)
    db_session.add(incident)
    db_session.commit()

    def fake_processor(_investigation):
        return {
            "findings": {"cpu_usage": "95%"},
            "root_cause": "CPU saturation caused by excessive workload",
            "confidence": 0.95,
            "recommendation": "Scale the deployment",
        }

    processed = run_once(db_session, fake_processor)

    db_session.refresh(investigation)

    assert processed is True
    assert investigation.status == "completed"
    assert investigation.findings == {"cpu_usage": "95%"}
    assert investigation.root_cause == "CPU saturation caused by excessive workload"
    assert investigation.confidence == 0.95
    assert investigation.recommendation == "Scale the deployment"
    assert investigation.completed_at is not None


def test_run_once_marks_investigation_failed():
    session = TestingSessionLocal()

    incident = Incident(
        id=str(uuid4()),
        alert_status="firing",
        incident_status="open",
        alertname="HighCPUUsage",
        severity="critical",
        namespace="microchat-prod",
        created_at=datetime.now(UTC),
    )

    investigation = Investigation(
        id=str(uuid4()),
        status="pending",
    )

    investigation_id = investigation.id
    incident.investigations.append(investigation)

    try:
        session.add(incident)
        session.commit()

        def failing_processor(_investigation):
            raise RuntimeError("Prometheus connection failed")

        processed = run_once(session, failing_processor)

        failed_investigation = session.get(Investigation, investigation_id)

        assert processed is True
        assert failed_investigation is not None
        assert failed_investigation.status == "failed"
        assert failed_investigation.error_message == "Prometheus connection failed"
        assert failed_investigation.completed_at is not None

    finally:
        session.delete(incident)
        session.commit()
        session.close()