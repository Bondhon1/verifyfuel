from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
from app.core.database import get_db
from app.core.security import get_current_active_user
from app.models.models import FuelEntry, User, Vehicle, UserRole
from app.schemas.schemas import (
    FuelEntryCreate, 
    FuelEntry as FuelEntrySchema,
    EligibilityResponse
)
from app.services.eligibility_service import EligibilityService
from app.services.scheduling_service import SchedulingService

router = APIRouter(prefix="/fuel", tags=["Fuel Management"])

@router.get("/check-eligibility/{plate_number}", response_model=EligibilityResponse)
def check_eligibility(
    plate_number: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Check if a vehicle is eligible for fuel (OCR scan result processing)"""
    return EligibilityService.check_eligibility(db, plate_number)

@router.post("/entries", response_model=FuelEntrySchema)
def create_fuel_entry(
    entry: FuelEntryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Record a new fuel entry (Operator only)"""
    # Only operators can create fuel entries
    if current_user.role != UserRole.OPERATOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only operators can record fuel entries"
        )
    
    # Check if vehicle exists
    vehicle = db.query(Vehicle).filter(Vehicle.id == entry.vehicle_id).first()
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Vehicle not found: ID {entry.vehicle_id}"
        )
    
    # Check eligibility first
    eligibility = EligibilityService.check_eligibility(db, vehicle.plate_number)
    if not eligibility.is_eligible:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=eligibility.message
        )
    
    # Calculate next slot
    next_eligible, slot_start, slot_end = SchedulingService.calculate_next_slot()
    
    # Create fuel entry
    db_entry = FuelEntry(
        vehicle_id=entry.vehicle_id,
        operator_id=current_user.id,
        amount_liters=entry.amount_liters,
        fuel_type=entry.fuel_type,
        station_name=entry.station_name,
        notes=entry.notes,
        entry_datetime=datetime.utcnow(),
        next_eligible_date=next_eligible,
        next_slot_start=slot_start,
        next_slot_end=slot_end
    )
    
    db.add(db_entry)
    db.commit()
    db.refresh(db_entry)
    
    return db_entry

@router.get("/entries/{vehicle_id}", response_model=List[FuelEntrySchema])
def get_fuel_history(
    vehicle_id: int,
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get fuel entry history for a vehicle"""
    # Check if vehicle exists
    vehicle = db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Vehicle not found: ID {vehicle_id}"
        )
    
    # Owners can only view their own vehicles
    if current_user.role == UserRole.OWNER and vehicle.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view your own vehicle history"
        )
    
    entries = db.query(FuelEntry).filter(
        FuelEntry.vehicle_id == vehicle_id
    ).order_by(
        FuelEntry.entry_datetime.desc()
    ).offset(skip).limit(limit).all()
    
    return entries

@router.get("/entries", response_model=List[FuelEntrySchema])
def list_all_fuel_entries(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """List all fuel entries (Admin/Operator only)"""
    if current_user.role not in [UserRole.ADMIN, UserRole.OPERATOR]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins and operators can view all entries"
        )
    
    entries = db.query(FuelEntry).order_by(
        FuelEntry.entry_datetime.desc()
    ).offset(skip).limit(limit).all()
    
    return entries
