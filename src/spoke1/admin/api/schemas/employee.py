from pydantic import BaseModel
from typing import Optional

class EmployeeBase(BaseModel):
    first_name: str
    last_name: str
    position: str
    department: str
    email: str
    is_active: bool = True

class EmployeeCreate(EmployeeBase):
    profile_picture_blob_name: Optional[str] = None
    document_blob_name: Optional[str] = None

class Employee(EmployeeBase):
    id: int
    profile_picture_blob_name: Optional[str] = None
    document_blob_name: Optional[str] = None
    profile_picture_url: Optional[str] = None
    document_url: Optional[str] = None

    class Config:
        from_attributes = True
