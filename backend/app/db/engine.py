import os

from sqlalchemy import create_engine

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError(
        "DATABASE_URL is not set. "
        "Example: postgresql+psycopg2://user:pass@postgres:5432/dbname"
    )

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
