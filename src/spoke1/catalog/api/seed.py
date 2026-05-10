from core.database import SessionLocal, Base, engine
from models.product import Product

def seed_data():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    if db.query(Product).count() == 0:
        products = [
            Product(sku="NW-ELEC-001", name="Monitor 27'' 4K", description="Monitor profesional IPS 4K con colores precisos", category="Electrónica", price=299.99, stock=45, warehouse_location="Bodega TI - Rack 1", supplier_id="SUP-TECH", document_blob_name="monitor_manual.pdf", is_active=True),
            Product(sku="NW-ELEC-002", name="Teclado Mecánico RGB", description="Teclado switches red silenciosos", category="Electrónica", price=89.50, stock=120, warehouse_location="Bodega TI - Rack 2", supplier_id="SUP-TECH", document_blob_name="teclado_specs.pdf", is_active=True),
            Product(sku="NW-OFFI-001", name="Silla Ergonómica", description="Silla de malla transpirable con soporte lumbar", category="Oficina", price=149.00, stock=30, warehouse_location="Bodega General", supplier_id="SUP-FURN", document_blob_name="silla_armado.pdf", is_active=True),
            Product(sku="NW-OFFI-002", name="Escritorio Ajustable", description="Escritorio standing desk motorizado", category="Oficina", price=350.00, stock=15, warehouse_location="Bodega General", supplier_id="SUP-FURN", document_blob_name="escritorio_armado.pdf", is_active=True),
            Product(sku="NW-CLEAN-001", name="Kit Limpieza Pantallas", description="Spray antiestático y paño de microfibra", category="Limpieza", price=12.99, stock=200, warehouse_location="Cuarto de Aseo", supplier_id="SUP-CLEAN", document_blob_name="msds_limpieza.pdf", is_active=True),
        ]
        db.add_all(products)
        db.commit()
        
        # Seed Sales History
        from models.product import SaleHistory
        from datetime import datetime, timedelta
        
        sales = [
            SaleHistory(product_id=products[0].id, quantity=2, unit_price=299.99, sale_date=datetime.utcnow() - timedelta(days=2), customer_region="Norte"),
            SaleHistory(product_id=products[1].id, quantity=5, unit_price=89.50, sale_date=datetime.utcnow() - timedelta(days=1), customer_region="Centro"),
            SaleHistory(product_id=products[2].id, quantity=1, unit_price=149.00, sale_date=datetime.utcnow(), customer_region="Sur"),
        ]
        db.add_all(sales)
        db.commit()
        
        print("Product and sales database seeded successfully.")
    else:
        print("Database already has products.")
        
    db.close()

if __name__ == "__main__":
    seed_data()
