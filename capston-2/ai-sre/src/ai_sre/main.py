from datetime import UTC, datetime
from typing import Annotated
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from ai_sre.database import get_db
from ai_sre.models import Incident
from ai_sre.schemas import AlertmanagerWebhook, IncidentStatusUpdate

app = FastAPI(title="AI SRE Platform")


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.post("/webhooks/alertmanager")
def receive_alert(
    payload: AlertmanagerWebhook,
    db: Annotated[Session, Depends(get_db)],
):
    incidents_created = []
    incidents_updated = []
    unmatched_resolved = 0

    for alert in payload.alerts:
        labels = alert.labels
        annotations = alert.annotations
        starts_at = alert.startsAt

        values = {
            "id": str(uuid4()),
            "fingerprint": alert.fingerprint,
            "alert_status": alert.status,
            "incident_status": "open",
            "alertname": labels.get("alertname", "Unknown"),
            "severity": labels.get("severity", "unknown"),
            "namespace": labels.get("namespace", "unknown"),
            "summary": annotations.get("summary", ""),
            "starts_at": starts_at,
            "created_at": datetime.now(UTC),
        }

        if alert.status == "resolved":
            result = db.execute(
                update(Incident)
                .where(
                    Incident.fingerprint == alert.fingerprint,
                    Incident.starts_at == starts_at,
                )
                .values(
                    alert_status="resolved",
                    alertname=values["alertname"],
                    severity=values["severity"],
                    namespace=values["namespace"],
                    summary=values["summary"],
                    updated_at=datetime.now(UTC),
                )
                .returning(Incident.id)
            )

            updated_id = result.scalar_one_or_none()

            if updated_id is not None:
                incidents_updated.append(updated_id)
            else:
                unmatched_resolved += 1

            continue

        statement = (
            insert(Incident)
            .values(**values)
            .on_conflict_do_nothing(constraint="uq_incidents_fingerprint_starts_at")
            .returning(Incident.id)
        )

        inserted_id = db.scalar(statement)

        if inserted_id is not None:
            incidents_created.append(inserted_id)
        else:
            result = db.execute(
                update(Incident)
                .where(
                    Incident.fingerprint == alert.fingerprint,
                    Incident.starts_at == starts_at,
                )
                .values(
                    alert_status=alert.status,
                    alertname=values["alertname"],
                    severity=values["severity"],
                    namespace=values["namespace"],
                    summary=values["summary"],
                    updated_at=datetime.now(UTC),
                )
                .returning(Incident.id)
            )

            updated_id = result.scalar_one_or_none()

            if updated_id is not None:
                incidents_updated.append(updated_id)

    db.commit()

    return {
        "status": "received",
        "incidents_created": len(incidents_created),
        "incidents_updated": len(incidents_updated),
        "unmatched_resolved": unmatched_resolved,
        "incident_ids": incidents_created + incidents_updated,
    }


@app.get("/incidents")
def list_incidents(
    db: Annotated[Session, Depends(get_db)],
):
    incidents = db.scalars(select(Incident).order_by(Incident.created_at.desc())).all()

    return [
        {
            "id": incident.id,
            "alert_status": incident.alert_status,
            "incident_status": incident.incident_status,
            "alertname": incident.alertname,
            "severity": incident.severity,
            "namespace": incident.namespace,
            "summary": incident.summary,
            "starts_at": incident.starts_at,
            "created_at": incident.created_at,
            "updated_at": incident.updated_at,
        }
        for incident in incidents
    ]


@app.get("/incidents/{incident_id}")
def get_incident(
    incident_id: str,
    db: Annotated[Session, Depends(get_db)],
):
    incident = db.get(Incident, incident_id)

    if incident is None:
        raise HTTPException(
            status_code=404,
            detail="Incident not found",
        )

    return {
        "id": incident.id,
        "alert_status": incident.alert_status,
        "incident_status": incident.incident_status,
        "alertname": incident.alertname,
        "severity": incident.severity,
        "namespace": incident.namespace,
        "summary": incident.summary,
        "starts_at": incident.starts_at,
        "created_at": incident.created_at,
        "updated_at": incident.updated_at,
    }


@app.patch("/incidents/{incident_id}/status")
def update_incident_status(
    incident_id: str,
    payload: IncidentStatusUpdate,
    db: Annotated[Session, Depends(get_db)],
):
    new_status = payload.status

    incident = db.get(Incident, incident_id)

    if incident is None:
        raise HTTPException(
            status_code=404,
            detail="Incident not found",
        )

    incident.incident_status = new_status
    incident.updated_at = datetime.now(UTC)

    db.commit()
    db.refresh(incident)

    return {
        "id": incident.id,
        "incident_status": incident.incident_status,
        "updated_at": incident.updated_at,
    }
