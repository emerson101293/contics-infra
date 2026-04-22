# ===========================================================================
# SCRIPT DE AGENTE CONTICS - WINDOWS POWERSHELL
# ===========================================================================
# Repositorio: github.com/emerson101293/contics-infra
# ===========================================================================

$ManagementURL = "https://vpn.contics.com" # <--- Tu dominio de Oracle
$SetupKey = "TU-SETUP-KEY-AQUÍ"           # <--- Tu clave de NetBird

Write-Host "🌐 Iniciando Agente CONTICS para Windows..." -ForegroundColor Cyan

# 1. Descarga e Instalación (Si no existe)
if (!(Get-Command netbird -ErrorAction SilentlyContinue)) {
    Write-Host "📦 NetBird no detectado. Descargando instalador..." -ForegroundColor Yellow
    $installerPath = "$env:TEMP\netbird_installer.exe"
    Invoke-WebRequest -Uri "https://pkgs.netbird.io/windows-amd64" -OutFile $installerPath
    
    Write-Host "⚙️ Ejecutando instalador..." -ForegroundColor Yellow
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
    Write-Host "✅ Instalación completada." -ForegroundColor Green
} else {
    Write-Host "✅ NetBird ya está instalado en este equipo." -ForegroundColor Green
}

# 2. Conexión al Servidor de Oracle
Write-Host "🔗 Vinculando equipo con el servidor de Oracle..." -ForegroundColor Cyan
& "C:\Program Files\NetBird\netbird.exe" up --management-url $ManagementURL --setup-key $SetupKey

# 3. Verificación de Estado
Write-Host "🔍 Verificando conexión..." -ForegroundColor Cyan
Start-Sleep -Seconds 5
& "C:\Program Files\NetBird\netbird.exe" status

Write-Host "=== ✅ EQUIPO WINDOWS VINCULADO A CONTICS ===" -ForegroundColor Green
