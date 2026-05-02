import os
from datetime import datetime, timezone

import requests
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse


SERVICE_NAME = os.getenv("SERVICE_NAME", "web-intranet")
API_BASE_URL = os.getenv("API_BASE_URL", "https://api.northwind.lab").rstrip("/")
API_HEALTH_PATH = os.getenv("API_HEALTH_PATH", "/health")
REQUEST_TIMEOUT_SECONDS = float(os.getenv("REQUEST_TIMEOUT_SECONDS", "4"))
VERIFY_TLS = os.getenv("VERIFY_TLS", "true").lower() == "true"

app = FastAPI(title=SERVICE_NAME)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def check_api() -> dict:
    health_url = f"{API_BASE_URL}{API_HEALTH_PATH}"
    started = datetime.now(timezone.utc)

    try:
        response = requests.get(
            health_url,
            timeout=REQUEST_TIMEOUT_SECONDS,
            verify=VERIFY_TLS,
        )
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        payload = response.json() if response.headers.get("content-type", "").startswith("application/json") else {}
        return {
            "name": "api-private",
            "status": "ok" if response.ok else "error",
            "url": health_url,
            "http_status": response.status_code,
            "elapsed_ms": elapsed_ms,
            "details": payload,
        }
    except Exception as exc:
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {
            "name": "api-private",
            "status": "error",
            "url": health_url,
            "elapsed_ms": elapsed_ms,
            "error": str(exc),
        }


def health_payload() -> dict:
    dependency = check_api()
    service_status = "ok" if dependency["status"] == "ok" else "degraded"
    return {
        "service": SERVICE_NAME,
        "status": service_status,
        "checked_at": utc_now(),
        "dependencies": {"api": dependency},
    }


def render_status_badge(status: str) -> str:
    label = "Conectado" if status == "ok" else "Con error"
    return f'<span class="badge {status}">{label}</span>'


@app.get("/", response_class=HTMLResponse)
def index() -> str:
    payload = health_payload()
    api_status = payload["dependencies"]["api"]
    overall_class = "ok" if payload["status"] == "ok" else "error"

    return f"""
    <!doctype html>
    <html lang="es">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <meta http-equiv="refresh" content="20" />
      <title>{SERVICE_NAME}</title>
      <style>
        :root {{ font-family: Arial, sans-serif; color: #172033; background: #f5f7fb; }}
        body {{ margin: 0; padding: 32px; }}
        main {{ max-width: 920px; margin: 0 auto; }}
        h1 {{ margin: 0 0 8px; font-size: 30px; }}
        .subtitle {{ color: #5d667a; margin: 0 0 28px; }}
        .panel {{ background: #fff; border: 1px solid #dde3ee; border-radius: 8px; padding: 22px; box-shadow: 0 8px 24px rgba(23, 32, 51, .06); }}
        .status-line {{ display: flex; align-items: center; justify-content: space-between; gap: 16px; flex-wrap: wrap; }}
        .badge {{ display: inline-flex; align-items: center; border-radius: 999px; padding: 8px 12px; font-weight: 700; font-size: 14px; }}
        .badge.ok {{ background: #dff7e8; color: #0b6b38; }}
        .badge.error, .badge.degraded {{ background: #ffe5e5; color: #9d1c1c; }}
        .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; margin-top: 18px; }}
        .metric {{ border: 1px solid #e4e9f2; border-radius: 8px; padding: 16px; background: #fbfcff; }}
        .metric strong {{ display: block; margin-bottom: 6px; }}
        code {{ overflow-wrap: anywhere; color: #334155; }}
        pre {{ white-space: pre-wrap; overflow-wrap: anywhere; background: #172033; color: #ecf2ff; border-radius: 8px; padding: 16px; }}
      </style>
    </head>
    <body>
      <main>
        <h1>Intranet privada</h1>
        <p class="subtitle">Validacion grafica de conectividad entre frontend, API y servicios privados.</p>
        <section class="panel">
          <div class="status-line">
            <div>
              <strong>Estado general</strong><br />
              <span>Ultima revision: {payload["checked_at"]}</span>
            </div>
            {render_status_badge("ok" if overall_class == "ok" else "degraded")}
          </div>
          <div class="grid">
            <div class="metric">
              <strong>API privada</strong>
              {render_status_badge(api_status["status"])}
            </div>
            <div class="metric">
              <strong>Endpoint consultado</strong>
              <code>{api_status["url"]}</code>
            </div>
            <div class="metric">
              <strong>Latencia</strong>
              <span>{api_status.get("elapsed_ms", "n/a")} ms</span>
            </div>
          </div>
          <pre>{payload}</pre>
        </section>
      </main>
    </body>
    </html>
    """


@app.get("/health")
def health() -> JSONResponse:
    payload = health_payload()
    return JSONResponse(payload, status_code=200 if payload["status"] == "ok" else 503)
