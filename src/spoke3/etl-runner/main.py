import os
from datetime import datetime, timezone

import pymysql
from fastapi import FastAPI
from fastapi.responses import JSONResponse


SERVICE_NAME = os.getenv("SERVICE_NAME", "etl-runner-01")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))

app = FastAPI(title=SERVICE_NAME)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def check_mysql(prefix: str, label: str) -> dict:
    host = os.getenv(f"{prefix}_HOST", "")
    database = os.getenv(f"{prefix}_DATABASE", "")
    user = os.getenv(f"{prefix}_USER", "")
    password = os.getenv(f"{prefix}_PASSWORD", "")

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


def health_payload() -> dict:
    dependencies = {
        "mysql_app_source": check_mysql("MYSQL_APP", "mysql-app-db"),
        "mysql_admin_source": check_mysql("MYSQL_ADMIN", "mysql-admin-db"),
        "mysql_analytics_target": check_mysql("MYSQL_ANALYTICS", "mysql-analytics-db"),
    }
    ok = all(item["status"] == "ok" for item in dependencies.values())
    return {"service": SERVICE_NAME, "status": "ok" if ok else "degraded", "checked_at": utc_now(), "dependencies": dependencies}


@app.get("/")
def root() -> dict:
    return {"service": SERVICE_NAME, "health": "/health", "run": "/run"}


@app.get("/health")
def health() -> JSONResponse:
    payload = health_payload()
    return JSONResponse(payload, status_code=200 if payload["status"] == "ok" else 503)


@app.post("/run")
def run_etl() -> dict:
    return {"service": SERVICE_NAME, "status": "accepted", "message": "ETL placeholder listo para la siguiente iteracion", "queued_at": utc_now()}
