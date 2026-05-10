from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class ProductBase(BaseModel):
    sku: str
    name: str
    description: Optional[str] = None
    category: str
    price: float
    stock: int
    warehouse_location: Optional[str] = None
    supplier_id: Optional[str] = None
    is_active: bool = True

class ProductCreate(ProductBase):
    pass

class Product(ProductBase):
    id: int
    image_blob: Optional[str] = None
    document_blob_name: Optional[str] = None
    last_audited: Optional[datetime] = None

    class Config:
        from_attributes = True
