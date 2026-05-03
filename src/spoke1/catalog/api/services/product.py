from sqlalchemy.orm import Session
from models.product import Product
from schemas.product import ProductCreate

def get_product(db: Session, product_id: int):
    return db.query(Product).filter(Product.id == product_id).first()

def get_products(db: Session, skip: int = 0, limit: int = 100, category: str = None):
    query = db.query(Product)
    if category:
        query = query.filter(Product.category == category)
    return query.offset(skip).limit(limit).all()

def create_product(db: Session, product: ProductCreate, image_blob: str = None):
    db_product = Product(**product.model_dump(), image_blob=image_blob)
    db.add(db_product)
    db.commit()
    db.refresh(db_product)
    return db_product

def update_product_image(db: Session, product_id: int, image_blob: str):
    db_product = get_product(db, product_id)
    if db_product:
        db_product.image_blob = image_blob
        db.commit()
        db.refresh(db_product)
    return db_product
