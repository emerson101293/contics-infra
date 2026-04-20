#!/bin/bash
# CONTICS - Respaldo Profesional con Subida a Nube
# Identificador: SVR-ORACLE-NETBIRD

# 1. Definir rutas y nombres
PROJECT_DIR="$HOME/netbird"
DATE=$(date +%Y-%m-%d)
BACKUP_NAME="CONTICS_NETBIRD_FULL_$DATE.tar.gz"
REMOTE_FOLDER="CONTICS-NETBIRD-BACKUP-PROD"

echo "=== 🚀 Iniciando Respaldo Profesional (CONTICS-NETBIRD) ==="

# 2. Detener contenedores para asegurar la integridad de la BD
cd "$PROJECT_DIR" || { echo "❌ Error: No se encontró el directorio $PROJECT_DIR"; exit 1; }
docker compose down

# 3. Crear área temporal de trabajo
mkdir -p /tmp/backup_temp
cp -r "$PROJECT_DIR/." /tmp/backup_temp/
rm -f /tmp/backup_temp/*.tar.gz

# 4. Extraer datos de los volúmenes internos de Docker
echo "📦 Extrayendo volúmenes de datos..."
docker run --rm -v netbird_netbird_management:/from -v /tmp/backup_temp:/to alpine tar -czf /to/data_mgmt.tar.gz -C /from .
docker run --rm -v netbird_netbird_zdb_data:/from -v /tmp/backup_temp:/to alpine tar -czf /to/data_zdb.tar.gz -C /from .

# 5. Crear el archivo comprimido FINAL
echo "📚 Empacando sistema completo..."
tar -czf "/tmp/$BACKUP_NAME" -C /tmp/backup_temp .

# 6. Limpiar temporales locales y encender el servidor
rm -rf /tmp/backup_temp
docker compose up -d
echo "✅ Servidor NetBird encendido de nuevo."

# 7. --- SUBIDA A GOOGLE DRIVE ---
if rclone listremotes | grep -q "^drive:"; then
    echo "☁️ Subiendo a la nube: drive:$REMOTE_FOLDER..."
    
    # Rclone crea la carpeta automáticamente si no existe
    rclone copy "/tmp/$BACKUP_NAME" "drive:$REMOTE_FOLDER" -P
    
    if [ $? -eq 0 ]; then
        echo "🚀 Respaldo asegurado con éxito en Drive."
        rm "/tmp/$BACKUP_NAME"
    else
        echo "⚠️ Error en la subida. El archivo se guardó en /tmp/$BACKUP_NAME"
    fi
else
    echo "❌ Error: Rclone no está configurado como 'drive'."
    echo "El backup local está en: /tmp/$BACKUP_NAME"
fi

echo "=== ¡Proceso Finalizado Exitosamente! ==="
