import os
from core.database import SessionLocal, engine, Base
from models.employee import Employee
from core.config import settings

def seed_data():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    # Check if empty
    if db.query(Employee).count() == 0:
        print("Seeding database with mock employees...")
        employees = [
            Employee(
                first_name="Carlos", last_name="Mendoza",
                position="Gerente de Logística", department="Operaciones",
                email="cmendoza@northwind.lab",
                profile_picture_blob_name="carlos_mendoza.png",
                document_blob_name="carlos_contrato.pdf"
            ),
            Employee(
                first_name="Ana", last_name="García",
                position="Analista de Datos", department="TI",
                email="agarcia@northwind.lab",
                profile_picture_blob_name="ana_garcia.png",
                document_blob_name="ana_certificacion.pdf"
            ),
            Employee(
                first_name="Luis", last_name="Fernández",
                position="Director de Ventas", department="Comercial",
                email="lfernandez@northwind.lab",
                profile_picture_blob_name=None,
                document_blob_name=None
            )
        ]
        db.add_all(employees)
        db.commit()
        print("Database seeded successfully.")
    else:
        print("Database already contains data.")
        
    db.close()

if __name__ == "__main__":
    seed_data()
