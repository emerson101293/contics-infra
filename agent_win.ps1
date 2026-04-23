# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - MONITORIZACION SEGURA
# Administrador: Jhonathan De La Cruz
# ===========================================================================

# --- CONFIGURACION DE TELEGRAM ---
$TelegramToken = '8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak'
$TelegramChatID = '6902736310'

function Send-Telegram {
    param([string]$Message)
    try {
        $Url = "https://api.telegram.org/bot$($TelegramToken)/sendMessage"
        $Body = @{ 
            chat_id = $TelegramChatID
            text = $Message
            parse_mode = 'Markdown'
        }
        $Json = $Body | ConvertTo-Json -Compress
        $utf8 = [System.Text.Encoding]::UTF8.GetBytes($Json)
        Invoke-RestMethod -Uri $Url -Method Post -Body $utf8 -ContentType "application/json; charset=utf-8"
    } catch { }
}

# --- LOGICA DE RED ---
$mUrl = 'https://contics-admin.duckdns.org'
$sKey = '8552E0C2-4E0A-490D-8B93-E2CD69CDC007'
$nbPath = 'C:\Program Files\NetBird\netbird.exe'
$PCName = $env:COMPUTERNAME

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "     SISTEMA DE RED CONTICS - MONITOR ACTIVO" -ForegroundColor Cyan
Write-Host "======================================================`n" -ForegroundColor Cyan

# 1. Instalacion
if (!(Test-Path $nbPath)) {
    Write-Host '[1/3] NetBird no detectado. Instalando...' -ForegroundColor Yellow
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

# 2. Conexion
Write-Host '[2/3] Vinculando equipo al panel...' -ForegroundColor Yellow
& $nbPath down | Out-Null
& $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null

# 3. Limpieza y Espera
Write-Host '[3/3] Finalizando configuracion...' -ForegroundColor Yellow
if (Test-Path 'C:\Users\Public\Desktop\NetBird.lnk') { 
    Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -Force 
}
Start-Sleep -Seconds 8 

# 4. Reporte e IP
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'

if ($lineaIP) {
    $nbIP = ($lineaIP.ToString() -split ':')[1].Trim()
    $nbIP = ($nbIP -split '/')[0].Trim() 
    
    # Mensaje con Simbolos Universales (No fallan)
    $Fecha = Get-Date -Format 'dd/MM/yyyy HH:mm'
    $Msg = "*[OK] NODO CONTICS CONECTADO*`n`n" +
           "*Equipo:* $PCName`n" +
           "*Direccion IP:* $nbIP`n" +
           "*Fecha:* $Fecha`n`n" +
           "*Admin:* Jhonathan De La Cruz"
    Send-Telegram -Message $Msg
    
    Write-Host '------------------------------------------------------' -ForegroundColor Cyan
    Write-Host " [+] NODO CONECTADO: $nbIP" -ForegroundColor Green
    $nbIP | clip
    Write-Host ' IP copiada al portapapeles.' -ForegroundColor Gray
} else {
    Send-Telegram -Message "[!] ALERTA: El equipo $PCName fallo al obtener IP."
    Write-Host ' [-] No se pudo obtener la IP.' -ForegroundColor Red
}

Write-Host '------------------------------------------------------' -ForegroundColor Cyan
Start-Process $mUrl
Write-Host "`nTerminado. Presione ENTER para salir..."
Read-Host
