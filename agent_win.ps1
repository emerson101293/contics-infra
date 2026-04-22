# ===========================================================================
# SCRIPT DE DESPLIEGUE SEGURO - RED CONTICS 2026 (FINAL FIX)
# ===========================================================================

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$mUrl = "https://contics-admin.duckdns.org"
$sKey = "8552E0C2-4E0A-490D-8B93-E2CD69CDC007"
$nbPath = "C:\Program Files\NetBird\netbird.exe"

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "     ACTIVANDO NODO DE RED - CONTICS" -ForegroundColor Cyan
Write-Host "======================================================`n"

# 1. Instalación
Write-Host "[1/3] Verificando instalacion..." -ForegroundColor Yellow
if (!(Test-Path $nbPath)) {
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri "https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe" -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList "/S", "/component=service" -Wait
    Start-Sleep -Seconds 5
}

# 2. Conexión
Write-Host "[2/3] Vinculando equipo al panel..." -ForegroundColor Yellow
& $nbPath down | Out-Null
& $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null

# 3. Limpieza y Espera (Vital para que no salga error de matriz nula)
Write-Host "[3/3] Finalizando configuracion..." -ForegroundColor Yellow
if (Test-Path "C:\Users\Public\Desktop\NetBird.lnk") { Remove-Item -Path "C:\Users\Public\Desktop\NetBird.lnk" -Force }

Write-Host "⏳ Esperando respuesta de la red..." -ForegroundColor Gray
Start-Sleep -Seconds 8 # Le damos tiempo a la red para asignar la IP

# 4. Reporte Final Seguro
Write-Host "------------------------------------------------------" -ForegroundColor Cyan
$status = & $nbPath status

# Nueva forma de extraer la IP sin usar $matches (más segura)
$lineaIP = $status | Select-String "NetBird IP:"
if ($lineaIP) {
    $nbIP = ($lineaIP.ToString() -split ":")[1].Trim()
    $nbIP = ($nbIP -split "/")[0].Trim() # Limpia el /16 o /24 si aparece
    
    Write-Host " ✅ NODO CONECTADO EXITOSAMENTE" -ForegroundColor Green
    Write-Host " 📍 TU IP EN LA RED CONTICS: $nbIP" -ForegroundColor White
    $nbIP | clip
    Write-Host " La IP ha sido copiada al portapapeles." -ForegroundColor Gray
} else {
    Write-Host " ❌ No se pudo extraer la IP visualmente, pero el nodo está activo." -ForegroundColor Red
    Write-Host " Revisa el panel web para confirmar." -ForegroundColor Gray
}

Write-Host "------------------------------------------------------" -ForegroundColor Cyan
Start-Process $mUrl
Write-Host "`nPresione ENTER para finalizar..."
Read-Host
