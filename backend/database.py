import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker

load_dotenv()

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

DATABASE_URL = (
    f"postgresql://{DB_USER}:{DB_PASSWORD}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def ensure_schema_updates() -> None:
    """Apply lightweight backward-compatible schema updates."""
    with engine.begin() as conn:
        inspector = inspect(conn)
        if "investment_assets" not in inspector.get_table_names():
            return

        existing_cols = {col["name"] for col in inspector.get_columns("investment_assets")}
        if "price" not in existing_cols:
            conn.execute(text("ALTER TABLE investment_assets ADD COLUMN price DOUBLE PRECISION"))


from models.base import Base
from models import category_orm
from models import expense_orm
from models import investment_asset_orm
from models import investment_option_orm
from models import merchant_orm
from models import mutual_fund_orm
from models import stock_orm
from models import gold_price_orm
from models import fd_rate_orm
from models import lic_policy_orm
from models import goals_portfolio_orm
from models import password_reset_otp_orm
from models import source_orm
from models import user_portfolio_orm
