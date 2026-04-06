from sqlalchemy import create_engine, event
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Configure engine for NeonDB with proper connection handling
engine = create_engine(
    settings.DATABASE_URL,
    poolclass=NullPool,  # Use NullPool for serverless databases like NeonDB
    connect_args={
        "connect_timeout": 10,
        "keepalives": 1,
        "keepalives_idle": 30,
        "keepalives_interval": 10,
        "keepalives_count": 5,
    },
    echo=False  # Set to True for SQL debugging
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# Add connection event listeners for better connection management
@event.listens_for(engine, "connect")
def receive_connect(dbapi_conn, connection_record):
    """Handle new connections"""
    logger.debug("Database connection established")

@event.listens_for(engine, "checkout")
def receive_checkout(dbapi_conn, connection_record, connection_proxy):
    """Verify connection is alive before using it"""
    try:
        cursor = dbapi_conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
    except Exception as e:
        logger.warning(f"Connection verification failed: {e}")
        # Invalidate the connection
        raise

def get_db():
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
