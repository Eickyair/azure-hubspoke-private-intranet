import os
from datetime import datetime, timezone

import pymysql
import requests
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse


SERVICE_NAME = os.getenv("SERVICE_NAME", "web-admin")
API_BASE_URL = os.getenv("API_BASE_URL", "https://api.northwind.lab").rstrip("/")
API_HEALTH_PATH = os.getenv("API_HEALTH_PATH", "/health")
REQUEST_TIMEOUT_SECONDS = float(os.getenv("REQUEST_TIMEOUT_SECONDS", "4"))
VERIFY_TLS = os.getenv("VERIFY_TLS", "true").lower() == "true"

MYSQL_ADMIN_HOST = os.getenv("MYSQL_ADMIN_HOST", "")
MYSQL_ADMIN_DATABASE = os.getenv("MYSQL_ADMIN_DATABASE", "")
MYSQL_ADMIN_USER = os.getenv("MYSQL_ADMIN_USER", "")
MYSQL_ADMIN_PASSWORD = os.getenv("MYSQL_ADMIN_PASSWORD", "")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))

app = FastAPI(title=SERVICE_NAME)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def check_api() -> dict:
    health_url = f"{API_BASE_URL}{API_HEALTH_PATH}"
    started = datetime.now(timezone.utc)
    try:
        response = requests.get(health_url, timeout=REQUEST_TIMEOUT_SECONDS, verify=VERIFY_TLS)
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {
            "name": "api-private",
            "status": "ok" if response.ok else "error",
            "url": health_url,
            "http_status": response.status_code,
            "elapsed_ms": elapsed_ms,
        }
    except Exception as exc:
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {"name": "api-private", "status": "error", "url": health_url, "elapsed_ms": elapsed_ms, "error": str(exc)}


def check_admin_database() -> dict:
    if not all([MYSQL_ADMIN_HOST, MYSQL_ADMIN_DATABASE, MYSQL_ADMIN_USER, MYSQL_ADMIN_PASSWORD]):
        return {"name": "mysql-admin-db", "status": "not_configured"}

    started = datetime.now(timezone.utc)
    try:
        connection = pymysql.connect(
            host=MYSQL_ADMIN_HOST,
            port=MYSQL_PORT,
            user=MYSQL_ADMIN_USER,
            password=MYSQL_ADMIN_PASSWORD,
            database=MYSQL_ADMIN_DATABASE,
            connect_timeout=4,
            ssl={"check_hostname": False},
        )
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        connection.close()
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {"name": "mysql-admin-db", "status": "ok", "host": MYSQL_ADMIN_HOST, "elapsed_ms": elapsed_ms}
    except Exception as exc:
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {"name": "mysql-admin-db", "status": "error", "host": MYSQL_ADMIN_HOST, "elapsed_ms": elapsed_ms, "error": str(exc)}


def health_payload() -> dict:
    dependencies = {"api": check_api(), "admin_database": check_admin_database()}
    ok = all(item["status"] == "ok" for item in dependencies.values())
    return {"service": SERVICE_NAME, "status": "ok" if ok else "degraded", "checked_at": utc_now(), "dependencies": dependencies}


def badge(status: str) -> str:
    label = "Correcto" if status == "ok" else "Revisar"
    css = "ok" if status == "ok" else "error"
    return f'<span class="badge {css}">{label}</span>'


@app.get("/", response_class=HTMLResponse)
def index() -> str:
    payload = health_payload()
    dependencies = payload["dependencies"]
    return f"""
    <!doctype html>
    <html lang="es">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <meta http-equiv="refresh" content="20" />
      <title>{SERVICE_NAME}</title>
      <style>
        body {{ margin: 0; padding: 32px; font-family: Arial, sans-serif; background: #f6f8fc; color: #162033; }}
        main {{ max-width: 900px; margin: 0 auto; }}
        h1 {{ margin: 0 0 8px; }}
        .panel {{ margin-top: 24px; background: #fff; border: 1px solid #dfe6f1; border-radius: 8px; padding: 22px; }}
        .row {{ display: flex; justify-content: space-between; gap: 16px; align-items: center; border-bottom: 1px solid #edf1f7; padding: 14px 0; }}
        .row:last-child {{ border-bottom: 0; }}
        .badge {{ border-radius: 999px; padding: 8px 12px; font-weight: 700; }}
        .badge.ok {{ background: #dcf7e7; color: #0c6837; }}
        .badge.error {{ background: #ffe4e4; color: #991b1b; }}
        code {{ overflow-wrap: anywhere; }}
      </style>
    </head>
    <body>
      <main>
        <h1>Administracion privada</h1>
        <p>Validacion de API privada y base administrativa.</p>
        <section class="panel">
          <div class="row"><strong>Estado general</strong>{badge(payload["status"])}</div>
          <div class="row"><strong>API privada</strong>{badge(dependencies["api"]["status"])}</div>
          <div class="row"><strong>MySQL admin</strong>{badge(dependencies["admin_database"]["status"])}</div>
          <div class="row"><strong>Ultima revision</strong><code>{payload["checked_at"]}</code></div>
        </section>
      </main>
    </body>
    </html>
    """


@app.get("/health")
def health() -> JSONResponse:
    payload = health_payload()
    return JSONResponse(payload, status_code=200 if payload["status"] == "ok" else 503)
