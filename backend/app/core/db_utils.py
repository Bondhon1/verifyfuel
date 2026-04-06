"""
Database connection utilities for handling NeonDB connections
"""
from sqlalchemy.exc import OperationalError
from time import sleep
import logging

logger = logging.getLogger(__name__)

def retry_on_disconnect(func, max_retries=3, delay=1):
    """
    Retry database operations on connection errors
    
    Args:
        func: Function to execute
        max_retries: Maximum number of retry attempts
        delay: Delay between retries in seconds
    """
    for attempt in range(max_retries):
        try:
            return func()
        except OperationalError as e:
            if "SSL connection has been closed" in str(e) or "connection" in str(e).lower():
                if attempt < max_retries - 1:
                    logger.warning(f"Database connection lost, retrying... (attempt {attempt + 1}/{max_retries})")
                    sleep(delay)
                    continue
                else:
                    logger.error(f"Database connection failed after {max_retries} attempts")
                    raise
            else:
                raise
    return None
