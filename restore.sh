#!/bin/bash
# ===========================================================================
# SISTEMA DE RESTAURACIÓN PROFESIONAL - CONTICS-NETBIRD
# ===========================================================================
# Descripción: Recupera datos de Drive, inyecta volúmenes Docker y 
#              sincroniza el script de backup con la última versión de GitHub.
# ===========================================================================

# 1. CONFIGURACIÓN DE RUTAS
PROJECT_DIR="/home/ubuntu/netbird"
REMOTE_FOLDER="CONTICS-NETBIRD-BACKUP-PROD"
TEMP_RESTORE="/tmp/restore_temp"
GITHUB_RAW_URL="https://raw.githubusercontent.com/emerson101293/contics-infra/main/backup.sh"

echo "=== ⚠️ INICIANDO PROCESO DE RESTAURACIÓN MAESTRA (CONTICS) ==="

# 2. VERIFICACIÓN DE DEPENDENCIAS
if ! rclone listremotes | grep -q "^drive:"; then
    echo "❌ Error: Rclone no está configurado. Ejecuta 'rclone config' primero."
    exit 1
fi

# 3. SELECCIÓN DEL RESPALDO
echo "📂 Listando respaldos disponibles en Google Drive..."
rclone lsl "drive:$REMOTE_FOLDER"
echo ""
echo "Escriba el nombre exacto del archivo .tar.gz que desea restaurar:"
read BACKUP_FILE

# 4. DESCARGA DEL PAQUETE
echo "☁️ Descargando backup desde la nube..."
rclone copy "drive:$REMOTE_FOLDER/$BACKUP_FILE" /tmp/ -P

if [ ! -f "/tmp/$BACKUP_FILE" ]; then
    echo "❌ Error: No se pudo descargar el archivo de Drive."
    exit 1
fi

# 5. PREPARACIÓN DEL ENTORNO
mkdir -p "$PROJECT_DIR"
echo "🛑 Deteniendo servicios actuales para evitar corrupción..."
cd "$PROJECT_DIR" && docker compose down 2>/dev/null

# 6. EXTRACCIÓN TEMPORAL
echo "🧹 Limpiando y preparando archivos..."
rm -rf $TEMP_RESTORE && mkdir -p $TEMP_RESTORE
tar -xzf "/tmp/$BACKUP_FILE" -C $TEMP_RESTORE

# 7. TRASPLANTE DE DATOS (INYECCIÓN EN VOLÚMENES DOCKER)
echo "📦 Inyectando bases de datos en volúmenes Docker..."
# Inyección para Management
docker run --rm -v netbird_netbird_management:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_mgmt.tar.gz -C ."
# Inyección para Zitadel/ZDB
docker run --rm -v netbird_netbird_zdb_data:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_zdb.tar.gz -C ."

# 8. RESTAURACIÓN DE CONFIGURACIONES FÍSICAS
echo "📝 Restaurando archivos de configuración del proyecto..."
cp -r $TEMP_RESTORE/* "$PROJECT_DIR/"
# Limpiar archivos .tar.gz que quedaron en la carpeta del proyecto
rm -f "$PROJECT_DIR"/*.tar.gz

# 9. SINCRONIZACIÓN CON EL CEREBRO (GITHUB)
echo "🔄 Sincronizando lógica de backup con GitHub (Versión Public)..."
curl -fsSL "$GITHUB_RAW_URL" -o "$PROJECT_DIR/backup.sh"

if [ $? -eq 0 ]; then
    chmod +x "$PROJECT_DIR/backup.sh"
    sed -i 's/\r$//' "$PROJECT_DIR/backup.sh"
    echo "✅ Script backup.sh actualizado desde GitHub."
else
    echo "⚠️ Advertencia: No se pudo conectar a GitHub. Se usará el script del backup."
    chmod +x "$PROJECT_DIR/backup.sh"
fi

# 10. ARRANQUE DEL SISTEMA
echo "🚀 Levantando red NetBird de CONTICS..."
docker compose up -d

# 11. AUTOMATIZACIÓN DEL SEGURO DE VIDA (CRONTAB)
echo "⏰ Asegurando programación de respaldo diario (03:00 AM)..."
(crontab -l 2>/dev/null | grep -v "backup.sh"; echo "00 03 * * * $PROJECT_DIR/backup.sh > $PROJECT_DIR/backup.log 2>&1") | crontab -

# 12. LIMPIEZA DE HUELLAS
rm -rf $TEMP_RESTORE
rm "/tmp/$BACKUP_FILE"

echo "=== ✅ PROCESO FINALIZADO CON ÉXITO ==="
echo "NetBird está operativo y los respaldos diarios han sido re-activados."
