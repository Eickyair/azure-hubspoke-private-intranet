import os
import requests
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles

app = FastAPI(title="Catalog WebApp")

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

templates = Jinja2Templates(directory="templates")

API_EXTERNAL_URL = os.getenv("API_EXTERNAL_URL", "http://localhost:8002/api")
API_INTERNAL_URL = os.getenv("API_INTERNAL_URL", "http://localhost:8002")

@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    return templates.TemplateResponse(
        "index.html", 
        {"request": request, "api_url": API_EXTERNAL_URL}
    )

@app.get("/live")
def live():
    return {"service": "catalog-webapp", "status": "ok"}

@app.get("/health")
def health():
    try:
        response = requests.get(f"{API_INTERNAL_URL}/health", timeout=3)
        api_status = response.json()
        status = "ok" if response.status_code == 200 and api_status.get("status") == "ok" else "degraded"
    except Exception as exc:
        status = "degraded"
        api_status = {"status": "error", "error": str(exc)}

    payload = {"service": "catalog-webapp", "status": status, "api_dependency": api_status}
    return JSONResponse(payload, status_code=200 if status == "ok" else 503)
