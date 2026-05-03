import os
from datetime import datetime, timezone
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from core.database import engine, Base, SessionLocal
from routers import employee
from core.config import settings

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.SERVICE_NAME, description="API privada para Northwind Distribución")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(employee.router, prefix="/api", tags=["employees"])

def check_db() -> dict:
    started = datetime.now(timezone.utc)
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {"status": "ok", "elapsed_ms": elapsed_ms, "url": settings.database_url.split("@")[-1] if "@" in settings.database_url else settings.database_url}
    except Exception as e:
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {"status": "error", "elapsed_ms": elapsed_ms, "error": str(e)}

@app.get("/")
def root():
    return {"service": settings.SERVICE_NAME, "health": "/health", "docs": "/docs"}

@app.get("/health")
def health() -> JSONResponse:
    db_health = check_db()
    payload = {
        "service": settings.SERVICE_NAME,
        "status": "ok" if db_health["status"] == "ok" else "degraded",
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "dependencies": {
            "database": db_health,
            "storage_mocked": settings.use_mock_storage
        }
    }
    return JSONResponse(payload, status_code=200 if payload["status"] == "ok" else 503)
