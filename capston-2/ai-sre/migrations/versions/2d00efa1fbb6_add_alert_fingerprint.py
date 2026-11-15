"""add alert fingerprint

Revision ID: 2d00efa1fbb6
Revises: 7c77ce007b98
Create Date: 2026-11-15 12:48:18.951806

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2d00efa1fbb6"
down_revision: str | Sequence[str] | None = "7c77ce007b98"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "incidents",
        sa.Column("fingerprint", sa.String(length=64), nullable=True),
    )
    op.create_unique_constraint(
        "uq_incidents_fingerprint_starts_at",
        "incidents",
        ["fingerprint", "starts_at"],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        "uq_incidents_fingerprint_starts_at",
        "incidents",
        type_="unique",
    )
    op.drop_column("incidents", "fingerprint")
