from sqlalchemy.orm import Session
from models.employee import Employee
from schemas.employee import EmployeeCreate, Employee as EmployeeSchema
from services.storage import storage_service

from typing import Optional

def get_employees(db: Session, skip: int = 0, limit: int = 100, is_active: Optional[bool] = None):
    query = db.query(Employee)
    if is_active is not None:
        query = query.filter(Employee.is_active == is_active)
    employees = query.offset(skip).limit(limit).all()
    result = []
    for emp in employees:
        emp_dict = emp.__dict__.copy()
        emp_dict["profile_picture_url"] = storage_service.get_blob_url(emp.profile_picture_blob_name)
        emp_dict["document_url"] = storage_service.get_blob_url(emp.document_blob_name)
        result.append(EmployeeSchema(**emp_dict))
    return result

def get_employee(db: Session, employee_id: int):
    emp = db.query(Employee).filter(Employee.id == employee_id).first()
    if emp:
        emp_dict = emp.__dict__.copy()
        emp_dict["profile_picture_url"] = storage_service.get_blob_url(emp.profile_picture_blob_name)
        emp_dict["document_url"] = storage_service.get_blob_url(emp.document_blob_name)
        return EmployeeSchema(**emp_dict)
    return None

def create_employee(db: Session, employee_data: dict, profile_blob: str = None, document_blob: str = None):
    db_employee = Employee(**employee_data)
    db_employee.profile_picture_blob_name = profile_blob
    db_employee.document_blob_name = document_blob
    db.add(db_employee)
    db.commit()
    db.refresh(db_employee)
    return db_employee

def update_profile_picture(db: Session, employee_id: int, blob_name: str):
    emp = db.query(Employee).filter(Employee.id == employee_id).first()
    if emp:
        emp.profile_picture_blob_name = blob_name
        db.commit()
        db.refresh(emp)
        emp_dict = emp.__dict__.copy()
        emp_dict["profile_picture_url"] = storage_service.get_blob_url(emp.profile_picture_blob_name)
        emp_dict["document_url"] = storage_service.get_blob_url(emp.document_blob_name)
        return EmployeeSchema(**emp_dict)
    return None

def update_document(db: Session, employee_id: int, blob_name: str):
    emp = db.query(Employee).filter(Employee.id == employee_id).first()
    if emp:
        emp.document_blob_name = blob_name
        db.commit()
        db.refresh(emp)
        emp_dict = emp.__dict__.copy()
        emp_dict["profile_picture_url"] = storage_service.get_blob_url(emp.profile_picture_blob_name)
        emp_dict["document_url"] = storage_service.get_blob_url(emp.document_blob_name)
        return EmployeeSchema(**emp_dict)
    return None

def toggle_active_status(db: Session, employee_id: int):
    emp = db.query(Employee).filter(Employee.id == employee_id).first()
    if emp:
        emp.is_active = not emp.is_active
        db.commit()
        db.refresh(emp)
        emp_dict = emp.__dict__.copy()
        emp_dict["profile_picture_url"] = storage_service.get_blob_url(emp.profile_picture_blob_name)
        emp_dict["document_url"] = storage_service.get_blob_url(emp.document_blob_name)
        return EmployeeSchema(**emp_dict)
    return None
