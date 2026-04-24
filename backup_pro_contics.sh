#!/bin/bash
# ===========================================================================
# CONTICS - Respaldo Profesional + Monitor de Salud (Consola & Telegram)
# ===========================================================================

# --- [CONFIGURACIÓN] ---
PROJECT_DIR="$HOME/netbird"
DATE=$(date +%Y-%m-%d_%H-%M)
BACKUP_NAME="CONTICS_NETBIRD_FULL_$DATE.tar.gz"
REMOTE_FOLDER="CONTICS-NETBIRD-BACKUP-PROD"
TOKEN="8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak"
CHAT_ID="6902736310"

enviar_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d parse_mode="Markdown" -d text="$1" > /dev/null
}

DOCKER_CMD=$(command -v docker-compose || echo "docker compose")

# 1. INICIO
echo "=== 🚀 Iniciando Respaldo Profesional (CONTICS) ==="
enviar_telegram "💾 *SVR-ORACLE*: Iniciando respaldo y chequeo médico..."

# 2. INTEGRIDAD
cd "$PROJECT_DIR" || exit 1
echo "🛑 Deteniendo servicios para asegurar integridad..."
$DOCKER_CMD down > /dev/null 2>&1

# 3. EXTRACCIÓN
echo "📦 Extrayendo volúmenes de datos..."
mkdir -p /tmp/backup_temp
cp -r "$PROJECT_DIR/." /tmp/backup_temp/
docker run --rm -v netbird_netbird_management:/from -v /tmp/backup_temp:/to alpine tar -czf /to/data_mgmt.tar.gz -C /from .
docker run --rm -v netbird_netbird_zdb_data:/from -v /tmp/backup_temp:/to alpine tar -czf /to/data_zdb.tar.gz -C /from .

# 4. EMPAQUE
echo "📚 Empacando sistema completo..."
tar -czf "/tmp/$BACKUP_NAME" -C /tmp/backup_temp .
TAMANO=$(du -sh "/tmp/$BACKUP_NAME" | cut -f1)
rm -rf /tmp/backup_temp

# 5. REINICIO Y SALUD
$DOCKER_CMD up -d > /dev/null 2>&1
echo "✅ Servidor NetBird encendido de nuevo."
sleep 10
CONTENEDORES_VIVOS=$($DOCKER_CMD ps --format "{{.Status}}" | grep "Up" | wc -l)
LISTA_SERVICIOS=$($DOCKER_CMD ps --format "{{.Names}}: {{.Status}}")

# 6. SUBIDA A DRIVE
echo "☁️ Subiendo a drive:$REMOTE_FOLDER..."
rclone copy "/tmp/$BACKUP_NAME" "drive:$REMOTE_FOLDER" -P

if [ $? -eq 0 ]; then
    # REPORTE DE TELEGRAM
    [ "$CONTENEDORES_VIVOS" -gt 0 ] && SALUD="✅ *SISTEMA SANO* ($CONTENEDORES_VIVOS servicios online)" || SALUD="⚠️ *SISTEMA CRÍTICO*"
    
    MENSAJE="📊 *REPORTE DIARIO CONTICS*%0A%0A$SALUD%0A📦 *Archivo*: $BACKUP_NAME%0A⚖️ *Peso*: $TAMANO%0A%0A*Detalle de servicios:*%0A$LISTA_SERVICIOS"
    
    enviar_telegram "$MENSAJE"
    rm "/tmp/$BACKUP_NAME"
    echo "=== ¡Proceso Finalizado Exitosamente! ==="
else
    enviar_telegram "❌ *ERROR EN SUBIDA*: Revisar rclone."
    echo "❌ Error en la subida."
fi
