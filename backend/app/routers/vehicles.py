from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.core.security import get_current_active_user
from app.models.models import Vehicle, User
from app.schemas.schemas import VehicleCreate, Vehicle as VehicleSchema

router = APIRouter(prefix="/vehicles", tags=["Vehicles"])

@router.post("/", response_model=VehicleSchema)
def create_vehicle(
    vehicle: VehicleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Register a new vehicle"""
    # Check if plate number already exists
    db_vehicle = db.query(Vehicle).filter(
        Vehicle.plate_number == vehicle.plate_number
    ).first()
    
    if db_vehicle:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Vehicle with plate number {vehicle.plate_number} already registered"
        )
    
    # Create vehicle
    db_vehicle = Vehicle(**vehicle.dict())
    db.add(db_vehicle)
    db.commit()
    db.refresh(db_vehicle)
    
    return db_vehicle

@router.get("/{plate_number}", response_model=VehicleSchema)
def get_vehicle(
    plate_number: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get vehicle by plate number"""
    vehicle = db.query(Vehicle).filter(
        Vehicle.plate_number == plate_number
    ).first()
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Vehicle not found: {plate_number}"
        )
    
    return vehicle

@router.get("/", response_model=List[VehicleSchema])
def list_vehicles(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """List all vehicles (admin/operator) or user's vehicles (owner)"""
    if current_user.role in ["admin", "operator"]:
        vehicles = db.query(Vehicle).offset(skip).limit(limit).all()
    else:
        vehicles = db.query(Vehicle).filter(
            Vehicle.owner_id == current_user.id
        ).offset(skip).limit(limit).all()
    
    return vehicles
