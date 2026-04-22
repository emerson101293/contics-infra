# ===========================================================================
# SCRIPT DE DESPLIEGUE SEGURO - RED CONTICS 2026 (Versión Sin SSH)
# ===========================================================================

# 1. Elevación de Privilegios (UAC) - Para poder instalar el programa
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Instalador NetBird - Nodo CONTICS"

# 2. Tus Variables de Red (Originales)
$mUrl = "https://contics-admin.duckdns.org"
$sKey = "8552E0C2-4E0A-490D-8B93-E2CD69CDC007"

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "     ACTIVANDO NODO DE RED - CONTICS" -ForegroundColor Cyan
Write-Host "======================================================`n" -ForegroundColor Cyan

# 3. Verificación e Instalación
Write-Host "[1/3] Verificando instalación..." -ForegroundColor Yellow
$nbPath = "C:\Program Files\NetBird\netbird.exe"

if (!(Test-Path $nbPath)) {
    Write-Host "    -> Descargando NetBird..." -ForegroundColor Gray
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri "https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe" -OutFile $installer -UseBasicParsing
    
    Write-Host "    -> Instalando silenciosamente..." -ForegroundColor Gray
    Start-Process -FilePath $installer -ArgumentList "/S", "/component=service" -Wait
    Start-Sleep -Seconds 5
}

# 4. Conexión a la Red (Sin SSH)
Write-Host "[2/3] Vinculando equipo al panel de administración..." -ForegroundColor Yellow
& $nbPath down | Out-Null
# Aquí eliminamos los flags de SSH (--allow-server-ssh y --enable-ssh-root)
& $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null

# 5. Limpieza del Escritorio
Write-Host "[3/3] Finalizando configuración y limpieza..." -ForegroundColor Yellow
Remove-Item -Path "C:\Users\Public\Desktop\NetBird.lnk" -ErrorAction SilentlyContinue

# 6. Reporte Final de Conexión
Write-Host "------------------------------------------------------" -ForegroundColor Cyan
$status = & $nbPath status
$match = $status | Select-String 'NetBird IP: (\d+\.\d+\.\d+\.\d+)'

if ($match) {
    $nbIP = $match.Matches.Groups[1].Value
    Write-Host " ✅ NODO CONECTADO EXITOSAMENTE" -ForegroundColor Green
    Write-Host " 📍 TU IP EN LA RED CONTICS: $nbIP" -ForegroundColor White
    $nbIP | clip
    Write-Host " La IP ha sido copiada al portapapeles." -ForegroundColor Gray
} else {
    Write-Host " ❌ El equipo no pudo obtener una IP. Revisa el Setup Key." -ForegroundColor Red
}

Write-Host "------------------------------------------------------" -ForegroundColor Cyan
Start-Process $mUrl
Write-Host "Presiona cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
