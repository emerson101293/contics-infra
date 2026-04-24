#!/bin/bash
# ===========================================================================
# CONTICS - Respaldo Profesional V2 (Optimizado)
# Identificador: SVR-ORACLE-NETBIRD
# ===========================================================================

# --- [1] CONFIGURACIÓN ---
PROJECT_DIR="$HOME/netbird"
DATE=$(date +%Y-%m-%d_%H-%M)
BACKUP_NAME="CONTICS_NETBIRD_FULL_$DATE.tar.gz"
REMOTE_FOLDER="CONTICS-NETBIRD-BACKUP-PROD"
TOKEN="8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak"
CHAT_ID="6902736310"

# --- [2] FUNCIÓN TELEGRAM ---
enviar_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d text="$1" > /dev/null
}

echo "=== 🚀 Iniciando Respaldo Profesional (CONTICS) ==="
enviar_telegram "💾 [SVR-ORACLE] Iniciando respaldo programado del Servidor NetBird..."

# --- [3] GESTIÓN DE DOCKER ---
cd "$PROJECT_DIR" || { 
    enviar_telegram "❌ Error Crítico: No se encontró el directorio $PROJECT_DIR"; 
    exit 1; 
}

echo "🛑 Deteniendo servicios para asegurar integridad..."
docker compose down > /dev/null 2>&1

# --- [4] ÁREA TEMPORAL Y VOLÚMENES ---
mkdir -p /tmp/backup_temp
cp -r "$PROJECT_DIR/." /tmp/backup_temp/
rm -f /tmp/backup_temp/*.tar.gz

echo "📦 Extrayendo volúmenes de datos..."
docker run --rm -v netbird_netbird_management:/from -v /tmp/backup_temp:/to alpine tar -czf /to/data_mgmt.tar.gz -C /from .
docker run --rm -v netbird_netbird_zdb_data:/from -v /tmp/backup_temp:/to alpine tar -czf /to/data_zdb.tar.gz -C /from .

# --- [5] COMPRESIÓN FINAL ---
echo "📚 Empacando sistema completo..."
tar -czf "/tmp/$BACKUP_NAME" -C /tmp/backup_temp .
TAMANO=$(du -sh "/tmp/$BACKUP_NAME" | cut -f1)

# --- [6] REINICIO DE SERVICIOS (AUTOCURACIÓN) ---
rm -rf /tmp/backup_temp
docker compose up -d > /dev/null 2>&1
echo "✅ Servidor NetBird encendido de nuevo."

# --- [7] SUBIDA A GOOGLE DRIVE ---
if rclone listremotes | grep -q "^drive:"; then
    echo "☁️ Subiendo a drive:$REMOTE_FOLDER..."
    rclone copy "/tmp/$BACKUP_NAME" "drive:$REMOTE_FOLDER" -P
    
    if [ $? -eq 0 ]; then
        # REPORTE EXITOSO
        MENSAJE="✅ BACKUP ASEGURADO - SVR ORACLE
📂 Archivo: $BACKUP_NAME
📊 Tamaño: $TAMANO
☁️ Destino: Google Drive (PROD)
🚀 Estado: Servidor NetBird Reiniciado OK."
        enviar_telegram "$MENSAJE"
        rm "/tmp/$BACKUP_NAME"
    else
        enviar_telegram "⚠️ ERROR: Falló la subida a Drive. El archivo quedó en /tmp/$BACKUP_NAME"
    fi
else
    enviar_telegram "❌ ERROR: Rclone no está configurado como 'drive' en el Servidor."
fi

echo "=== ¡Proceso Finalizado Exitosamente! ==="
