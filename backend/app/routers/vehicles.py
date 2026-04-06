from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.core.security import get_current_active_user
from app.models.models import Vehicle, User, UserRole
from app.schemas.schemas import VehicleCreate, Vehicle as VehicleSchema

router = APIRouter(prefix="/vehicles", tags=["Vehicles"])

@router.post("/", response_model=VehicleSchema)
def create_vehicle(
    vehicle: VehicleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Register a new vehicle (registered owner or unknown vehicle)"""
    normalized_plate = vehicle.plate_number.strip().upper()

    # Check if plate number already exists
    db_vehicle = db.query(Vehicle).filter(
        Vehicle.plate_number == normalized_plate
    ).first()
    
    if db_vehicle:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Vehicle with plate number {normalized_plate} already registered"
        )

    # Handle unknown vehicles (no app user)
    if not vehicle.is_registered_owner:
        # Unknown vehicle - require owner name and phone
        if not vehicle.owner_name or not vehicle.owner_phone:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="For unknown vehicles, owner_name and owner_phone are required"
            )
        
        # Create unknown vehicle
        db_vehicle = Vehicle(
            plate_number=normalized_plate,
            owner_id=None,  # No app user
            owner_name=vehicle.owner_name,
            owner_phone=vehicle.owner_phone,
            is_registered_owner=False,
            vehicle_type=vehicle.vehicle_type,
            make=vehicle.make,
            model=vehicle.model,
            year=vehicle.year,
        )
        db.add(db_vehicle)
        db.commit()
        db.refresh(db_vehicle)
        return db_vehicle

    # Handle registered owner vehicles
    owner_id = vehicle.owner_id
    if current_user.role == UserRole.OWNER:
        owner_id = current_user.id
    elif current_user.role == UserRole.OPERATOR:
        if owner_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Operator must provide owner_id for registered vehicles"
            )
    elif current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to register vehicles"
        )

    if owner_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="owner_id is required for registered vehicles"
        )
    
    # Create registered vehicle
    db_vehicle = Vehicle(
        plate_number=normalized_plate,
        owner_id=owner_id,
        is_registered_owner=True,
        vehicle_type=vehicle.vehicle_type,
        make=vehicle.make,
        model=vehicle.model,
        year=vehicle.year,
    )
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
    normalized_plate = plate_number.strip().upper()
    vehicle = db.query(Vehicle).filter(
        Vehicle.plate_number == normalized_plate
    ).first()
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Vehicle not found: {normalized_plate}"
        )

    if current_user.role == UserRole.OWNER and vehicle.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view your own vehicles"
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
    if current_user.role in [UserRole.ADMIN, UserRole.OPERATOR]:
        # Include both registered and unknown vehicles
        vehicles = db.query(Vehicle).offset(skip).limit(limit).all()
    else:
        # Owners only see their own vehicles (where owner_id matches)
        vehicles = db.query(Vehicle).filter(
            Vehicle.owner_id == current_user.id
        ).offset(skip).limit(limit).all()
    
    return vehicles


@router.get("/my", response_model=List[VehicleSchema])
def my_vehicles(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get all vehicles owned by the logged-in owner"""
    vehicles = db.query(Vehicle).filter(
        Vehicle.owner_id == current_user.id
    ).order_by(Vehicle.created_at.desc()).all()
    return vehicles
