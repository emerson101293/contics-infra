#!/bin/bash
# ===========================================================================
# SISTEMA DE MIGRACIÓN Y RESTAURACIÓN PRO (v4.0) - CONTICS
# ===========================================================================
# Autor: Gemino - CONTICS
# Funcionalidad: Diagnóstico de red/firewall + Inyección Docker + Reporte URL
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
NC='\033[0m'

enviar_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d parse_mode="Markdown" -d text="$1" > /dev/null
}

# --- [ PASO 0: DIAGNÓSTICO PRE-VUELO ] ---
clear
echo -e "${GREEN}🔍 INICIANDO DIAGNÓSTICO DE MIGRACIÓN...${NC}"
echo "----------------------------------------------------------"

# 1. Identificación de Usuario
USUARIO=$(whoami)
echo -e "👤 Usuario detectado: ${YELLOW}$USUARIO${NC}"

# 2. Verificación de Docker y Rclone
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ ERROR: Docker no está instalado.${NC}"
    exit 1
fi
if ! rclone listremotes | grep -q "^drive:"; then
    echo -e "${RED}❌ ERROR: Rclone no tiene configurado el remoto 'drive:'.${NC}"
    exit 1
fi

# 3. Verificación de Firewall y Puertos (Crítico para Oracle Cloud)
echo -e "📡 Verificando accesibilidad de puertos..."
PUERTOS=(80 443 33073 10000)
for port in "${PUERTOS[@]}"; do
    if command -v iptables &> /dev/null; then
        if ! sudo iptables -L INPUT -n | grep -q "dpt:$port"; then
            echo -e "${YELLOW}⚠️  ADVERTENCIA: Puerto $port podría estar cerrado en el Firewall local.${NC}"
        fi
    fi
done
echo -e "${YELLOW}👉 NOTA: Recuerda abrir estos puertos en el Panel de Oracle Cloud (Ingress Rules).${NC}"

# 4. Memoria RAM
RAM_LIBRE=$(free -m | awk '/^Mem:/{print $4}')
echo -e "🧠 RAM Disponible: ${YELLOW}$RAM_LIBRE MB${NC}"

echo -e "✅ ${GREEN}Diagnóstico completado.${NC}"
echo "----------------------------------------------------------"

# --- [ PASO 1: SELECCIÓN Y DESCARGA ] ---
echo -e "📂 Conectando con Google Drive..."
rclone lsl "drive:$REMOTE_FOLDER"
echo ""
echo -e "${YELLOW}Escriba el nombre exacto del archivo .tar.gz a restaurar:${NC}"
read BACKUP_FILE

if [ -z "$BACKUP_FILE" ]; then echo "Operación cancelada."; exit 1; fi

enviar_telegram "🚨 *ALERTA DE MIGRACIÓN*: Iniciando restauración en SVR-ORACLE%0A👤 *User:* $USUARIO%0A📦 *File:* $BACKUP_FILE"

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

# Sincronizar Cron con GitHub (Lanzador automático)
echo "🔄 Configurando respaldo automático desde GitHub..."
(crontab -l 2>/dev/null | grep -v "backup_pro_contics.sh"; echo "00 03 * * * curl -sSL $GITHUB_PRO_URL | bash") | crontab -

echo -e "${GREEN}🚀 Levantando infraestructura...${NC}"
$DOCKER_CMD up -d

# --- [ PASO 3: VERIFICACIÓN Y ENTREGA ] ---
echo -e "⌛ Esperando estabilización del sistema (15s)..."
sleep 15

# Detectar Dominio desde setup.env para generar URL de acceso
DOMINIO=$(grep -oP '(?<=NETBIRD_DOMAIN=).*' "$PROJECT_DIR/setup.env" 2>/dev/null | head -n 1)

# Si el dominio está vacío, intentar buscar en el archivo .env principal
if [ -z "$DOMINIO" ]; then
    DOMINIO=$(grep -oP '(?<=NETBIRD_DOMAIN=).*' "$PROJECT_DIR/.env" 2>/dev/null | head -n 1)
fi

# Fallback final si no se encuentra dominio configurado
if [ -z "$DOMINIO" ]; then
    URL_DASHBOARD="https://$(curl -s https://ifconfig.me)"
else
    URL_DASHBOARD="https://$DOMINIO"
fi

SERVICIOS_ACTIVOS=$($DOCKER_CMD ps | grep "Up" | wc -l)

if [ "$SERVICIOS_ACTIVOS" -gt 0 ]; then
    echo -e "=========================================================="
    echo -e "${GREEN}✅ MIGRACIÓN / RESTAURACIÓN COMPLETADA EXITOSAMENTE${NC}"
    echo -e "🌐 DASHBOARD: ${YELLOW}$URL_DASHBOARD${NC}"
    echo -e "👤 OPERADOR: $USUARIO"
    echo -e "=========================================================="
    
    MENSAJE="✅ *SISTEMA RECUPERADO*%0A%0A👤 *Operador:* $USUARIO%0A🌐 *URL:* $URL_DASHBOARD%0A📦 *Paquete:* $BACKUP_FILE%0A🚀 *Estado:* Netbird Online"
    enviar_telegram "$MENSAJE"
else
    echo -e "${RED}⚠️ ERROR: Los servicios no iniciaron correctamente.${NC}"
    enviar_telegram "❌ *ERROR CRÍTICO*: Servicios caídos tras restauración."
fi

# Limpieza final
rm -rf $TEMP_RESTORE
rm "/tmp/$BACKUP_FILE"
