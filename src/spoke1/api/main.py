import os
from datetime import datetime, timezone

import pymysql
from azure.storage.blob import BlobServiceClient
from fastapi import FastAPI
from fastapi.responses import JSONResponse


SERVICE_NAME = os.getenv("SERVICE_NAME", "api-private")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))
STORAGE_ACCOUNT_URL = os.getenv("STORAGE_ACCOUNT_URL", "")
STORAGE_ACCOUNT_KEY = os.getenv("STORAGE_ACCOUNT_KEY", "")
STORAGE_CONTAINER_NAME = os.getenv("STORAGE_CONTAINER_NAME", "documents")

app = FastAPI(title=SERVICE_NAME)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def env(name: str) -> str:
    return os.getenv(name, "").strip()


def check_mysql(prefix: str, label: str) -> dict:
    host = env(f"{prefix}_HOST")
    database = env(f"{prefix}_DATABASE")
    user = env(f"{prefix}_USER")
    password = env(f"{prefix}_PASSWORD")

    if not all([host, database, user, password]):
        return {"name": label, "status": "not_configured"}

    started = datetime.now(timezone.utc)
    try:
        connection = pymysql.connect(
            host=host,
            port=MYSQL_PORT,
            user=user,
            password=password,
            database=database,
            connect_timeout=4,
            ssl={"check_hostname": False},
        )
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        connection.close()
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {"name": label, "status": "ok", "host": host, "database": database, "elapsed_ms": elapsed_ms}
    except Exception as exc:
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {"name": label, "status": "error", "host": host, "database": database, "elapsed_ms": elapsed_ms, "error": str(exc)}


def check_blob_storage() -> dict:
    if not STORAGE_ACCOUNT_URL or not STORAGE_ACCOUNT_KEY:
        return {"name": "blob-documents", "status": "not_configured"}

    started = datetime.now(timezone.utc)
    try:
        client = BlobServiceClient(account_url=STORAGE_ACCOUNT_URL, credential=STORAGE_ACCOUNT_KEY)
        container = client.get_container_client(STORAGE_CONTAINER_NAME)
        exists = container.exists()
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {
            "name": "blob-documents",
            "status": "ok" if exists else "error",
            "container": STORAGE_CONTAINER_NAME,
            "elapsed_ms": elapsed_ms,
            "error": None if exists else "container_not_found",
        }
    except Exception as exc:
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {"name": "blob-documents", "status": "error", "container": STORAGE_CONTAINER_NAME, "elapsed_ms": elapsed_ms, "error": str(exc)}


def health_payload() -> dict:
    dependencies = {
        "mysql_app": check_mysql("MYSQL_APP", "mysql-app-db"),
        "mysql_admin": check_mysql("MYSQL_ADMIN", "mysql-admin-db"),
        "blob_storage": check_blob_storage(),
    }
    ok = all(item["status"] == "ok" for item in dependencies.values())
    return {"service": SERVICE_NAME, "status": "ok" if ok else "degraded", "checked_at": utc_now(), "dependencies": dependencies}


@app.get("/")
def root() -> dict:
    return {"service": SERVICE_NAME, "health": "/health"}


@app.get("/health")
def health() -> JSONResponse:
    payload = health_payload()
    return JSONResponse(payload, status_code=200 if payload["status"] == "ok" else 503)
