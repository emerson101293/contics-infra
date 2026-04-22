#!/bin/bash
# ===========================================================================
# SISTEMA DE RESTAURACIÓN UNIVERSAL - CONTICS-NETBIRD (NUBE & LOCAL)
# ===========================================================================
# Autor: Gemino - CONTICS
# Funcionalidad: Detecta el usuario actual y restaura desde Drive + GitHub.
# ===========================================================================

# 1. CONFIGURACIÓN DINÁMICA (Funciona en /home/ubuntu o /home/tu_usuario)
PROJECT_DIR="$HOME/netbird"
REMOTE_FOLDER="CONTICS-NETBIRD-BACKUP-PROD"
TEMP_RESTORE="/tmp/restore_temp"
GITHUB_RAW_URL="https://raw.githubusercontent.com/emerson101293/contics-infra/main/backup.sh"

# Detectar comando Docker Compose disponible
if docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
else
    DOCKER_CMD="docker-compose"
fi

echo "=== ⚠️ INICIANDO RESTAURACIÓN EN: $PROJECT_DIR ==="

# 2. VERIFICACIÓN DE DEPENDENCIAS
if ! rclone listremotes | grep -q "^drive:"; then
    echo "❌ Error: Rclone no configurado o sin remoto 'drive:'."
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
rclone copy "drive:$REMOTE_FOLDER/$BACKUP_FILE" /tmp/ -P

if [ ! -f "/tmp/$BACKUP_FILE" ]; then
    echo "❌ Error: No se encontró el archivo descargado."
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

# 7. TRASPLANTE DE DATOS (INJECCIÓN QUIRÚRGICA)
echo "📦 Inyectando bases de datos en Volúmenes Docker..."
# Inyectar Management (Configuración de Red y Pares)
docker run --rm -v netbird_netbird_management:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_mgmt.tar.gz -C ."
# Inyectar ZDB (Usuarios y Logs)
docker run --rm -v netbird_netbird_zdb_data:/to -v $TEMP_RESTORE:/from alpine sh -c "cd /to && rm -rf ./* && tar -xzf /from/data_zdb.tar.gz -C ."

# 8. RESTAURACIÓN DE ARCHIVOS DE CONFIGURACIÓN
echo "📝 Restaurando archivos del proyecto..."
cp -r $TEMP_RESTORE/* "$PROJECT_DIR/"
rm -f "$PROJECT_DIR"/*.tar.gz

# 9. SINCRONIZACIÓN CON GITHUB (Lógica actualizada)
echo "🔄 Sincronizando script de backup desde GitHub..."
curl -fsSL "$GITHUB_RAW_URL" -o "$PROJECT_DIR/backup.sh"

if [ $? -eq 0 ]; then
    chmod +x "$PROJECT_DIR/backup.sh"
    sed -i 's/\r$//' "$PROJECT_DIR/backup.sh"
    echo "✅ backup.sh actualizado."
else
    echo "⚠️ No se pudo conectar a GitHub. Usando versión del backup."
    chmod +x "$PROJECT_DIR/backup.sh"
fi

# 10. ARRANQUE DEL SISTEMA
echo "🚀 Levantando infraestructura CONTICS..."
$DOCKER_CMD up -d

# 11. RE-PROGRAMACIÓN DEL CRON (Seguro de vida)
echo "⏰ Asegurando backup automático (03:00 AM)..."
(crontab -l 2>/dev/null | grep -v "backup.sh"; echo "00 03 * * * $PROJECT_DIR/backup.sh > $PROJECT_DIR/backup.log 2>&1") | crontab -

# 12. LIMPIEZA FINAL
rm -rf $TEMP_RESTORE
rm "/tmp/$BACKUP_FILE"

echo "=== ✅ RESTAURACIÓN COMPLETADA EXITOSAMENTE ==="
