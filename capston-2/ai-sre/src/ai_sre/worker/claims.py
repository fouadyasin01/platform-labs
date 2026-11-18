from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from ai_sre.models import Investigation


def claim_next_investigation(db: Session) -> Investigation | None:
    statement = (
        select(Investigation)
        .where(Investigation.status == "pending")
        .order_by(Investigation.created_at.asc())
        .limit(1)
        .with_for_update(skip_locked=True)
    )

    investigation = db.scalar(statement)

    if investigation is None:
        return None

    investigation.status = "running"
    investigation.started_at = datetime.now(UTC)

    db.commit()
    db.refresh(investigation)

    return investigation
