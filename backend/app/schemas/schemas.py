from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional
from enum import Enum

class UserRole(str, Enum):
    OPERATOR = "operator"
    OWNER = "owner"
    ADMIN = "admin"

# User Schemas
class UserBase(BaseModel):
    username: str
    email: EmailStr
    phone: Optional[str] = None
    full_name: Optional[str] = None
    role: UserRole

class UserCreate(UserBase):
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class User(UserBase):
    id: int
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

# Vehicle Schemas
class VehicleBase(BaseModel):
    plate_number: str
    vehicle_type: Optional[str] = None
    make: Optional[str] = None
    model: Optional[str] = None
    year: Optional[int] = None

class VehicleCreate(VehicleBase):
    owner_id: Optional[int] = None
    owner_name: Optional[str] = None  # For unknown vehicles
    owner_phone: Optional[str] = None  # For unknown vehicles
    is_registered_owner: bool = True  # False for unknown vehicles

class Vehicle(VehicleBase):
    id: int
    owner_id: Optional[int] = None  # Nullable for unknown vehicles
    owner_name: Optional[str] = None
    owner_phone: Optional[str] = None
    is_registered_owner: bool
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

# Fuel Entry Schemas
class FuelEntryBase(BaseModel):
    vehicle_id: int
    amount_liters: int
    fuel_type: str = "Petrol"
    station_name: Optional[str] = None
    notes: Optional[str] = None

class FuelEntryCreate(FuelEntryBase):
    operator_id: Optional[int] = None

class FuelEntry(FuelEntryBase):
    id: int
    operator_id: int
    entry_datetime: datetime
    next_eligible_date: datetime
    next_slot_start: datetime
    next_slot_end: datetime
    created_at: datetime
    
    class Config:
        from_attributes = True

# Eligibility Check
class EligibilityResponse(BaseModel):
    is_eligible: bool
    message: str
    plate_number: str
    last_fuel_date: Optional[datetime] = None
    next_eligible_date: Optional[datetime] = None
    next_slot_start: Optional[datetime] = None
    next_slot_end: Optional[datetime] = None
    hours_remaining: Optional[int] = None

# Token
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None


class ScanFuelRequest(BaseModel):
    plate_number: str
    amount_liters: int
    fuel_type: str = "Petrol"
    station_name: Optional[str] = None
    notes: Optional[str] = None


class DashboardSummary(BaseModel):
    total_vehicles: int
    total_users: int
    total_fuel_entries: int
    today_fuel_entries: int
    eligible_vehicles: int
    denied_vehicles: int
