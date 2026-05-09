import os
import requests
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles

SERVICE_NAME = os.getenv("SERVICE_NAME", "web-intranet")
# For backend-to-backend calls (e.g. Docker network)
API_INTERNAL_URL = os.getenv("API_INTERNAL_URL", "http://localhost:8000")
# For frontend browser calls
API_EXTERNAL_URL = os.getenv("API_EXTERNAL_URL", "http://localhost:8000/api")
CATALOG_API_EXTERNAL_URL = os.getenv("CATALOG_API_EXTERNAL_URL", "http://localhost:8002/api")

app = FastAPI(title=SERVICE_NAME)

templates = Jinja2Templates(directory="templates")
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("index.html", {
        "request": request, 
        "api_base_url": API_EXTERNAL_URL,
        "catalog_api_url": CATALOG_API_EXTERNAL_URL
    })

@app.get("/health")
def health():
    try:
        r = requests.get(f"{API_INTERNAL_URL}/health", timeout=2)
        api_status = r.json()
    except Exception as e:
        api_status = {"status": "error", "error": str(e)}
    return {"status": "ok", "service": SERVICE_NAME, "api_dependency": api_status}
