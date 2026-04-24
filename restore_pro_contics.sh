#!/bin/bash
# ===========================================================================
# SISTEMA DE MIGRACIÓN Y RESTAURACIÓN PRO (v5.2) - CONTICS
# ===========================================================================

PROJECT_DIR="$HOME/netbird"
REMOTE_FOLDER="CONTICS-NETBIRD-BACKUP-PROD"
TEMP_RESTORE="/tmp/restore_temp"
GITHUB_PRO_URL="https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/backup_pro_contics.sh"

TOKEN="8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak"
CHAT_ID="6902736310"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

enviar_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d parse_mode="Markdown" -d text="$1" > /dev/null
}

# --- [ PASO 1: SELECCIÓN ] ---
echo -e "${GREEN}🔍 INICIANDO PROCESO DE MIGRACIÓN...${NC}"
rclone lsl "drive:$REMOTE_FOLDER"
echo ""
echo -e "${YELLOW}Escriba el nombre del archivo a restaurar:${NC}"
read BACKUP_FILE
[ -z "$BACKUP_FILE" ] && exit 1

enviar_telegram "🚨 *MIGRACIÓN*: Restaurando $BACKUP_FILE"
rclone copy "drive:$REMOTE_FOLDER/$BACKUP_FILE" /tmp/ -P

# --- [ PASO 2: RESTAURACIÓN ] ---
DOCKER_CMD=$(command -v docker-compose || echo "docker compose")
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit
$DOCKER_CMD down > /dev/null 2>&1

rm -rf $TEMP_RESTORE && mkdir -p $TEMP_RESTORE
tar -xzf "/tmp/$BACKUP_FILE" -C $TEMP_RESTORE

# Inyección de Volúmenes
docker run --rm -v netbird_netbird_management:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_mgmt.tar.gz -C ."
docker run --rm -v netbird_netbird_zdb_data:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_zdb.tar.gz -C ."

# Configuración
cp -r $TEMP_RESTORE/* "$PROJECT_DIR/" 2>/dev/null
rm -f "$PROJECT_DIR"/*.tar.gz

# Automatización Local
curl -sSL "$GITHUB_PRO_URL" -o "$PROJECT_DIR/backup_pro.sh"
chmod +x "$PROJECT_DIR/backup_pro.sh"
(crontab -l 2>/dev/null | grep -v "backup_pro") > /tmp/cron_temp
echo "00 03 * * * /bin/bash $PROJECT_DIR/backup_pro.sh >> $PROJECT_DIR/backup.log 2>&1" >> /tmp/cron_temp
crontab /tmp/cron_temp

$DOCKER_CMD up -d
echo -e "⌛ Estabilizando (15s)..."
sleep 15

# ===========================================================================
# 🔍 EXTRACCIÓN DE DATOS (MEJORADA PARA DUCKDNS)
# ===========================================================================

# Extraer Usuario
NETBIRD_USER=$(grep -Eh "NETBIRD_ZITADEL_ADMIN_USER|CITADEL_ADMIN_EMAIL" "$PROJECT_DIR/setup.env" "$PROJECT_DIR/.env" 2>/dev/null | head -n 1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)

# Extraer Dominio (Busca específicamente la variable de dominio)
DOMINIO=$(grep -Eh "^NETBIRD_DOMAIN=" "$PROJECT_DIR/setup.env" "$PROJECT_DIR/.env" 2>/dev/null | head -n 1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)

# Si no lo encuentra, intenta con la variable genérica DOMAIN
if [ -z "$DOMINIO" ]; then
    DOMINIO=$(grep -Eh "^DOMAIN=" "$PROJECT_DIR/setup.env" "$PROJECT_DIR/.env" 2>/dev/null | head -n 1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
fi

# Construcción de la URL final
if [ ! -z "$DOMINIO" ]; then
    URL_DASHBOARD="https://$DOMINIO/peers"
else
    # Solo usa la IP si el dominio realmente no existe en los archivos
    IP_PUBLICA=$(curl -s https://ifconfig.me)
    URL_DASHBOARD="https://$IP_PUBLICA/peers"
fi

SERVICIOS_ACTIVOS=$($DOCKER_CMD ps | grep "Up" | wc -l)

# ===========================================================================
# 📟 REPORTE FINAL
# ===========================================================================
echo ""
echo -e "${CYAN}[FIN DEL PROCESO]-------------------------------------------${NC}"
echo -e "${GREEN}>> STATUS:${NC}    SYSTEM_ONLINE_&_RESTORED"
echo -e "${GREEN}>> DOMAIN:${NC}    ${YELLOW}${DOMINIO:-Detectado por IP}${NC}"
echo -e "${GREEN}>> LOGIN:${NC}     ${YELLOW}${NETBIRD_USER:-No detectado}${NC}"
echo -e "${GREEN}>> URL:${NC}       ${YELLOW}${URL_DASHBOARD}${NC}"
echo -e "${GREEN}>> NODES:${NC}     $SERVICIOS_ACTIVOS SERVICIOS ACTIVOS"
echo -e "${CYAN}------------------------------------------------------------${NC}"
echo -e "${GREEN}✅ OPERACIÓN COMPLETADA CON ÉXITO. ACCESO CONCEDIDO.${NC}"
echo ""

MENSAJE="✅ *SISTEMA RECUPERADO*%0A%0A👤 *User:* \`${NETBIRD_USER}\` %0A🌐 *URL:* $URL_DASHBOARD"
enviar_telegram "$MENSAJE"

rm -rf $TEMP_RESTORE
rm -f "/tmp/$BACKUP_FILE"
