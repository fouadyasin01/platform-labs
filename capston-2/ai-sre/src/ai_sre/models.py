from datetime import UTC, datetime

from sqlalchemy import (
    DateTime,
    Float,
    ForeignKey,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

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

    investigations: Mapped[list["Investigation"]] = relationship(
        back_populates="incident",
        cascade="all, delete-orphan",
    )


class Investigation(Base):
    __tablename__ = "investigations"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)

    incident_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("incidents.id", ondelete="CASCADE"),
        index=True,
    )

    status: Mapped[str] = mapped_column(String(30), default="pending")

    findings: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)

    root_cause: Mapped[str | None] = mapped_column(Text, nullable=True)

    confidence: Mapped[float | None] = mapped_column(Float, nullable=True)

    recommendation: Mapped[str | None] = mapped_column(Text, nullable=True)

    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )

    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    incident: Mapped["Incident"] = relationship(
        back_populates="investigations",
    )
