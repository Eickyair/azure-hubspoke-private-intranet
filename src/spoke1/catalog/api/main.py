from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from core.database import engine, Base
from routers import product
from core.config import settings

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Catalog API", description="Northwind Product Catalog Backend")

# Allow CORS for local dev across ports
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(product.router, prefix="/api", tags=["products"])

@app.get("/")
def root():
    return {"service": settings.service_name, "status": "running"}

@app.get("/health")
def health():
    return {"status": "ok"}
