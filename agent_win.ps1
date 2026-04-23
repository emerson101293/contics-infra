# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - AGENTE DE GESTION CENTRALIZADA
# Administrador: Jhonathan De La Cruz
# ===========================================================================

# --- CONFIGURACION DE TELEGRAM ---
$TelegramToken = '8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak'
$TelegramChatID = '6902736310'

function Send-Telegram {
    param([string]$Message)
    try {
        $Url = "https://api.telegram.org/bot$($TelegramToken)/sendMessage"
        $Body = @{ chat_id = $TelegramChatID; text = $Message; parse_mode = 'Markdown' }
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
# URL RAW DE TU GITHUB
$GitHubRawUrl = 'https://raw.githubusercontent.com/CONTICS-PERU/RED-CONTICS/refs/heads/main/agent_win.ps1'

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "     SISTEMA DE RED CONTICS - AGENTE V3" -ForegroundColor Cyan
Write-Host "======================================================`n" -ForegroundColor Cyan

# 1. Instalacion (Solo si es necesario)
if (!(Test-Path $nbPath)) {
    Write-Host '[1/4] Instalando NetBird...' -ForegroundColor Yellow
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

# 2. Conexion y Verificacion
Write-Host '[2/4] Verificando conexion a la red...' -ForegroundColor Yellow
$check = & $nbPath status
if ($check -notmatch 'Connected') {
    & $nbPath down | Out-Null
    & $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null
}

# 3. Limpieza de accesos directos
if (Test-Path 'C:\Users\Public\Desktop\NetBird.lnk') { Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -Force }

# 4. Reporte de Estado a Telegram
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'
if ($lineaIP) {
    $nbIP = ($lineaIP.ToString() -split ':')[1].Trim()
    $nbIP = ($nbIP -split '/')[0].Trim() 
    $Msg = "*[OK] NODO CONTICS CONECTADO*`n`n*Equipo:* $PCName`n*IP:* $nbIP`n*Estado:* Activo y Sincronizado"
    Send-Telegram -Message $Msg
    Write-Host " [+] CONECTADO EXITOSAMENTE: $nbIP" -ForegroundColor Green
    $nbIP | clip
}

# 5. CONFIGURACION DE LA TAREA DE ACTUALIZACION (AL INICIAR SESION)
Write-Host '[4/4] Configurando persistencia de gestion...' -ForegroundColor Yellow
$TaskName = "Contics_Manager"
# La tarea descarga el script de GitHub y lo ejecuta para estar siempre actualizado
$ActionScript = "powershell.exe -WindowStyle Hidden -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (iwr '$GitHubRawUrl' -UseBasicParsing)`""

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -Command `"$ActionScript`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn 
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable -DontStopIfGoingOnBatteries
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null

Write-Host " ✅ Gestion remota configurada al inicio de sesion." -ForegroundColor Green
Write-Host '------------------------------------------------------' -ForegroundColor Cyan
Write-Host "Proceso terminado. Presione ENTER..."
Read-Host
