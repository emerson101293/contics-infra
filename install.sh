#!/bin/bash

# --- CONFIGURACIÓN DE VARIABLES ---
# Si no se pasan argumentos, usará estos valores por defecto (puedes dejarlos así)
DOMAIN=${1:-"TU_DOMINIO_AQUI"}
EMAIL=${2:-"TU_CORREO_AQUI"}

echo "🚀 Iniciando instalación de NetBird para CONTICS..."
echo "🌐 Dominio: $DOMAIN"
echo "📧 Admin: $EMAIL"

# 1. Actualización e Instalación de herramientas base
sudo apt update && sudo apt install -y jq docker.io docker-compose-v2 iptables-persistent rclone

# 2. Configuración de permisos de Docker
sudo usermod -aG docker $USER

# 3. Apertura de Firewall en Ubuntu (Específico para Oracle Cloud)
echo "🛡️ Configurando Firewall de Ubuntu..."
sudo iptables -I INPUT 6 -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT 6 -p udp --dport 3478 -j ACCEPT
sudo iptables -I INPUT 6 -p udp --dport 10000:16000 -j ACCEPT
# Guardar reglas permanentemente
sudo netfilter-persistent save

# 4. Preparación de NetBird
mkdir -p ~/netbird && cd ~/netbird

# 5. Descarga del instalador oficial
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started-with-zitadel.sh -o setup.sh
chmod +x setup.sh

# 6. Ejecución Automática usando las variables del comando
# Usamos 'sg docker' para aplicar los permisos de grupo al instante
sg docker -c "./setup.sh --domain $DOMAIN --first-name Gemino --last-name Red --email $EMAIL"

echo "✅ Proceso finalizado. Verifica el acceso en: https://$DOMAIN"
