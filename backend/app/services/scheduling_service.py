from datetime import datetime, timedelta
from typing import Tuple

# Time slots for fuel distribution (24-hour format)
TIME_SLOTS = [
    (6, 9),    # 6 AM - 9 AM
    (9, 12),   # 9 AM - 12 PM
    (12, 15),  # 12 PM - 3 PM
    (15, 18),  # 3 PM - 6 PM
    (18, 21),  # 6 PM - 9 PM
]

class SchedulingService:
    """Service to assign next fuel visit date and time slot"""
    
    @staticmethod
    def calculate_next_slot(current_time: datetime = None) -> Tuple[datetime, datetime, datetime]:
        """
        Calculate the next eligible date and time slot for fuel.
        
        Returns:
            Tuple of (next_eligible_date, slot_start, slot_end)
        
        Logic:
        - Next eligible date is exactly 72 hours (3 days) from current time
        - Assign time slot based on current hour
        - If current time is 11 AM, next slot will be 10 AM - 1 PM (after 3 days)
        """
        if current_time is None:
            current_time = datetime.utcnow()
        
        # Calculate next eligible date (72 hours from now)
        next_eligible_date = current_time + timedelta(hours=72)
        
        # Find the appropriate time slot based on current hour
        current_hour = current_time.hour
        
        # Select time slot based on current hour
        # This ensures similar time-of-day preference for the next visit
        selected_slot = None
        for slot_start, slot_end in TIME_SLOTS:
            if current_hour >= slot_start and current_hour < slot_end:
                selected_slot = (slot_start, slot_end)
                break
        
        # If no slot matches (late night), default to first slot (6-9 AM)
        if selected_slot is None:
            selected_slot = TIME_SLOTS[0]
        
        # Create datetime objects for slot start and end
        slot_start_time = next_eligible_date.replace(
            hour=selected_slot[0],
            minute=0,
            second=0,
            microsecond=0
        )
        
        slot_end_time = next_eligible_date.replace(
            hour=selected_slot[1],
            minute=0,
            second=0,
            microsecond=0
        )
        
        return next_eligible_date, slot_start_time, slot_end_time
    
    @staticmethod
    def format_slot_bangla(slot_start: datetime, slot_end: datetime) -> str:
        """Format time slot in Bangla"""
        bangla_numbers = str.maketrans('0123456789', '০১২৩৪৫৬৭৮৯')
        
        start_hour = slot_start.hour
        end_hour = slot_end.hour
        
        # Convert to 12-hour format
        start_period = "সকাল" if start_hour < 12 else "বিকাল" if start_hour < 18 else "সন্ধ্যা"
        end_period = "সকাল" if end_hour < 12 else "বিকাল" if end_hour < 18 else "সন্ধ্যা"
        
        start_12h = start_hour if start_hour <= 12 else start_hour - 12
        end_12h = end_hour if end_hour <= 12 else end_hour - 12
        
        start_str = f"{start_12h}".translate(bangla_numbers)
        end_str = f"{end_12h}".translate(bangla_numbers)
        
        return f"{start_period} {start_str}টা - {end_period} {end_str}টা"
