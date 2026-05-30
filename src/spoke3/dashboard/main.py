import os
import requests
import pymysql
import streamlit as st

st.set_page_config(page_title="Northwind KPI Dashboard", page_icon="📊", layout="wide")
st.title("📊 Dashboard de Analítica - Northwind")
st.markdown("Métricas clave de negocio extraídas desde el Spoke 2.")

MYSQL_PORT   = int(os.getenv("MYSQL_PORT", "3306"))
ETL_RUN_URL  = os.getenv("ETL_RUN_URL", "http://localhost:8000/run")

@st.cache_data(ttl=60)
def get_kpi_data():
    host     = os.getenv("MYSQL_ANALYTICS_HOST", "127.0.0.1")
    database = os.getenv("MYSQL_ANALYTICS_DATABASE", "intranet_analytics")
    user     = os.getenv("MYSQL_ANALYTICS_USER", "root")
    password = os.getenv("MYSQL_ANALYTICS_PASSWORD", "labadmin")

    try:
        conn = pymysql.connect(
            host=host, port=MYSQL_PORT, user=user, password=password,
            database=database, connect_timeout=10,
            ssl={"check_hostname": False},
            cursorclass=pymysql.cursors.DictCursor,
        )
        with conn.cursor() as cursor:
            cursor.execute("SELECT kpi_name, kpi_value, kpi_category, updated_at FROM kpi_summary")
            data = cursor.fetchall()
        conn.close()
        return data
    except Exception as e:
        st.error(f"Error conectando a la base de datos de Analítica: {e}")
        return []

def run_etl():
    try:
        resp = requests.post(ETL_RUN_URL, timeout=30)
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.ConnectionError:
        return {"status": "error", "message": f"No se pudo conectar al ETL en {ETL_RUN_URL}"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ── Barra lateral: control ETL ────────────────────────────────────────────────
with st.sidebar:
    st.header("Control ETL")
    st.caption(f"Runner: `{ETL_RUN_URL}`")

    if st.button("▶ Ejecutar ETL", type="primary", use_container_width=True):
        with st.spinner("Ejecutando ETL..."):
            result = run_etl()

        if result.get("status") == "success":
            st.success(f"ETL completado — {result.get('kpis_procesados', '?')} KPIs procesados")
            get_kpi_data.clear()
            st.rerun()
        else:
            st.error(f"Error: {result.get('message', result)}")

    st.divider()
    if st.button("🔄 Refrescar datos", use_container_width=True):
        get_kpi_data.clear()
        st.rerun()

# ── Cuerpo principal ──────────────────────────────────────────────────────────
datos_kpi = get_kpi_data()

if not datos_kpi:
    st.warning("No hay datos en la tabla kpi_summary. Usa el botón **▶ Ejecutar ETL** del panel izquierdo.")
else:
    nomina     = next((d['kpi_value'] for d in datos_kpi if d['kpi_name'] == 'nomina_mensual_total'), 0)
    inventario = next((d['kpi_value'] for d in datos_kpi if d['kpi_name'] == 'valor_inventario_total'), 0)

    st.subheader("Indicadores Globales")
    col1, col2 = st.columns(2)
    with col1:
        st.metric("Nomina Mensual Activa", f"${nomina:,.2f} MXN")
    with col2:
        st.metric("Valor del Inventario", f"${inventario:,.2f} MXN")

    st.divider()

    col_chart1, col_chart2 = st.columns(2)
    with col_chart1:
        st.subheader("Empleados por Departamento")
        dept_data = {
            d['kpi_name'].replace('empleados_dept_', ''): d['kpi_value']
            for d in datos_kpi if d['kpi_name'].startswith('empleados_dept_')
        }
        if dept_data:
            st.bar_chart(dept_data)

    with col_chart2:
        st.subheader("Stock por Categoría")
        cat_data = {
            d['kpi_name'].replace('stock_categoria_', ''): d['kpi_value']
            for d in datos_kpi if d['kpi_name'].startswith('stock_categoria_')
        }
        if cat_data:
            st.bar_chart(cat_data)

    ultimo_update = datos_kpi[0]['updated_at'] if datos_kpi else "Desconocido"
    st.caption(f"Última ejecución del ETL: {ultimo_update}")
