#!/bin/bash
# ===========================================================================
# SISTEMA DE RESTAURACIÓN UNIVERSAL - CONTICS-NETBIRD (OPTIMIZADO)
# ===========================================================================
# Autor: Gemino - CONTICS
# Funcionalidad: Restaura desde Drive + Notifica a Telegram + Configura GitHub
# ===========================================================================

# 1. CONFIGURACIÓN DINÁMICA Y TELEGRAM
PROJECT_DIR="$HOME/netbird"
REMOTE_FOLDER="CONTICS-NETBIRD-BACKUP-PROD"
TEMP_RESTORE="/tmp/restore_temp"
# URL de tu script optimizado en GitHub (Lanzador)
GITHUB_PRO_URL="https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/backup_pro_contics.sh"

# Credenciales de Telegram
TOKEN="8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak"
CHAT_ID="6902736310"

enviar_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d parse_mode="Markdown" -d text="$1" > /dev/null
}

# Detectar comando Docker Compose disponible
if docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
else
    DOCKER_CMD="docker-compose"
fi

echo "=== ⚠️ INICIANDO RESTAURACIÓN EN: $PROJECT_DIR ==="
enviar_telegram "🚨 *ALERTA DE RESCATE*: Iniciando proceso de recuperación en SVR-ORACLE..."

# 2. VERIFICACIÓN DE DEPENDENCIAS
if ! rclone listremotes | grep -q "^drive:"; then
    echo "❌ Error: Rclone no configurado o sin remoto 'drive:'."
    enviar_telegram "❌ *ERROR*: Rclone no está configurado en este servidor."
    exit 1
fi

# 3. SELECCIÓN DEL RESPALDO
echo "📂 Conectando con Google Drive..."
rclone lsl "drive:$REMOTE_FOLDER"
echo ""
echo "Escriba el nombre exacto del archivo .tar.gz a restaurar:"
read BACKUP_FILE

# 4. DESCARGA DEL PAQUETE
echo "☁️ Descargando archivo..."
enviar_telegram "☁️ Descargando paquete: $BACKUP_FILE de la nube..."
rclone copy "drive:$REMOTE_FOLDER/$BACKUP_FILE" /tmp/ -P

if [ ! -f "/tmp/$BACKUP_FILE" ]; then
    echo "❌ Error: No se encontró el archivo descargado."
    enviar_telegram "❌ *ERROR CRÍTICO*: No se pudo bajar el archivo de Drive."
    exit 1
fi

# 5. PREPARACIÓN DEL ENTORNO
mkdir -p "$PROJECT_DIR"
echo "🛑 Deteniendo servicios en $PROJECT_DIR..."
cd "$PROJECT_DIR" && $DOCKER_CMD down 2>/dev/null

# 6. EXTRACCIÓN TEMPORAL
echo "🧹 Limpiando temporales..."
rm -rf $TEMP_RESTORE && mkdir -p $TEMP_RESTORE
tar -xzf "/tmp/$BACKUP_FILE" -C $TEMP_RESTORE

# 7. TRASPLANTE DE DATOS (INYECCIÓN QUIRÚRGICA)
echo "📦 Inyectando bases de datos en Volúmenes Docker..."
# Inyectar Management (Configuración de Red y Pares)
docker run --rm -v netbird_netbird_management:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_mgmt.tar.gz -C ."
# Inyectar ZDB (Usuarios y Logs)
docker run --rm -v netbird_netbird_zdb_data:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_zdb.tar.gz -C ."

# 8. RESTAURACIÓN DE ARCHIVOS DE CONFIGURACIÓN
echo "📝 Restaurando archivos del proyecto..."
cp -r $TEMP_RESTORE/* "$PROJECT_DIR/" 2>/dev/null
rm -f "$PROJECT_DIR"/*.tar.gz

# 9. PROGRAMACIÓN DEL LANZADOR (Automatización GitHub)
echo "🔄 Configurando lanzador automático desde GitHub..."
# Esta línea asegura que el cron use siempre la versión más reciente de GitHub
(crontab -l 2>/dev/null | grep -v "backup_pro_contics.sh"; echo "00 03 * * * curl -sSL $GITHUB_PRO_URL | bash") | crontab -

# 10. ARRANQUE DEL SISTEMA
echo "🚀 Levantando infraestructura CONTICS..."
$DOCKER_CMD up -d

# 11. VERIFICACIÓN DE SALUD
echo "⌛ Verificando estado de los servicios..."
sleep 12
SERVICIOS_ACTIVOS=$($DOCKER_CMD ps | grep "Up" | wc -l)

# 12. LIMPIEZA FINAL
rm -rf $TEMP_RESTORE
rm "/tmp/$BACKUP_FILE"

if [ "$SERVICIOS_ACTIVOS" -gt 0 ]; then
    echo "=== ✅ RESTAURACIÓN COMPLETADA EXITOSAMENTE ==="
    enviar_telegram "✅ *SISTEMA RECUPERADO EXITOSAMENTE*%0A📂 *Archivo*: $BACKUP_FILE%0A🚀 *Estado*: NetBird Online%0A⏰ *Cron*: Backup diario re-activado (Lanzador GitHub)."
else
    echo "⚠️ Restauración de archivos terminada, pero los servicios no arrancaron."
    enviar_telegram "⚠️ *ATENCIÓN*: Los datos se restauraron pero el sistema no inició automáticamente. Revisar 'docker ps'."
fi
