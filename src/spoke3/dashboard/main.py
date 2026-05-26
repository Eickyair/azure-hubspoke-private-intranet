import os
import pymysql
import streamlit as st

# Configuración de la página
st.set_page_config(page_title="Northwind KPI Dashboard", page_icon="📊", layout="wide")
st.title("📊 Dashboard de Analítica - Northwind")
st.markdown("Métricas clave de negocio extraídas desde el Spoke 2.")

MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))

# Función para conectarse a la base de analítica
@st.cache_data(ttl=60) # Hace caché por 60 segundos para no saturar la BD
def get_kpi_data():
    # Toma las variables de entorno inyectadas por Azure o tu local
    host = os.getenv("MYSQL_ANALYTICS_HOST", "127.0.0.1")
    database = os.getenv("MYSQL_ANALYTICS_DATABASE", "intranet_analytics")
    user = os.getenv("MYSQL_ANALYTICS_USER", "root")
    password = os.getenv("MYSQL_ANALYTICS_PASSWORD", "labadmin")

    try:
        conn = pymysql.connect(
            host=host,
            port=MYSQL_PORT,
            user=user,
            password=password,
            database=database,
            connect_timeout=10,
            ssl={"check_hostname": False},
            cursorclass=pymysql.cursors.DictCursor
        )
        with conn.cursor() as cursor:
            cursor.execute("SELECT kpi_name, kpi_value, kpi_category, updated_at FROM kpi_summary")
            data = cursor.fetchall()
        conn.close()
        return data
    except Exception as e:
        st.error(f"Error conectando a la base de datos de Analítica: {e}")
        return []

# Extraer la data
datos_kpi = get_kpi_data()

if not datos_kpi:
    st.warning("No hay datos en la tabla kpi_summary. ¿Ya ejecutaste el ETL en http://localhost:8010/docs ?")
else:
    # --- PROCESAMIENTO BÁSICO ---
    # Convertimos la lista de diccionarios a variables más fáciles de usar
    nomina = next((item['kpi_value'] for item in datos_kpi if item['kpi_name'] == 'nomina_mensual_total'), 0)
    inventario = next((item['kpi_value'] for item in datos_kpi if item['kpi_name'] == 'valor_inventario_total'), 0)
    
    # --- SECCIÓN 1: KPIs SUPERIORES ---
    st.subheader("Indicadores Globales")
    col1, col2 = st.columns(2)
    with col1:
        st.metric(label="Nomina Mensual Activa", value=f"${nomina:,.2f} MXN")
    with col2:
        st.metric(label="Valor del Inventario", value=f"${inventario:,.2f} MXN")

    st.divider()

    # --- SECCIÓN 2: GRÁFICAS ---
    col_chart1, col_chart2 = st.columns(2)
    
    with col_chart1:
        st.subheader("Empleados por Departamento")
        # Filtramos los kpis que empiezan con 'empleados_dept_'
        dept_data = {item['kpi_name'].replace('empleados_dept_', ''): item['kpi_value'] 
                     for item in datos_kpi if item['kpi_name'].startswith('empleados_dept_')}
        if dept_data:
            st.bar_chart(dept_data)

    with col_chart2:
        st.subheader("Stock por Categoría")
        # Filtramos los kpis que empiezan con 'stock_categoria_'
        cat_data = {item['kpi_name'].replace('stock_categoria_', ''): item['kpi_value'] 
                    for item in datos_kpi if item['kpi_name'].startswith('stock_categoria_')}
        if cat_data:
            st.bar_chart(cat_data)
            
    # Timestamp de última actualización
    ultimo_update = datos_kpi[0]['updated_at'] if datos_kpi else "Desconocido"
    st.caption(f"Última ejecución del ETL: {ultimo_update}")
