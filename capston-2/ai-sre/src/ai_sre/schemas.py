from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class Alert(BaseModel):
    model_config = ConfigDict(extra="allow")

    status: Literal["firing", "resolved"]

    labels: dict[str, str] = Field(default_factory=dict)
    annotations: dict[str, str] = Field(default_factory=dict)

    startsAt: datetime
    endsAt: datetime | None = None

    fingerprint: str
    generatorURL: str | None = None


class AlertmanagerWebhook(BaseModel):
    model_config = ConfigDict(extra="allow")

    receiver: str
    status: Literal["firing", "resolved"]

    alerts: list[Alert]

    groupLabels: dict[str, str] = Field(default_factory=dict)
    commonLabels: dict[str, str] = Field(default_factory=dict)
    externalURL: str | None = None


class IncidentStatusUpdate(BaseModel):
    status: Literal["open", "investigating", "resolved"]
