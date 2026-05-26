# Guía de Configuración del Cliente VPN (Windows & Linux)

Esta guía detalla cómo configurar un equipo local (Host) con sistema operativo **Linux** o **Windows** para establecer una conexión VPN Point-to-Site (P2S) segura con la red interna en Azure.

Como el Gateway de VPN está configurado con el SKU `VpnGw1AZ` y el protocolo **OpenVPN**, utilizaremos perfiles `.ovpn` y autenticación basada en los certificados generados.

---

## Prerrequisitos

Antes de configurar tu cliente, necesitas tener a la mano:
1. **Los archivos de certificados generados en tu host:**
   * `vpn-certs/client.crt` (Certificado del cliente)
   * `vpn-certs/client.key` (Clave privada del cliente)
2. **El perfil de configuración de Azure VPN (archivo ZIP):**
   * Puedes descargarlo desde el Azure Portal ingresando al recurso **Virtual Network Gateway** (`vpngw-privintra-lab-001-hub`) -> sección **Configuración de punto a sitio** -> **Descargar cliente de VPN**.
   * O a través de la terminal usando Azure CLI:
     ```bash
     az network vnet-gateway vpn-client generate \
       --resource-group dream-team-tf \
       --name vpngw-privintra-lab-001-hub
     ```
     Descarga el enlace ZIP proporcionado y descomprímelo.

---

## Configuración en Linux (Ubuntu/Debian)

### Paso 1: Instalar dependencias
Instala el cliente oficial de OpenVPN y la integración con el gestor de red NetworkManager:
```bash
sudo apt update && sudo apt install -y openvpn network-manager-openvpn-gnome
sudo systemctl restart NetworkManager
```

### Paso 2: Preparar el archivo de configuración `.ovpn`
1. Abre tu gestor de archivos y entra en la carpeta descomprimida del perfil VPN. Abre la carpeta `OpenVPN` y localiza el archivo `vpnconfig.ovpn`.
2. Abre `vpnconfig.ovpn` con un editor de texto.
3. Busca la línea `auth-user-pass` y coméntala agregando un `;` al inicio para desactivar la autenticación de usuario/contraseña (ya que usamos certificados):
   ```
   ;auth-user-pass
   ```
4. Ve al final del archivo y añade las etiquetas `<cert>` y `<key>`, copiando dentro de ellas el contenido exacto de los archivos generados en `vpn-certs/client.crt` y `vpn-certs/client.key`:
   ```xml
   <cert>
   -----BEGIN CERTIFICATE-----
   (Copia y pega TODO el texto de tu archivo vpn-certs/client.crt aquí)
   -----END CERTIFICATE-----
   </cert>

   <key>
   -----BEGIN PRIVATE KEY-----
   (Copia y pega TODO el texto de tu archivo vpn-certs/client.key aquí)
   -----END PRIVATE KEY-----
   </key>
   ```
5. Guarda y cierra el archivo `vpnconfig.ovpn`.

### Paso 3: Conectar a la VPN
Puedes conectarte de dos maneras:

#### Opción A: Desde la Terminal (Recomendado para pruebas rápidas)
Ejecuta el siguiente comando apuntando a tu archivo `.ovpn` modificado:
```bash
sudo openvpn --config vpnconfig.ovpn
```
*Mantén la terminal abierta mientras utilices la VPN.*

#### Opción B: Desde la Interfaz Gráfica (Network Manager)
1. Ve a la **Configuración** de tu sistema -> **Red (Network)**.
2. En la sección **VPN**, haz clic en **+**.
3. Selecciona **Importar desde archivo...** y elige tu archivo `vpnconfig.ovpn` modificado.
4. Haz clic en **Añadir**.
5. Activa el interruptor para conectarte.

---

## Configuración en Windows

### Paso 1: Instalar el cliente de OpenVPN
1. Descarga e instala la herramienta oficial **OpenVPN Connect para Windows** desde su sitio web oficial ([https://openvpn.net/client-connect-vpn-for-windows/](https://openvpn.net/client-connect-vpn-for-windows/)).

### Paso 2: Preparar el archivo de configuración `.ovpn`
El procedimiento es el mismo que en Linux:
1. Abre la carpeta `OpenVPN` del archivo ZIP descomprimido y edita el archivo `vpnconfig.ovpn` con el **Bloc de Notas** o VS Code.
2. Comenta la línea `auth-user-pass` colocando un `;` o `#` al principio:
   ```
   ;auth-user-pass
   ```
3. Al final del archivo, agrega los bloques `<cert>` y `<key>` con el contenido del certificado de cliente (`client.crt`) y su clave privada (`client.key`) generados en la carpeta `vpn-certs/` del host:
   ```xml
   <cert>
   -----BEGIN CERTIFICATE-----
   (Copia y pega el contenido del archivo client.crt)
   -----END CERTIFICATE-----
   </cert>

   <key>
   -----BEGIN PRIVATE KEY-----
   (Copia y pega el contenido del archivo client.key)
   -----END PRIVATE KEY-----
   </key>
   ```
4. Guarda los cambios.

### Paso 3: Importar y Conectar
1. Abre la aplicación **OpenVPN Connect**.
2. Ve a la pestaña **File** (Archivo).
3. Arrastra y suelta tu archivo `vpnconfig.ovpn` modificado dentro de la ventana de la aplicación (o haz clic en *Browse* para buscarlo).
4. Haz clic en **Import** (Importar).
5. Activa el perfil importado haciendo clic en el interruptor de encendido para conectarte.

---

## Verificación de Conectividad
Una vez conectado (en Windows o Linux), puedes validar tu acceso privado haciendo ping a las IPs de la arquitectura interna o intentando resolver DNS locales desde tu navegador o terminal:
* **Base de datos MySQL local:** `mysql-privintra-lab-001-analytics.mysql.database.azure.com` (IP del Private Endpoint `10.10.x.x`).
* **App Service privada (Intranet):** `intranet.northwind.lab` (IP local del App Gateway `10.10.2.10`).
