import os
from datetime import datetime, timezone

import pymysql
import requests
import streamlit as st


SERVICE_NAME = os.getenv("SERVICE_NAME", "dashboard-kpi-01")
ETL_HEALTH_URL = os.getenv("ETL_HEALTH_URL", "http://etl-runner-01:8000/health")
REQUEST_TIMEOUT_SECONDS = float(os.getenv("REQUEST_TIMEOUT_SECONDS", "4"))
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))


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


def check_etl() -> dict:
    started = datetime.now(timezone.utc)
    try:
        response = requests.get(ETL_HEALTH_URL, timeout=REQUEST_TIMEOUT_SECONDS)
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {"name": "etl-runner", "status": "ok" if response.ok else "error", "url": ETL_HEALTH_URL, "http_status": response.status_code, "elapsed_ms": elapsed_ms}
    except Exception as exc:
        elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        return {"name": "etl-runner", "status": "error", "url": ETL_HEALTH_URL, "elapsed_ms": elapsed_ms, "error": str(exc)}


def render_card(title: str, result: dict) -> None:
    status = result.get("status", "unknown")
    if status == "ok":
        st.success(f"{title}: conectado")
    elif status == "not_configured":
        st.warning(f"{title}: variables pendientes")
    else:
        st.error(f"{title}: error")
    st.json(result)


st.set_page_config(page_title=SERVICE_NAME, page_icon="OK", layout="wide")
st.title("Dashboard interno de analitica")
st.caption(f"Revision: {datetime.now(timezone.utc).isoformat()}")

checks = {
    "MySQL Analytics": check_mysql("MYSQL_ANALYTICS", "mysql-analytics-db"),
    "MySQL App Source": check_mysql("MYSQL_APP", "mysql-app-db"),
    "MySQL Admin Source": check_mysql("MYSQL_ADMIN", "mysql-admin-db"),
    "ETL Runner": check_etl(),
}

overall_ok = all(item["status"] == "ok" for item in checks.values())
st.metric("Estado general", "OK" if overall_ok else "Revisar")

columns = st.columns(2)
for index, (title, result) in enumerate(checks.items()):
    with columns[index % 2]:
        render_card(title, result)
