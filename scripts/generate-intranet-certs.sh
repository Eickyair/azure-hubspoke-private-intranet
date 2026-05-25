#!/bin/bash
set -e

# Ruta del repositorio
REPO_DIR="/home/erick/Documents/github/azure-hubspoke-private-intranet"

# Crear directorio si no existe
mkdir -p "$REPO_DIR/terraform/.vpn-certs"

# Ruta de salida
OUT_DIR="$REPO_DIR/terraform/.vpn-certs"
PASSWORD="" # Contraseña del PFX vacía para compatibilidad con Application Gateway integrado con Key Vault

echo "Generando llave privada para CA interna..."
openssl genrsa -out "$OUT_DIR/ca.key" 4096

echo "Generando certificado de CA auto-firmado..."
openssl req -x509 -new -nodes -key "$OUT_DIR/ca.key" -sha256 -days 3650 \
  -subj "/CN=Northwind Private Root CA/O=Northwind/C=MX" \
  -out "$OUT_DIR/ca.crt"

echo "Generando llave privada para el Application Gateway..."
openssl genrsa -out "$OUT_DIR/intranet-wildcard.key" 2048

echo "Creando archivo de configuración para la petición del certificado con SANs..."
cat <<EOF > "$OUT_DIR/openssl-san.cnf"
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = MX
O = Northwind
CN = *.northwind.lab

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.northwind.lab
DNS.2 = intranet.northwind.lab
DNS.3 = admin.northwind.lab
DNS.4 = api.northwind.lab
EOF

echo "Creando petición de firma de certificado (CSR)..."
openssl req -new -key "$OUT_DIR/intranet-wildcard.key" \
  -config "$OUT_DIR/openssl-san.cnf" \
  -out "$OUT_DIR/intranet-wildcard.csr"

echo "Creando archivo de extensiones para la firma del certificado..."
cat <<EOF > "$OUT_DIR/v3-ext.cnf"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.northwind.lab
DNS.2 = intranet.northwind.lab
DNS.3 = admin.northwind.lab
DNS.4 = api.northwind.lab
EOF

echo "Firmando el certificado con la CA interna..."
openssl x509 -req -in "$OUT_DIR/intranet-wildcard.csr" \
  -CA "$OUT_DIR/ca.crt" -CAkey "$OUT_DIR/ca.key" \
  -CAcreateserial -out "$OUT_DIR/intranet-wildcard.crt" \
  -days 3650 -sha256 -extfile "$OUT_DIR/v3-ext.cnf"

echo "Empaquetando en formato PFX (PKCS#12)..."
openssl pkcs12 -export \
  -out "$OUT_DIR/cert-northwind-lab.pfx" \
  -inkey "$OUT_DIR/intranet-wildcard.key" \
  -in "$OUT_DIR/intranet-wildcard.crt" \
  -certfile "$OUT_DIR/ca.crt" \
  -passout "pass:$PASSWORD"

echo "Certificados generados exitosamente en $OUT_DIR/"
