from sqlalchemy.orm import Session

from ai_sre.models import Investigation
from ai_sre.schemas import (
    InvestigationContext,
    InvestigationIncidentContext,
)


def build_investigation_context(
    db: Session,
    investigation_id: str,
) -> InvestigationContext:
    investigation = db.get(Investigation, investigation_id)

    if investigation is None:
        raise ValueError(f"Investigation {investigation_id} not found")

    incident = investigation.incident

    return InvestigationContext(
        investigation_id=investigation.id,
        incident=InvestigationIncidentContext(
            incident_id=incident.id,
            alertname=incident.alertname,
            severity=incident.severity,
            namespace=incident.namespace,
            summary=incident.summary,
            status=incident.incident_status,
            starts_at=incident.starts_at,
            fingerprint=incident.fingerprint,
        ),
    )
