# ===========================================================================
# SCRIPT DE DESPLIEGUE SEGURO - RED CONTICS 2026 (FINAL STABLE)
# ===========================================================================

# 1. Variables de Red
$mUrl = 'https://contics-admin.duckdns.org'
$sKey = '8552E0C2-4E0A-490D-8B93-E2CD69CDC007'
$nbPath = 'C:\Program Files\NetBird\netbird.exe'

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "     ACTIVANDO NODO DE RED - CONTICS" -ForegroundColor Cyan
Write-Host "======================================================`n" -ForegroundColor Cyan

# 2. Instalacion de NetBird
if (!(Test-Path $nbPath)) {
    Write-Host '[1/3] NetBird no detectado. Instalando...' -ForegroundColor Yellow
    $installer = "$env:TEMP\nb.exe"
    # Descarga directa desde GitHub oficial
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Write-Host '     Ejecutando instalador silencioso...' -ForegroundColor Gray
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

# 3. Conexion y Vinculacion
Write-Host '[2/3] Vinculando equipo al panel de administracion...' -ForegroundColor Yellow
& $nbPath down | Out-Null
& $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null

# 4. Limpieza del Escritorio
Write-Host '[3/3] Finalizando configuracion y limpieza...' -ForegroundColor Yellow
if (Test-Path 'C:\Users\Public\Desktop\NetBird.lnk') { 
    Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -Force 
}

Write-Host '--- Esperando respuesta de la red (8s) ---' -ForegroundColor Gray
Start-Sleep -Seconds 8 

# 5. Reporte Final
Write-Host '------------------------------------------------------' -ForegroundColor Cyan
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'

if ($lineaIP) {
    $nbIP = ($lineaIP.ToString() -split ':')[1].Trim()
    $nbIP = ($nbIP -split '/')[0].Trim() 
    
    Write-Host ' ✅ CONECTADO EXITOSAMENTE' -ForegroundColor Green
    Write-Host " 📍 IP ASIGNADA: $nbIP" -ForegroundColor White
    $nbIP | clip
    Write-Host ' La IP ha sido copiada al portapapeles.' -ForegroundColor Gray
} else {
    Write-Host ' ⚠️ Nodo activo pero IP no detectada. Revisa el panel web.' -ForegroundColor Red
}

Write-Host '------------------------------------------------------' -ForegroundColor Cyan
Start-Process $mUrl
Write-Host "`nProceso terminado. Presione ENTER para salir..."
Read-Host
