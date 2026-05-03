from fastapi import APIRouter, Depends, HTTPException, Response, Form, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional

from core.database import get_db
from schemas.employee import Employee, EmployeeCreate
import services.employee as employee_service
from services.storage import storage_service

router = APIRouter()

@router.get("/employees", response_model=List[Employee])
def read_employees(skip: int = 0, limit: int = 100, is_active: Optional[bool] = None, db: Session = Depends(get_db)):
    return employee_service.get_employees(db, skip=skip, limit=limit, is_active=is_active)

@router.get("/employees/{employee_id}", response_model=Employee)
def read_employee(employee_id: int, db: Session = Depends(get_db)):
    db_employee = employee_service.get_employee(db, employee_id=employee_id)
    if db_employee is None:
        raise HTTPException(status_code=404, detail="Employee not found")
    return db_employee

@router.post("/employees", response_model=Employee)
async def create_employee(
    first_name: str = Form(...),
    last_name: str = Form(...),
    position: str = Form(...),
    department: str = Form(...),
    email: str = Form(...),
    profile_picture: UploadFile = File(None),
    document: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    profile_blob = None
    document_blob = None

    if profile_picture:
        content = await profile_picture.read()
        extension = profile_picture.filename.split(".")[-1] if "." in profile_picture.filename else "jpg"
        profile_blob = f"profile_{email}.{extension}"
        storage_service.upload_file(content, profile_blob, profile_picture.content_type)
        
    if document:
        content = await document.read()
        extension = document.filename.split(".")[-1] if "." in document.filename else "pdf"
        document_blob = f"doc_{email}.{extension}"
        storage_service.upload_file(content, document_blob, document.content_type)
        
    employee_data = {
        "first_name": first_name,
        "last_name": last_name,
        "position": position,
        "department": department,
        "email": email
    }
    db_employee = employee_service.create_employee(db=db, employee_data=employee_data, profile_blob=profile_blob, document_blob=document_blob)
    return employee_service.get_employee(db, db_employee.id)

@router.patch("/employees/{employee_id}/picture", response_model=Employee)
async def update_profile_picture(employee_id: int, profile_picture: UploadFile = File(...), db: Session = Depends(get_db)):
    db_employee = employee_service.get_employee(db, employee_id=employee_id)
    if not db_employee:
        raise HTTPException(status_code=404, detail="Employee not found")
        
    content = await profile_picture.read()
    extension = profile_picture.filename.split(".")[-1] if "." in profile_picture.filename else "jpg"
    profile_blob = f"profile_{employee_id}_{db_employee.email}.{extension}"
    
    storage_service.upload_file(content, profile_blob, profile_picture.content_type)
    
    return employee_service.update_profile_picture(db, employee_id, profile_blob)

@router.patch("/employees/{employee_id}/document", response_model=Employee)
async def update_document(employee_id: int, document: UploadFile = File(...), db: Session = Depends(get_db)):
    db_employee = employee_service.get_employee(db, employee_id=employee_id)
    if not db_employee:
        raise HTTPException(status_code=404, detail="Employee not found")
        
    content = await document.read()
    extension = document.filename.split(".")[-1] if "." in document.filename else "pdf"
    document_blob = f"doc_{employee_id}_{db_employee.email}.{extension}"
    
    storage_service.upload_file(content, document_blob, document.content_type)
    
    return employee_service.update_document(db, employee_id, document_blob)

@router.patch("/employees/{employee_id}/toggle-status", response_model=Employee)
async def toggle_status(employee_id: int, db: Session = Depends(get_db)):
    db_employee = employee_service.toggle_active_status(db, employee_id)
    if not db_employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    return db_employee

@router.get("/storage/{blob_name}")
def download_blob(blob_name: str):
    try:
        content = storage_service.get_file_content(blob_name)
        content_type = "application/octet-stream"
        if blob_name.endswith(".pdf"):
            content_type = "application/pdf"
        elif blob_name.endswith(".png"):
            content_type = "image/png"
        elif blob_name.endswith(".jpg") or blob_name.endswith(".jpeg"):
            content_type = "image/jpeg"
        
        return Response(content=content, media_type=content_type)
    except Exception as e:
        raise HTTPException(status_code=404, detail=f"Blob not found: {str(e)}")
