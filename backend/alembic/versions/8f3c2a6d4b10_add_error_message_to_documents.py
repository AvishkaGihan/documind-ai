"""add error_message to documents

Revision ID: 8f3c2a6d4b10
Revises: 4c8ab44815f1
Create Date: 2026-03-18 12:35:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "8f3c2a6d4b10"
down_revision: str | None = "4c8ab44815f1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("documents", sa.Column("error_message", sa.String(length=1024), nullable=True))


def downgrade() -> None:
    op.drop_column("documents", "error_message")
