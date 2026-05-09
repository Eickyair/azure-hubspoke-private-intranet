from sqlalchemy import Column, Integer, String, Float, Text, Boolean
from core.database import Base

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    sku = Column(String(50), unique=True, index=True)
    name = Column(String(100), index=True)
    description = Column(Text, nullable=True)
    category = Column(String(50), index=True)
    price = Column(Float, default=0.0)
    stock = Column(Integer, default=0)
    image_blob = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
