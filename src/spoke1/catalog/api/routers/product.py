from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from core.database import get_db
from schemas.product import Product, ProductCreate
from services import product as product_service
from services.storage import storage_service
from fastapi.responses import Response

router = APIRouter()

@router.get("/products", response_model=List[Product])
def read_products(skip: int = 0, limit: int = 100, category: Optional[str] = None, db: Session = Depends(get_db)):
    products = product_service.get_products(db, skip=skip, limit=limit, category=category)
    return products

@router.get("/products/{product_id}", response_model=Product)
def read_product(product_id: int, db: Session = Depends(get_db)):
    db_product = product_service.get_product(db, product_id=product_id)
    if db_product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return db_product

@router.post("/products", response_model=Product)
async def create_product(
    sku: str = Form(...),
    name: str = Form(...),
    description: str = Form(None),
    category: str = Form(...),
    price: float = Form(...),
    stock: int = Form(...),
    is_active: bool = Form(True),
    image: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    product_data = ProductCreate(
        sku=sku, name=name, description=description, 
        category=category, price=price, stock=stock, is_active=is_active
    )
    
    # We first create the product to get the ID
    db_product = product_service.create_product(db, product_data)
    
    # If image is provided, we upload it
    if image:
        content = await image.read()
        extension = image.filename.split(".")[-1] if "." in image.filename else "jpg"
        blob_name = f"product_{db_product.id}_{sku}.{extension}"
        image_url = storage_service.upload_file(content, blob_name, image.content_type)
        db_product = product_service.update_product_image(db, db_product.id, image_url)
        
    return db_product

@router.put("/products/{product_id}", response_model=Product)
async def update_product(
    product_id: int,
    sku: str = Form(None),
    name: str = Form(None),
    description: str = Form(None),
    category: str = Form(None),
    price: float = Form(None),
    stock: int = Form(None),
    is_active: bool = Form(None),
    image: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    db_product = product_service.get_product(db, product_id)
    if not db_product:
        raise HTTPException(status_code=404, detail="Product not found")

    update_data = {}
    if sku is not None: update_data["sku"] = sku
    if name is not None: update_data["name"] = name
    if description is not None: update_data["description"] = description
    if category is not None: update_data["category"] = category
    if price is not None: update_data["price"] = price
    if stock is not None: update_data["stock"] = stock
    if is_active is not None: update_data["is_active"] = is_active

    db_product = product_service.update_product(db, product_id, update_data)

    if image:
        content = await image.read()
        extension = image.filename.split(".")[-1] if "." in image.filename else "jpg"
        blob_name = f"product_{db_product.id}_{db_product.sku}.{extension}"
        image_url = storage_service.upload_file(content, blob_name, image.content_type)
        db_product = product_service.update_product_image(db, db_product.id, image_url)

    return db_product

@router.get("/storage")
def download_blob_by_query(blob: str = Query(...)):
    return download_blob(blob)

@router.get("/storage/{blob_name:path}")
def download_blob(blob_name: str):
    try:
        content = storage_service.get_file_content(blob_name)
        normalized_blob_name = storage_service.normalize_blob_name(blob_name)
        content_type = "application/octet-stream"
        if normalized_blob_name.endswith((".jpg", ".jpeg")):
            content_type = "image/jpeg"
        elif normalized_blob_name.endswith(".png"):
            content_type = "image/png"
            
        return Response(content=content, media_type=content_type)
    except Exception as e:
        raise HTTPException(status_code=404, detail="File not found")
