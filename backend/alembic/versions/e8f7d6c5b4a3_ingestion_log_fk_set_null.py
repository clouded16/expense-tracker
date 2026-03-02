"""alter ingestion_log.expense_id fk to ondelete SET NULL

Revision ID: e8f7d6c5b4a3
Revises: d673e9376a51
Create Date: 2026-02-26 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'e8f7d6c5b4a3'
down_revision = 'd673e9376a51'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.engine.reflection.Inspector.from_engine(conn)

    # Ensure expense_id is nullable
    op.alter_column('ingestion_log', 'expense_id', existing_type=sa.Integer(), nullable=True)

    # Drop existing foreign key if present
    try:
        op.drop_constraint('ingestion_log_expense_id_fkey', 'ingestion_log', type_='foreignkey')
    except Exception:
        # attempt to find any fk on column and drop it
        fks = inspector.get_foreign_keys('ingestion_log')
        for fk in fks:
            if fk['constrained_columns'] == ['expense_id']:
                op.drop_constraint(fk['name'], 'ingestion_log', type_='foreignkey')
                break

    # Create new FK with ON DELETE SET NULL
    op.create_foreign_key(
        'ingestion_log_expense_id_fkey',
        'ingestion_log',
        'expense',
        ['expense_id'],
        ['id'],
        ondelete='SET NULL'
    )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.engine.reflection.Inspector.from_engine(conn)

    # Drop FK with ON DELETE SET NULL
    try:
        op.drop_constraint('ingestion_log_expense_id_fkey', 'ingestion_log', type_='foreignkey')
    except Exception:
        fks = inspector.get_foreign_keys('ingestion_log')
        for fk in fks:
            if fk['constrained_columns'] == ['expense_id']:
                op.drop_constraint(fk['name'], 'ingestion_log', type_='foreignkey')
                break

    # Recreate original FK without ON DELETE (RESTRICT behavior)
    op.create_foreign_key(
        'ingestion_log_expense_id_fkey',
        'ingestion_log',
        'expense',
        ['expense_id'],
        ['id']
    )
