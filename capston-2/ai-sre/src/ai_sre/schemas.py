from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


# Validates individual alerts received from Alertmanager.
class Alert(BaseModel):
    model_config = ConfigDict(extra="allow")

    status: Literal["firing", "resolved"]

    labels: dict[str, str] = Field(default_factory=dict)
    annotations: dict[str, str] = Field(default_factory=dict)

    startsAt: datetime
    endsAt: datetime | None = None

    fingerprint: str
    generatorURL: str | None = None


# Validates Alertmanager webhook payloads containing grouped alerts.
class AlertmanagerWebhook(BaseModel):
    model_config = ConfigDict(extra="allow")

    receiver: str
    status: Literal["firing", "resolved"]

    alerts: list[Alert]

    groupLabels: dict[str, str] = Field(default_factory=dict)
    commonLabels: dict[str, str] = Field(default_factory=dict)
    externalURL: str | None = None


# Validates requests to update an incident's lifecycle status.
class IncidentStatusUpdate(BaseModel):
    status: Literal["open", "investigating", "resolved"]


# Represents the incident details provided to the AI investigation system.
class InvestigationIncidentContext(BaseModel):
    incident_id: str
    alertname: str
    severity: str
    namespace: str
    summary: str
    status: str
    starts_at: datetime | None = None
    fingerprint: str | None = None


# Provides optional infrastructure and application context for an investigation.
class InvestigationEnvironment(BaseModel):
    platform: str | None = None
    environment: str | None = None
    cluster: str | None = None
    service: str | None = None


# Defines the complete input context and available capabilities for an investigation.
class InvestigationContext(BaseModel):
    investigation_id: str
    incident: InvestigationIncidentContext
    environment: InvestigationEnvironment = Field(
        default_factory=InvestigationEnvironment
    )
    capabilities: list[str] = Field(default_factory=list)


# Represents an observation collected from an operational data source.
class Evidence(BaseModel):
    source: str
    observation: str
    timestamp: datetime | None = None
    resource: str | None = None


# Represents the suspected incident cause, its assessment, and confidence level.
class RootCause(BaseModel):
    description: str
    status: Literal["confirmed", "probable", "unknown"]
    confidence: float = Field(ge=0.0, le=1.0)


# Defines the standardized report returned after an AI investigation completes.
class InvestigationReport(BaseModel):
    summary: str
    evidence: list[Evidence] = Field(default_factory=list)
    root_cause: RootCause
    recommendation: str
