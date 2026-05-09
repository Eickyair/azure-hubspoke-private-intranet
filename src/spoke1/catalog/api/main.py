from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from datetime import datetime, timezone
from core.database import engine, Base
from core.database import SessionLocal
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
    return {"service": settings.service_name, "live": "/live", "health": "/health", "docs": "/docs"}

@app.get("/live")
def live():
    return {"service": settings.service_name, "status": "ok", "checked_at": datetime.now(timezone.utc).isoformat()}

@app.get("/health")
def health():
    started = datetime.now(timezone.utc)
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        database = {"status": "ok", "elapsed_ms": elapsed_ms, "host": settings.mysql_host, "database": settings.mysql_database}
    except Exception as exc:
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        database = {"status": "error", "elapsed_ms": elapsed_ms, "error": str(exc)}

    payload = {
        "service": settings.service_name,
        "status": "ok" if database["status"] == "ok" else "degraded",
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "dependencies": {
            "database": database,
            "storage_mocked": settings.use_mock_storage,
        },
    }
    return JSONResponse(payload, status_code=200 if payload["status"] == "ok" else 503)
