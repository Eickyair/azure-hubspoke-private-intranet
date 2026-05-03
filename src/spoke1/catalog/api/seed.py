from core.database import SessionLocal, Base, engine
from models.product import Product

def seed_data():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    if db.query(Product).count() == 0:
        products = [
            Product(sku="NW-ELEC-001", name="Monitor 27'' 4K", description="Monitor profesional IPS 4K con colores precisos", category="Electrónica", price=299.99, stock=45, is_active=True),
            Product(sku="NW-ELEC-002", name="Teclado Mecánico RGB", description="Teclado switches red silenciosos", category="Electrónica", price=89.50, stock=120, is_active=True),
            Product(sku="NW-OFFI-001", name="Silla Ergonómica", description="Silla de malla transpirable con soporte lumbar", category="Oficina", price=149.00, stock=30, is_active=True),
            Product(sku="NW-OFFI-002", name="Escritorio Ajustable", description="Escritorio standing desk motorizado", category="Oficina", price=350.00, stock=15, is_active=True),
            Product(sku="NW-CLEAN-001", name="Kit Limpieza Pantallas", description="Spray antiestático y paño de microfibra", category="Limpieza", price=12.99, stock=200, is_active=True),
        ]
        db.add_all(products)
        db.commit()
        print("Product database seeded successfully.")
    else:
        print("Database already has products.")
        
    db.close()

if __name__ == "__main__":
    seed_data()
