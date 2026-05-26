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

# ==========================================
# LÓGICA DEL ETL (EXTRACTION, TRANSFORMATION, LOAD)
# ==========================================

def get_db_connection(prefix: str):
    host = os.getenv(f"{prefix}_HOST", "")
    database = os.getenv(f"{prefix}_DATABASE", "")
    user = os.getenv(f"{prefix}_USER", "")
    password = os.getenv(f"{prefix}_PASSWORD", "")

    if not all([host, database, user, password]):
        raise ValueError(f"Faltan credenciales para {prefix}")

    return pymysql.connect(
        host=host,
        port=MYSQL_PORT,
        user=user,
        password=password,
        database=database,
        connect_timeout=10,
        ssl={"check_hostname": False},
        cursorclass=pymysql.cursors.DictCursor 
    )

@app.post("/run")
def run_etl() -> dict:
    started_at = utc_now()
    conn_app = None
    conn_admin = None
    conn_analytics = None
    
    try:
        conn_app = get_db_connection("MYSQL_APP")
        conn_admin = get_db_connection("MYSQL_ADMIN")
        conn_analytics = get_db_connection("MYSQL_ANALYTICS")

        # 1. EXTRACT: Jalamos la data de los esquemas que nos pasaste
        with conn_admin.cursor() as cursor_admin:
            # Traemos empleados y sus salarios, solo los activos
            cursor_admin.execute("""
                SELECT id, department, salary, position 
                FROM employees 
                WHERE is_active = TRUE
            """)
            empleados = cursor_admin.fetchall()
            
        with conn_app.cursor() as cursor_app:
            # Traemos inventario de productos
            cursor_app.execute("""
                SELECT id, category, price, stock 
                FROM products 
                WHERE is_active = TRUE
            """)
            productos = cursor_app.fetchall()

        # 2. TRANSFORM: Armamos los KPIs usando list comprehensions de Python
        # KPI 1: Costo total de nómina mensual
        nomina_total = sum(emp['salary'] for emp in empleados if emp['salary'])
        
        # KPI 2: Cantidad de empleados por departamento
        dept_counts = {}
        for emp in empleados:
            dept = emp['department']
            dept_counts[dept] = dept_counts.get(dept, 0) + 1
            
        # KPI 3: Valor total del inventario en almacén
        valor_inventario = sum(prod['price'] * prod['stock'] for prod in productos)
        
        # KPI 4: Top categorías de productos por stock
        cat_stock = {}
        for prod in productos:
            cat = prod['category']
            cat_stock[cat] = cat_stock.get(cat, 0) + prod['stock']

        # Preparamos los registros para insertar en la tabla de analítica
        # Estructuramos la data como un par Clave-Valor genérico para el dashboard
        kpi_records = [
            {"kpi_name": "nomina_mensual_total", "kpi_value": float(nomina_total), "kpi_category": "Finanzas"},
            {"kpi_name": "valor_inventario_total", "kpi_value": float(valor_inventario), "kpi_category": "Operaciones"}
        ]
        
        for dept, count in dept_counts.items():
            kpi_records.append({"kpi_name": f"empleados_dept_{dept}", "kpi_value": float(count), "kpi_category": "Recursos Humanos"})
            
        for cat, stock in cat_stock.items():
            kpi_records.append({"kpi_name": f"stock_categoria_{cat}", "kpi_value": float(stock), "kpi_category": "Inventario"})

        # 3. LOAD: Lo metemos al Spoke 3 (Analytics)
        with conn_analytics.cursor() as cursor_analytics:
            # Creamos la tabla destino si no existe. 
            # Esto te salva la vida si el equipo de Infra no la incluyó en Terraform.
            cursor_analytics.execute("""
                CREATE TABLE IF NOT EXISTS kpi_summary (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    kpi_name VARCHAR(100) NOT NULL UNIQUE,
                    kpi_value DECIMAL(15,2) NOT NULL,
                    kpi_category VARCHAR(50) NOT NULL,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            """)
            
            # Upsert (Actualiza si el KPI ya existe, inserta si es nuevo)
            insert_query = """
                INSERT INTO kpi_summary (kpi_name, kpi_value, kpi_category) 
                VALUES (%(kpi_name)s, %(kpi_value)s, %(kpi_category)s)
                ON DUPLICATE KEY UPDATE 
                kpi_value = VALUES(kpi_value), 
                kpi_category = VALUES(kpi_category)
            """
            cursor_analytics.executemany(insert_query, kpi_records)
            conn_analytics.commit()

        return {
            "service": SERVICE_NAME, 
            "status": "success", 
            "message": "ETL ejecutado correctamente", 
            "kpis_procesados": len(kpi_records),
            "executed_at": started_at
        }

    except Exception as e:
        if conn_analytics: conn_analytics.rollback()
        return {
            "service": SERVICE_NAME, 
            "status": "error", 
            "message": str(e), 
            "executed_at": started_at
        }
        
    finally:
        if conn_app: conn_app.close()
        if conn_admin: conn_admin.close()
        if conn_analytics: conn_analytics.close()
