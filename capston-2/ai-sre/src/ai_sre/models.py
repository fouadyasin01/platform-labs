from datetime import datetime

from sqlalchemy import (
    DateTime,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from ai_sre.database import Base


class Incident(Base):
    __tablename__ = "incidents"

    __table_args__ = (
        UniqueConstraint(
            "fingerprint",
            "starts_at",
            name="uq_incidents_fingerprint_starts_at",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)

    fingerprint: Mapped[str | None] = mapped_column(String(64), nullable=True)

    alert_status: Mapped[str] = mapped_column(String(30))
    incident_status: Mapped[str] = mapped_column(String(30), default="open")

    alertname: Mapped[str] = mapped_column(String(255))
    severity: Mapped[str] = mapped_column(String(30))
    namespace: Mapped[str] = mapped_column(String(255))

    summary: Mapped[str] = mapped_column(Text, default="")

    starts_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
