from fastapi import FastAPI
import os

app = FastAPI(title="Catalog API")
SERVICE_NAME = os.getenv("SERVICE_NAME", "catalog-api")

@app.get("/")
def read_root():
    return {"service": SERVICE_NAME, "status": "running", "message": "Product Catalog API is ready."}
