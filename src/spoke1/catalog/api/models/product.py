from sqlalchemy import Column, Integer, String, Float, Text, Boolean, Numeric, DateTime, ForeignKey
from core.database import Base
from datetime import datetime

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    sku = Column(String(50), unique=True, index=True)
    name = Column(String(100), index=True)
    description = Column(Text, nullable=True)
    category = Column(String(50), index=True)
    price = Column(Numeric(10, 2), default=0.0)
    stock = Column(Integer, default=0)
    warehouse_location = Column(String(50), nullable=True, index=True)
    supplier_id = Column(String(50), nullable=True)
    image_blob = Column(String(255), nullable=True)
    document_blob_name = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    last_audited = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class SaleHistory(Base):
    __tablename__ = "sales_history"

    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id", ondelete="RESTRICT"), nullable=False)
    quantity = Column(Integer, nullable=False)
    unit_price = Column(Numeric(10, 2), nullable=False)
    # total_price is GENERATED ALWAYS AS (quantity * unit_price) STORED in DB
    sale_date = Column(DateTime, default=datetime.utcnow)
    customer_region = Column(String(100), nullable=True)
