from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from sqlalchemy import select

from ai_sre.database import SessionLocal
from ai_sre.models import Incident

app = FastAPI(title="AI SRE Platform")


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.post("/webhooks/alertmanager")
def receive_alert(payload: dict[str, Any]):
    alerts = payload.get("alerts", [])

    if not isinstance(alerts, list):
        raise HTTPException(
            status_code=400,
            detail="Invalid Alertmanager payload: alerts must be a list",
        )

    created_incidents = []

    with SessionLocal() as session:
        for alert in alerts:
            labels = alert.get("labels", {})
            annotations = alert.get("annotations", {})

            starts_at = alert.get("startsAt")

            incident = Incident(
                id=str(uuid4()),
                alert_status=alert.get("status", "unknown"),
                incident_status="open",
                alertname=labels.get("alertname", "Unknown"),
                severity=labels.get("severity", "unknown"),
                namespace=labels.get("namespace", "unknown"),
                summary=annotations.get("summary", ""),
                starts_at=(
                    datetime.fromisoformat(starts_at.replace("Z", "+00:00"))
                    if starts_at
                    else None
                ),
                created_at=datetime.now(UTC),
            )

            session.add(incident)
            created_incidents.append(incident)

        session.commit()

        for incident in created_incidents:
            session.refresh(incident)

        return {
            "status": "received",
            "incidents_created": len(created_incidents),
            "incidents": [
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
                for incident in created_incidents
            ],
        }


@app.get("/incidents")
def list_incidents():
    with SessionLocal() as session:
        incidents = session.scalars(
            select(Incident).order_by(Incident.created_at.desc())
        ).all()

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
def get_incident(incident_id: str):
    with SessionLocal() as session:
        incident = session.get(Incident, incident_id)

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
    payload: dict[str, str],
):
    valid_statuses = {"open", "investigating", "resolved"}
    new_status = payload.get("status")

    if new_status not in valid_statuses:
        raise HTTPException(
            status_code=400,
            detail="Invalid incident status",
        )

    with SessionLocal() as session:
        incident = session.get(Incident, incident_id)

        if incident is None:
            raise HTTPException(
                status_code=404,
                detail="Incident not found",
            )

        incident.incident_status = new_status
        incident.updated_at = datetime.now(UTC)

        session.commit()
        session.refresh(incident)

        return {
            "id": incident.id,
            "incident_status": incident.incident_status,
            "updated_at": incident.updated_at,
        }
