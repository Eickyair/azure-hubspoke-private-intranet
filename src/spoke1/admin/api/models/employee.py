from sqlalchemy import Column, Integer, String, Boolean, Date, Numeric, DateTime, ForeignKey
from core.database import Base
from datetime import datetime

class Employee(Base):
    __tablename__ = "employees"

    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String(50), nullable=False)
    last_name = Column(String(50), nullable=False)
    position = Column(String(100), nullable=False)
    department = Column(String(100), nullable=False)
    manager_id = Column(Integer, ForeignKey("employees.id"), nullable=True)
    hire_date = Column(Date, nullable=False)
    salary = Column(Numeric(12, 2), nullable=True)
    location = Column(String(100), nullable=True)
    phone_number = Column(String(50), nullable=True)
    email = Column(String(100), unique=True, index=True, nullable=False)
    profile_picture_blob_name = Column(String(255), nullable=True)
    document_blob_name = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
