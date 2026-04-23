# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - MONITOR + KEEP ALIVE (LOW RESOURCE)
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

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "     SISTEMA DE RED CONTICS - OPTIMIZADO" -ForegroundColor Cyan
Write-Host "======================================================`n" -ForegroundColor Cyan

# 1. Instalacion (Solo si no existe)
if (!(Test-Path $nbPath)) {
    Write-Host '[1/4] Instalando NetBird...' -ForegroundColor Yellow
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

# 2. Conexion Inicial
Write-Host '[2/4] Vinculando equipo...' -ForegroundColor Yellow
& $nbPath down | Out-Null
& $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null

# 3. Limpieza
if (Test-Path 'C:\Users\Public\Desktop\NetBird.lnk') { Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -Force }
Start-Sleep -Seconds 8 

# 4. Reporte e IP
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'
if ($lineaIP) {
    $nbIP = ($lineaIP.ToString() -split ':')[1].Trim()
    $nbIP = ($nbIP -split '/')[0].Trim() 
    $Msg = "*[OK] NODO CONTICS CONECTADO*`n`n*Equipo:* $PCName`n*IP:* $nbIP"
    Send-Telegram -Message $Msg
    Write-Host " [+] CONECTADO: $nbIP" -ForegroundColor Green
    $nbIP | clip
}

# 5. CONFIGURACION DE AUTO-RECONEXION (CADA 1 HORA)
Write-Host '[4/4] Configurando Tarea de Persistencia (60 min)...' -ForegroundColor Yellow
$TaskName = "Contics_KeepAlive"
# Comando ultra-ligero: solo hace 'up' si detecta que no hay IP
$ActionScript = "if (!(& '$nbPath' status | Select-String 'NetBird IP:')) { & '$nbPath' up --management-url $mUrl --setup-key $sKey }"

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -Command `"$ActionScript`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null

# Ajuste de intervalo a 1 hora (PT1H)
$vTask = Get-ScheduledTask -TaskName $TaskName
$vTask.Triggers[0].Repetition.Interval = "PT1H" 
$vTask.Triggers[0].Repetition.Duration = "P365D"
Set-ScheduledTask -InputObject $vTask | Out-Null

Write-Host " ✅ Persistencia configurada cada 1 hora." -ForegroundColor Green
Write-Host '------------------------------------------------------' -ForegroundColor Cyan
Start-Process $mUrl
Write-Host "`nTerminado."
Read-Host
