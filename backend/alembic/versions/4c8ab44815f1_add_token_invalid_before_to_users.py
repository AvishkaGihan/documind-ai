"""add token_invalid_before to users

Revision ID: 4c8ab44815f1
Revises: 0db104fe82c5
Create Date: 2026-03-16 18:20:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "4c8ab44815f1"
down_revision: str | None = "0db104fe82c5"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("token_invalid_before", sa.BigInteger(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("users", "token_invalid_before")
