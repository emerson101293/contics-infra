#!/bin/bash
# ===========================================================================
# CONTICS - Respaldo Profesional + Monitor de Salud (Doctor NetBird)
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

# --- [1] INICIO Y SALUD INICIAL ---
enviar_telegram "💾 *SVR-ORACLE*: Iniciando respaldo y chequeo médico..."

cd "$PROJECT_DIR" || exit 1
$DOCKER_CMD down > /dev/null 2>&1

# --- [2] PROCESO DE RESPALDO (IGUAL AL ANTERIOR) ---
mkdir -p /tmp/backup_temp
cp -r "$PROJECT_DIR/." /tmp/backup_temp/
docker run --rm -v netbird_netbird_management:/from -v /tmp/backup_temp:/to alpine tar -czf /to/data_mgmt.tar.gz -C /from .
docker run --rm -v netbird_netbird_zdb_data:/from -v /tmp/backup_temp:/to alpine tar -czf /to/data_zdb.tar.gz -C /from .
tar -czf "/tmp/$BACKUP_NAME" -C /tmp/backup_temp .
TAMANO=$(du -sh "/tmp/$BACKUP_NAME" | cut -f1)
rm -rf /tmp/backup_temp

# --- [3] REINICIO Y VERIFICACIÓN DE SALUD (NUEVO) ---
$DOCKER_CMD up -d > /dev/null 2>&1
sleep 10 # Damos tiempo para que los servicios enganchen

# Contamos cuántos contenedores deberían estar corriendo (usualmente son 6-7 en NetBird)
CONTENEDORES_VIVOS=$($DOCKER_CMD ps --format "{{.Status}}" | grep "Up" | wc -l)
LISTA_SERVICIOS=$($DOCKER_CMD ps --format "{{.Names}}: {{.Status}}")

# --- [4] SUBIDA A DRIVE ---
rclone copy "/tmp/$BACKUP_NAME" "drive:$REMOTE_FOLDER"

if [ $? -eq 0 ]; then
    # REPORTE DETALLADO DE SALUD
    if [ "$CONTENEDORES_VIVOS" -gt 0 ]; then
        SALUD="✅ *SISTEMA SANO* ($CONTENEDORES_VIVOS servicios online)"
    else
        SALUD="⚠️ *SISTEMA CRÍTICO*: Los contenedores no iniciaron."
    fi

    MENSAJE="📊 *REPORTE DIARIO CONTICS*%0A%0A$SALUD%0A📦 *Archivo*: $BACKUP_NAME%0A⚖️ *Peso*: $TAMANO%0A☁️ *Nube*: Sincronizado OK%0A%0A*Detalle de servicios:*%0A$LISTA_SERVICIOS"
    
    enviar_telegram "$MENSAJE"
    rm "/tmp/$BACKUP_NAME"
else
    enviar_telegram "❌ *ERROR*: Backup falló en la subida a Drive."
fi
