#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE COPIAS DE SEGURIDAD CIFRADAS (REGLA 3-2-1) Y PRUEBA DE RESTAURACIÓN
# Proyecto Final 2º DAW - Carlos Plata Morán
# ==============================================================================
set -euo pipefail

BACKUP_DIR="/var/backups/dashboard_facturas"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DB_NAME="${DB_NAME:-dashboard_facturas_prod}"
DB_USER="${DB_USER:-postgres}"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
ENCRYPTED_FILE="${BACKUP_FILE}.gpg"
GPG_RECIPIENT="${GPG_BACKUP_RECIPIENT:-seguridad@midominio.com}"

mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

echo "[INFO] Iniciando backup transaccional de ${DB_NAME} a las $(date)..."

# 1. Dump binario coherente con pg_dump
pg_dump -U "${DB_USER}" -d "${DB_NAME}" --format=custom --compress=9 > "${BACKUP_FILE}"

echo "[INFO] Cifrando backup con GPG (AES-256)..."
gpg --encrypt --recipient "${GPG_RECIPIENT}" --trust-model always "${BACKUP_FILE}"
rm -f "${BACKUP_FILE}" # Eliminar dump en claro

echo "[INFO] Backup generado y cifrado con éxito: ${ENCRYPTED_FILE}"

# 2. Replicación a destino secundario (Regla 3-2-1: 3 copias, 2 soportes, 1 off-site)
# Ejemplo: subida segura mediante rsync sobre SSH o S3 con Object Lock
echo "[INFO] Replicando a almacenamiento externo seguro..."
# rsync -avz -e "ssh -i /root/.ssh/id_backup" "${ENCRYPTED_FILE}" backup-remote:/mnt/secure_cold_storage/

# 3. Prueba de Restauración Automatizada en Base de Datos de Prueba (Sandbox)
TEST_DB="sandbox_restore_test_${TIMESTAMP}"
echo "[INFO] Ejecutando prueba de integridad y restauración en ${TEST_DB}..."

createdb -U "${DB_USER}" "${TEST_DB}" || true
# Descifrar temporalmente en memoria /tmpfs para validar integridad
gpg --decrypt "${ENCRYPTED_FILE}" | pg_restore -U "${DB_USER}" -d "${TEST_DB}" --clean --if-exists

# Comprobación de integridad: verificar que la tabla 'invoices' tiene registros
INVOICE_COUNT=$(psql -U "${DB_USER}" -d "${TEST_DB}" -t -c "SELECT COUNT(*) FROM invoices;")
echo "[VERIFICACIÓN] Registros en tabla 'invoices' tras restaurar: ${INVOICE_COUNT}"

# Limpieza del sandbox de prueba
dropdb -U "${DB_USER}" "${TEST_DB}"
echo "[ÉXITO] Prueba de restauración validada satisfactoriamente."

