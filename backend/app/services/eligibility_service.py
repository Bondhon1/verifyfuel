from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from app.models.models import Vehicle, FuelEntry
from app.schemas.schemas import EligibilityResponse

ELIGIBILITY_HOURS = 72  # 3 days = 72 hours

class EligibilityService:
    """Service to check if a vehicle is eligible for fuel based on the 3-day rule"""
    
    @staticmethod
    def check_eligibility(db: Session, plate_number: str) -> EligibilityResponse:
        """
        Check if a vehicle is eligible for fuel based on last fuel entry.
        
        Rules:
        - Vehicle must wait minimum 72 hours (3 days) between fuel entries
        - If no previous entry exists, vehicle is eligible
        - Returns eligibility status with next available slot info
        """
        # Find vehicle by plate number
        vehicle = db.query(Vehicle).filter(
            Vehicle.plate_number == plate_number,
            Vehicle.is_active == True
        ).first()
        
        if not vehicle:
            return EligibilityResponse(
                is_eligible=False,
                message=f"যানবাহন পাওয়া যায়নি - Vehicle not found: {plate_number}",
                plate_number=plate_number
            )
        
        # Get the most recent fuel entry for this vehicle
        last_entry = db.query(FuelEntry).filter(
            FuelEntry.vehicle_id == vehicle.id
        ).order_by(FuelEntry.entry_datetime.desc()).first()
        
        # If no previous entry, vehicle is eligible
        if not last_entry:
            return EligibilityResponse(
                is_eligible=True,
                message=f"অনুমোদিত - প্রথম জ্বালানি প্রবেশ - Approved: First fuel entry",
                plate_number=plate_number
            )
        
        # Calculate time since last fuel entry
        now = datetime.utcnow()
        time_since_last = now - last_entry.entry_datetime
        hours_since_last = time_since_last.total_seconds() / 3600
        
        # Check if 72 hours have passed
        if hours_since_last >= ELIGIBILITY_HOURS:
            return EligibilityResponse(
                is_eligible=True,
                message=f"অনুমোদিত - জ্বালানি দিতে পারেন - Approved: Vehicle is eligible",
                plate_number=plate_number,
                last_fuel_date=last_entry.entry_datetime,
                next_eligible_date=last_entry.next_eligible_date,
                next_slot_start=last_entry.next_slot_start,
                next_slot_end=last_entry.next_slot_end
            )
        else:
            # Calculate remaining hours
            hours_remaining = int(ELIGIBILITY_HOURS - hours_since_last)
            
            return EligibilityResponse(
                is_eligible=False,
                message=f"অস্বীকৃত - এখনও {hours_remaining} ঘন্টা বাকি - Denied: {hours_remaining} hours remaining",
                plate_number=plate_number,
                last_fuel_date=last_entry.entry_datetime,
                next_eligible_date=last_entry.next_eligible_date,
                next_slot_start=last_entry.next_slot_start,
                next_slot_end=last_entry.next_slot_end,
                hours_remaining=hours_remaining
            )
