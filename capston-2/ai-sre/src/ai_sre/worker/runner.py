import time
from collections.abc import Callable
from datetime import UTC, datetime

from sqlalchemy.orm import Session, sessionmaker

from ai_sre.models import Investigation
from ai_sre.schemas import InvestigationContext
from ai_sre.worker.claims import claim_next_investigation
from ai_sre.worker.context import build_investigation_context

InvestigationProcessor = Callable[[InvestigationContext], dict]


def run_once(
    session_factory: sessionmaker[Session],
    processor: InvestigationProcessor,
) -> bool:
    # 1. Claim investigation and build context using a short-lived DB session
    with session_factory() as db:
        investigation = claim_next_investigation(db)

        if investigation is None:
            return False

        investigation_id = investigation.id

        context = build_investigation_context(db, investigation_id)

    # Database session is now closed.
    # The processor receives a validated context, not an ORM object.

    try:
        result = processor(context)

        # 2. Open a new session to persist successful results
        with session_factory() as db:
            investigation = db.get(Investigation, investigation_id)

            if investigation is None:
                return True

            investigation.findings = result.get("findings", {})
            investigation.root_cause = result.get("root_cause")
            investigation.confidence = result.get("confidence")
            investigation.recommendation = result.get("recommendation")
            investigation.status = "completed"
            investigation.completed_at = datetime.now(UTC)

            db.commit()

    except Exception as exc:
        # 3. Open a separate session to persist failure
        with session_factory() as db:
            investigation = db.get(Investigation, investigation_id)

            if investigation is not None:
                investigation.status = "failed"
                investigation.error_message = str(exc)
                investigation.completed_at = datetime.now(UTC)

                db.commit()

    return True


def run_worker(
    session_factory: sessionmaker[Session],
    processor: InvestigationProcessor,
    poll_interval: float = 5.0,
) -> None:
    while True:
        processed = run_once(session_factory, processor)

        if not processed:
            time.sleep(poll_interval)
