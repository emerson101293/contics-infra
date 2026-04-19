#!/bin/bash
# CONTICS - Respaldo Profesional con Subida a Nube

# 1. Definir rutas
PROJECT_DIR="$HOME/netbird"
DATE=$(date +%Y-%m-%d)
BACKUP_NAME="CONTICS_FULL_$DATE.tar.gz"

echo "=== 🚀 Iniciando Respaldo Nivel Senior (Docker + Drive) ==="

# 2. Detener contenedores para que la BD esté quieta
cd $PROJECT_DIR
docker compose down

# 3. Crear área temporal
mkdir -p /tmp/backup_temp
cp -r $PROJECT_DIR/. /tmp/backup_temp/
rm -f /tmp/backup_temp/*.tar.gz

# 4. Extraer datos de la "Bóveda" de Docker
echo "📦 Extrayendo volúmenes internos..."
docker run --rm -v netbird_netbird_management:/from -v /tmp/backup_temp:/to alpine tar -czf /to/data_mgmt.tar.gz -C /from .
docker run --rm -v netbird_netbird_zdb_data:/from -v /tmp/backup_temp:/to alpine tar -czf /to/data_zdb.tar.gz -C /from .

# 5. Crear el archivo comprimido FINAL
echo "📚 Empacando todo el sistema..."
tar -czf /tmp/$BACKUP_NAME -C /tmp/backup_temp .

# 6. Limpiar y encender el servidor de inmediato
rm -rf /tmp/backup_temp
docker compose up -d
echo "✅ Servidor NetBird encendido de nuevo."

# 7. --- SUBIDA A LA NUBE (Google Drive) ---
if rclone listremotes | grep -q "drive:"; then
    echo "☁️ Subiendo a Google Drive..."
    rclone mkdir drive:backups_contics
    rclone copy "/tmp/$BACKUP_NAME" drive:backups_contics/
    
    if [ $? -eq 0 ]; then
        echo "🚀 Respaldo asegurado en la nube."
        rm "/tmp/$BACKUP_NAME"  # Borramos el temporal si se subió bien
    else
        echo "⚠️ Falló la subida. El backup quedó en /tmp/$BACKUP_NAME"
    fi
else
    echo "⚠️ Rclone no configurado. Backup guardado en /tmp/$BACKUP_NAME"
fi

echo "=== ¡Proceso de CONTICS Finalizado! ==="
