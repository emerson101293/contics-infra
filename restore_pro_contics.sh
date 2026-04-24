#!/bin/bash
# ===========================================================================
# SISTEMA DE MIGRACIÓN Y RESTAURACIÓN PRO (v5.0) - CONTICS
# ===========================================================================
# Funcionalidad: Diagnóstico + Inyección + Automatización Local + Reporte Clean
# ===========================================================================

# --- [ CONFIGURACIÓN ] ---
PROJECT_DIR="$HOME/netbird"
REMOTE_FOLDER="CONTICS-NETBIRD-BACKUP-PROD"
TEMP_RESTORE="/tmp/restore_temp"
GITHUB_PRO_URL="https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/backup_pro_contics.sh"

# Credenciales de Telegram
TOKEN="8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak"
CHAT_ID="6902736310"

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

enviar_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d parse_mode="Markdown" -d text="$1" > /dev/null
}

# --- [ PASO 1: DIAGNÓSTICO Y SELECCIÓN ] ---
echo -e "${GREEN}🔍 INICIANDO PROCESO DE MIGRACIÓN...${NC}"
echo "----------------------------------------------------------"

if ! rclone listremotes | grep -q "^drive:"; then
    echo -e "${RED}❌ ERROR: Rclone no tiene configurado el remoto 'drive:'.${NC}"
    exit 1
fi

echo -e "📂 Conectando con Google Drive..."
rclone lsl "drive:$REMOTE_FOLDER"
echo ""
echo -e "${YELLOW}Escriba el nombre exacto del archivo .tar.gz a restaurar:${NC}"
read BACKUP_FILE

if [ -z "$BACKUP_FILE" ]; then echo "Operación cancelada."; exit 1; fi

enviar_telegram "🚨 *ALERTA DE MIGRACIÓN*: Iniciando restauración en SVR-ORACLE%0A📦 *File:* $BACKUP_FILE"

echo -e "${GREEN}☁️ Descargando paquete...${NC}"
rclone copy "drive:$REMOTE_FOLDER/$BACKUP_FILE" /tmp/ -P

# --- [ PASO 2: RESTAURACIÓN QUIRÚRGICA ] ---
DOCKER_CMD=$(command -v docker-compose || echo "docker compose")

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit
echo "🛑 Deteniendo servicios actuales..."
$DOCKER_CMD down > /dev/null 2>&1

echo "🧹 Preparando inyección de datos..."
rm -rf $TEMP_RESTORE && mkdir -p $TEMP_RESTORE
tar -xzf "/tmp/$BACKUP_FILE" -C $TEMP_RESTORE

echo "📦 Inyectando Volúmenes Docker..."
docker run --rm -v netbird_netbird_management:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_mgmt.tar.gz -C ."
docker run --rm -v netbird_netbird_zdb_data:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_zdb.tar.gz -C ."

echo "📝 Restaurando archivos de configuración..."
cp -r $TEMP_RESTORE/* "$PROJECT_DIR/" 2>/dev/null
rm -f "$PROJECT_DIR"/*.tar.gz

# --- [ PASO 3: CONFIGURAR AUTOMATIZACIÓN LOCAL ] ---
echo -e "${GREEN}🔄 Configurando respaldo automático LOCAL...${NC}"
curl -sSL "$GITHUB_PRO_URL" -o "$PROJECT_DIR/backup_pro.sh"
chmod +x "$PROJECT_DIR/backup_pro.sh"

(crontab -l 2>/dev/null | grep -v "backup_pro") > /tmp/cron_temp
echo "00 03 * * * /bin/bash $PROJECT_DIR/backup_pro.sh >> $PROJECT_DIR/backup.log 2>&1" >> /tmp/cron_temp
crontab /tmp/cron_temp
rm /tmp/cron_temp

echo -e "${GREEN}🚀 Levantando infraestructura...${NC}"
$DOCKER_CMD up -d
echo -e "⌛ Estabilizando (15s)..."
sleep 15

# --- [ PASO 4: EXTRACCIÓN DE DATOS PARA REPORTE ] ---
NETBIRD_USER=$(grep -E "NETBIRD_ZITADEL_ADMIN_USER|CITADEL_ADMIN_EMAIL" "$PROJECT_DIR/setup.env" "$PROJECT_DIR/.
