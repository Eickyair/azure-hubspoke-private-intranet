#!/usr/bin/env bash
set -euo pipefail

# Directorio de certificados
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERTS_DIR="${REPO_ROOT}/vpn-certs"
mkdir -p "${CERTS_DIR}"

echo "=== Generando certificados autofirmados para VPN en ${CERTS_DIR} ==="

# Variables
ROOT_NAME="p2s-root-cert"
CLIENT_NAME="p2s-client-cert"
DAYS_VALID=3650
CLIENT_DAYS_VALID=365
PFX_PASSWORD="VpnPassword123!"

# 1. Generar la clave privada de la CA Raíz
echo "1. Generando clave privada de la CA Raíz..."
openssl genrsa -out "${CERTS_DIR}/ca.key" 2048

# 2. Generar el certificado de la CA Raíz
echo "2. Generando certificado autofirmado de la CA Raíz..."
openssl req -x509 -new -nodes \
  -key "${CERTS_DIR}/ca.key" \
  -sha256 \
  -days ${DAYS_VALID} \
  -subj "/CN=${ROOT_NAME}" \
  -out "${CERTS_DIR}/ca.crt"

# 3. Generar la clave privada del cliente
echo "3. Generando clave privada del cliente..."
openssl genrsa -out "${CERTS_DIR}/client.key" 2048

# 4. Generar la solicitud de firma de certificado (CSR) para el cliente
echo "4. Generando CSR para el cliente..."
openssl req -new \
  -key "${CERTS_DIR}/client.key" \
  -subj "/CN=${CLIENT_NAME}" \
  -out "${CERTS_DIR}/client.csr"

# 5. Firmar el certificado del cliente con la CA Raíz (incluyendo EKU para Client Authentication)
echo "5. Firmando certificado del cliente con la CA Raíz..."
cat <<EOF > "${CERTS_DIR}/client.ext"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

openssl x509 -req \
  -in "${CERTS_DIR}/client.csr" \
  -CA "${CERTS_DIR}/ca.crt" \
  -CAkey "${CERTS_DIR}/ca.key" \
  -CAcreateserial \
  -days ${CLIENT_DAYS_VALID} \
  -sha256 \
  -extfile "${CERTS_DIR}/client.ext" \
  -out "${CERTS_DIR}/client.crt"

rm "${CERTS_DIR}/client.ext"

# 6. Exportar el certificado del cliente a formato PFX (PKCS#12)
echo "6. Exportando certificado del cliente a formato PFX..."
openssl pkcs12 -export \
  -in "${CERTS_DIR}/client.crt" \
  -inkey "${CERTS_DIR}/client.key" \
  -certfile "${CERTS_DIR}/ca.crt" \
  -name "${CLIENT_NAME}" \
  -passout "pass:${PFX_PASSWORD}" \
  -out "${CERTS_DIR}/client.pfx"

# 7. Extraer la clave pública base64 del certificado raíz para Terraform
echo "7. Extrayendo certificado raíz base64 formateado para Terraform..."
TF_CERT_DATA=$(grep -v '^-' "${CERTS_DIR}/ca.crt" | tr -d '\n' | tr -d '\r')

echo "=========================================================="
echo "¡Certificados creados exitosamente en ${CERTS_DIR}!"
echo "=========================================================="
echo "Archivos generados:"
echo " - ca.key        : Clave privada de la CA (MANTENER PRIVADA)"
echo " - ca.crt        : Certificado público de la CA"
echo " - client.key    : Clave privada del cliente (MANTENER PRIVADA)"
echo " - client.crt    : Certificado público del cliente"
echo " - client.pfx    : Certificado del cliente en formato PFX (contraseña: ${PFX_PASSWORD})"
echo "=========================================================="
echo "Copia el siguiente bloque de texto en tu archivo 'main.tfvars':"
echo ""
echo "vpn_root_certificate_data = \"${TF_CERT_DATA}\""
echo "=========================================================="

# Guardar temporalmente el valor de base64 en un archivo de texto para que Terraform o el script lo lea fácilmente
echo "${TF_CERT_DATA}" > "${CERTS_DIR}/ca_base64.txt"
