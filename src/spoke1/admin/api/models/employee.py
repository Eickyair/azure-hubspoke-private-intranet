from sqlalchemy import Column, Integer, String, Boolean
from core.database import Base

class Employee(Base):
    __tablename__ = "employees"

    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String(50), nullable=False)
    last_name = Column(String(50), nullable=False)
    position = Column(String(100), nullable=False)
    department = Column(String(100), nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    profile_picture_blob_name = Column(String(255), nullable=True)
    document_blob_name = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
