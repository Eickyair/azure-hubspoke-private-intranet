from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI(title="Catalog WebApp")

@app.get("/", response_class=HTMLResponse)
def read_root():
    return """
    <html>
        <head><title>Catálogo de Productos</title></head>
        <body style="font-family: sans-serif; text-align: center; margin-top: 50px;">
            <h1>Bienvenido al Catálogo de Productos</h1>
            <p>El desarrollo del frontend comenzará aquí.</p>
        </body>
    </html>
    """
