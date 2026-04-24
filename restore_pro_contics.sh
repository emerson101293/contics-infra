#!/bin/bash
# ===========================================================================
# SISTEMA DE MIGRACIÓN Y RESTAURACIÓN PRO (v4.7) - CONTICS
# ===========================================================================
# Autor: Gemino - CONTICS
# Ajuste: Automatización Local + Hacker Terminal Output
# ===========================================================================

# --- [ CONFIGURACIÓN ] ---
PROJECT_DIR="$HOME/netbird"
REMOTE_FOLDER="CONTICS-NETBIRD-BACKUP-PROD"
TEMP_RESTORE="/tmp/restore_temp"
GITHUB_PRO_URL="https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/backup_pro_contics.sh"

# Credenciales de Telegram
TOKEN="8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak"
CHAT_ID="6902736310"

# Colores para la consola
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

enviar_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d parse_mode="Markdown" -d text="$1" > /dev/null
}

# --- [ PASO 0: DIAGNÓSTICO PRE-VUELO ] ---
clear
echo -e "${GREEN}🔍 INICIANDO DIAGNÓSTICO DE MIGRACIÓN...${NC}"
echo "----------------------------------------------------------"

USUARIO_SISTEMA=$(whoami)
echo -e "👤 Usuario del sistema: ${YELLOW}$USUARIO_SISTEMA${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ ERROR: Docker no está instalado.${NC}"
    exit 1
fi
if ! rclone listremotes | grep -q "^drive:"; then
    echo -e "${RED}❌ ERROR: Rclone no tiene configurado el remoto 'drive:'.${NC}"
    exit 1
fi

echo -e "📡 Verificando accesibilidad de puertos..."
PUERTOS=(80 443 33073 10000)
for port in "${PUERTOS[@]}"; do
    if command -v iptables &> /dev/null; then
        if ! sudo iptables -L INPUT -n | grep -q "dpt:$port"; then
            echo -e "${YELLOW}⚠️  ADVERTENCIA: Puerto $port podría estar cerrado.${NC}"
        fi
    fi
done

echo -e "✅ ${GREEN}Diagnóstico completado.${NC}"
echo "----------------------------------------------------------"

# --- [ PASO 1: SELECCIÓN Y DESCARGA ] ---
echo -e "📂 Conectando con Google Drive..."
rclone lsl "drive:$REMOTE_FOLDER"
echo ""
echo -e "${YELLOW}Escriba el nombre exacto del archivo .tar.gz a restaurar:${NC}"
read BACKUP_FILE

if [ -z "$BACKUP_FILE" ]; then echo "Operación cancelada."; exit 1; fi

enviar_telegram "🚨 *ALERTA DE MIGRACIÓN*: Iniciando restauración en SVR-ORACLE%0A👤 *User Linux:* $USUARIO_SISTEMA%0A📦 *File:* $BACKUP_FILE"

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

echo "📦 Inyectando Volúmenes (Management & ZDB)..."
docker run --rm -v netbird_netbird_management:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_mgmt.tar.gz -C ."
docker run --rm -v netbird_netbird_zdb_data:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_zdb.tar.gz -C ."

echo "📝 Restaurando archivos de configuración (.env, setup.env)..."
cp -r $TEMP_RESTORE/* "$PROJECT_DIR/" 2>/dev/null
rm -f "$PROJECT_DIR"/*.tar.gz

echo -e "${GREEN}🔄 Configurando respaldo automático LOCAL...${NC}"
curl -sSL "$GITHUB_PRO_URL" -o "$PROJECT_DIR/backup_pro.sh"
chmod +x "$PROJECT_DIR/backup_pro.sh"

(crontab -l 2>/dev/null | grep -v "backup_pro_contics.sh" | grep -v "backup_pro.sh") > /tmp/cron_temp
echo "00 03 * * * /bin/bash $PROJECT_DIR/backup_pro.sh >> $PROJECT_DIR/backup.log 2>&1" >> /tmp/cron_temp
crontab /tmp/cron_temp
rm /tmp/cron_temp

echo -e "${GREEN}🚀 Levantando infraestructura...${NC}"
$DOCKER_CMD up -d

# --- [ PASO 3: VERIFICACIÓN Y ENTREGA ] ---
echo -e "⌛ Esperando estabilización del sistema (15s)..."
sleep 15

# BUSQUEDA DEL NOMBRE DE USUARIO DE LOGIN
NETBIRD_USER=$(grep -oP '(?<=NETBIRD_ZITADEL_ADMIN_USER=).*' "$PROJECT_DIR/setup.env" 2>/dev/null | tr -d '"' | tr -d "'" | xargs)
[ -z "$NETBIRD_USER" ] && NETBIRD_USER=$(grep -oP '(?<=CITADEL_ADMIN_EMAIL=).*' "$PROJECT_DIR/.env" 2>/dev/null | tr -d '"' | tr -d "'" | xargs)

# BUSQUEDA DEL DOMINIO
DOMINIO=$(grep -oP '(?<=NETBIRD_DOMAIN=).*' "$PROJECT_DIR/setup.env" 2>/dev/null | tr -d '"' | tr -d "'" | xargs)
[ -z "$DOMINIO" ] && DOMINIO=$(grep -oP '(?<=NETBIRD_DOMAIN=).*' "$PROJECT_DIR/.env" 2>/dev/null | tr -d '"' | tr -d "'" | xargs)
if [ -z "$DOMINIO" ] && [[ "$NETBIRD_USER" == *"@"* ]]; then DOMINIO=$(echo "$NETBIRD_USER" | cut -d'@' -f2); fi

if [ ! -z "$DOMINIO" ] && [[ "$DOMINIO" != *" "* ]]; then
    URL_DASHBOARD="https://$DOMINIO/peers"
else
    URL_DASHBOARD="https://$(curl -s https://ifconfig.me)/peers"
fi

SERVICIOS_ACTIVOS=$($DOCKER_CMD ps | grep "Up" | wc -l)

# --- [ EL TOQUE HACKER FINAL ] ---
clear
if [ "$SERVICIOS_ACTIVOS" -gt 0 ]; then
    echo -e "${GREEN}"
    echo "  ██████╗ ██████╗ ███╗   ██╗████████╗██╗ ██████╗███████╗"
    echo " ██╔════╝██╔═══██╗████╗  ██║╚══██╔══╝██║██╔════╝██╔════╝"
    echo " ██║     ██║   ██║██╔██╗ ██║   ██║   ██║██║     ███████╗"
    echo " ██║     ██║   ██║██║╚██╗██║   ██║   ██║██║     ╚════██║"
    echo " ╚██████╗╚██████╔╝██║ ╚████║   ██║   ██║╚██████╗███████║"
    echo "  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚═╝ ╚═════╝╚══════╝"
    echo -e "${NC}"
    echo -e "${CYAN}[SYSTEM INFO]${NC} -------------------------------------------"
    echo -e "${GREEN}STATUS:${NC}       SYSTEM_RESTORED_SUCCESSFULLY"
    echo -e "${GREEN}DOMAIN:${NC}       $DOMINIO"
    echo -e "${GREEN}INTERFACE:${NC}    $URL_DASHBOARD"
    echo -e "${GREEN}ADMIN_USER:${NC}   $NETBIRD_USER"
    echo -e "${GREEN}SERVICES:${NC}     $SERVICIOS_ACTIVOS CONTAINERS ONLINE"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    echo -e "${YELLOW}>> SISTEMA FUNCIONANDO CON ÉXITO. ACCESO CONCEDIDO.${NC}"
    
    MENSAJE="✅ *SISTEMA RECUPERADO*%0A%0A👤 *Login:* \`${NETBIRD_USER:-No detectado}\` %0A🌐 *URL:* $URL_DASHBOARD%0A🚀 *Estado:* Netbird Online"
    enviar_telegram "$MENSAJE"
else
    echo -e "${RED}⚠️ CRITICAL_FAILURE: SERVICES_NOT_RESPONDING${NC}"
    enviar_telegram "❌ *ERROR CRÍTICO*: Servicios caídos tras restauración."
fi

rm -rf $TEMP_RESTORE
rm -f "/tmp/$BACKUP_FILE"
