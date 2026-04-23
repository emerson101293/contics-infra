# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - MONITORIZACION POR TELEGRAM (UTF-8 FIX)
# Administrador: Jhonathan De La Cruz
# ===========================================================================

# Forzar codificacion UTF8 para que los emojis lleguen bien a Telegram
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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
        # Forzamos la codificacion en la peticion web
        Invoke-RestMethod -Uri $Url -Method Post -Body (ConvertTo-Json $Body) -ContentType "application/json; charset=utf-8"
    } catch {
        # Falla silenciosa
    }
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
    
    # Envio a Telegram con formato limpio
    $Fecha = Get-Date -Format 'dd/MM/yyyy HH:mm'
    $Msg = "🚀 *Nodo CONTICS Conectado*`n`n" +
           "💻 *Equipo:* $PCName`n" +
           "🌐 *IP:* $nbIP`n" +
           "⏰ *Fecha:* $Fecha`n`n" +
           "👤 *Admin:* Jhonathan De La Cruz"
    Send-Telegram -Message $Msg
    
    Write-Host '------------------------------------------------------' -ForegroundColor Cyan
    Write-Host " ✅ NODO CONECTADO: $nbIP" -ForegroundColor Green
    $nbIP | clip
    Write-Host ' IP copiada al portapapeles.' -ForegroundColor Gray
} else {
    Send-Telegram -Message "⚠️ *Alerta:* El equipo $PCName fallo al obtener IP."
    Write-Host ' ❌ No se pudo obtener la IP.' -ForegroundColor Red
}

Write-Host '------------------------------------------------------' -ForegroundColor Cyan
Start-Process $mUrl
Write-Host "`nTerminado. Presione ENTER para salir..."
Read-Host
