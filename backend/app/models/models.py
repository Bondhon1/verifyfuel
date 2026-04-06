from sqlalchemy import Column, Integer, String, DateTime, Enum, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.core.database import Base

class UserRole(str, enum.Enum):
    OPERATOR = "operator"
    OWNER = "owner"
    ADMIN = "admin"

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    phone = Column(String, unique=True, index=True)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String)
    role = Column(Enum(UserRole), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    vehicles = relationship("Vehicle", back_populates="owner")
    fuel_entries = relationship("FuelEntry", back_populates="operator")

class Vehicle(Base):
    __tablename__ = "vehicles"
    
    id = Column(Integer, primary_key=True, index=True)
    plate_number = Column(String, unique=True, index=True, nullable=False)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    vehicle_type = Column(String)  # Car, Motorcycle, Truck, etc.
    make = Column(String)
    model = Column(String)
    year = Column(Integer)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    owner = relationship("User", back_populates="vehicles")
    fuel_entries = relationship("FuelEntry", back_populates="vehicle", order_by="desc(FuelEntry.created_at)")

class FuelEntry(Base):
    __tablename__ = "fuel_entries"
    
    id = Column(Integer, primary_key=True, index=True)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=False)
    operator_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Fuel details
    amount_liters = Column(Integer, nullable=False)
    fuel_type = Column(String, default="Petrol")
    
    # Scheduling
    entry_datetime = Column(DateTime, default=datetime.utcnow, nullable=False)
    next_eligible_date = Column(DateTime, nullable=False)
    next_slot_start = Column(DateTime, nullable=False)
    next_slot_end = Column(DateTime, nullable=False)
    
    # Metadata
    station_name = Column(String)
    notes = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    vehicle = relationship("Vehicle", back_populates="fuel_entries")
    operator = relationship("User", back_populates="fuel_entries")
