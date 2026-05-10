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
        import random
        from datetime import date, timedelta
        
        first_names_m = ["Alejandro", "Juan", "Carlos", "Eduardo", "Roberto", "Luis", "Jorge", "Miguel", "Ricardo", "Fernando", "Diego", "Javier", "Héctor"]
        first_names_f = ["María", "Guadalupe", "Ana", "Sofía", "Daniela", "Laura", "Carmen", "Patricia", "Martha", "Leticia", "Lucía", "Valeria", "Fernanda"]
        last_names = ["García", "Martínez", "López", "González", "Pérez", "Rodríguez", "Sánchez", "Ramírez", "Cruz", "Flores", "Gómez", "Díaz", "Morales"]
        locations = ["Ciudad de México", "Monterrey", "Guadalajara", "Puebla", "Tijuana", "Querétaro", "Mérida", "León", "Toluca"]
        departments = ["Operaciones", "TI", "Comercial", "Recursos Humanos", "Finanzas", "Marketing"]
        
        # Jerarquías y rangos salariales aproximados (MXN mensuales)
        positions_pool = {
            "Director": {"salary": (80000, 120000)},
            "Gerente": {"salary": (45000, 75000)},
            "Coordinador": {"salary": (25000, 40000)},
            "Especialista": {"salary": (18000, 30000)},
            "Analista": {"salary": (12000, 20000)}
        }
        
        employees = []
        # Crear un CEO / Director General explícito (manager_id = None)
        ceo = Employee(
            first_name="Ricardo", last_name="Mendoza",
            position="Director General", department="Dirección",
            email="rmendoza@northwind.lab",
            hire_date=date(2015, 1, 10),
            salary=150000.00,
            location="Ciudad de México",
            phone_number=f"55-{random.randint(1000,9999)}-{random.randint(1000,9999)}",
            is_active=True
        )
        employees.append(ceo)
        
        for i in range(1, 50):
            is_male = random.choice([True, False])
            fname = random.choice(first_names_m) if is_male else random.choice(first_names_f)
            lname1 = random.choice(last_names)
            lname2 = random.choice(last_names)
            
            position_title = random.choice(list(positions_pool.keys()))
            dept = random.choice(departments)
            full_position = f"{position_title} de {dept}"
            
            salary_range = positions_pool[position_title]["salary"]
            salary = round(random.uniform(salary_range[0], salary_range[1]), 2)
            
            # Generar fecha de contratación entre 2018 y hoy
            days_ago = random.randint(10, 2000)
            h_date = date.today() - timedelta(days=days_ago)
            
            email_prefix = f"{fname[0].lower()}{lname1.lower()}{i}"
            email = f"{email_prefix}@northwind.lab"
            
            phone = f"{random.choice(['55','33','81'])}-{random.randint(1000,9999)}-{random.randint(1000,9999)}"
            
            emp = Employee(
                first_name=fname,
                last_name=f"{lname1} {lname2}",
                position=full_position,
                department=dept,
                email=email,
                hire_date=h_date,
                salary=salary,
                location=random.choice(locations),
                phone_number=phone,
                manager_id=1 if position_title == "Director" else random.randint(1, i) if i > 1 else 1, # Jerarquía mockeada
                is_active=random.choice([True] * 9 + [False]) # 10% inactivos
            )
            employees.append(emp)
            
        db.add_all(employees)
        db.commit()
        print("Database seeded successfully.")
    else:
        print("Database already contains data.")
        
    db.close()

if __name__ == "__main__":
    seed_data()
