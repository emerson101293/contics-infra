@echo off
:: SCRIPT DE DESPLIEGUE SEGURO - RED CONTICS 2026
TITLE Instalador NetBird + Permisos SSH

:: Elevación de privilegios automática (UAC)
set "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~dp0"" && ""%~0"" %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

echo ======================================================
echo     ACTIVANDO NODO Y SERVIDOR SSH - CONTICS
echo ======================================================
echo.

:: Variables de red
set "mUrl=https://contics-admin.duckdns.org"
set "sKey=8552E0C2-4E0A-490D-8B93-E2CD69CDC007"

powershell -Command "Write-Host '[1/3] Verificando instalacion...' -ForegroundColor Yellow; if (!(Test-Path 'C:\Program Files\NetBird\netbird.exe')) { Write-Host '    -> Descargando NetBird...' -ForegroundColor Gray; iwr 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile \"$env:TEMP\nb.exe\" -UseBasicParsing; Start-Process -FilePath \"$env:TEMP\nb.exe\" -ArgumentList '/S', '/component=service' -Wait; Start-Sleep -Seconds 5 }; Write-Host '[2/3] Reiniciando servicio con permisos SSH...' -ForegroundColor Yellow; & 'C:\Program Files\NetBird\netbird.exe' down | Out-Null; & 'C:\Program Files\NetBird\netbird.exe' up --management-url %mUrl% --setup-key %sKey% --allow-server-ssh --enable-ssh-root | Out-Null; Write-Host '[3/3] Finalizando configuracion...' -ForegroundColor Yellow; Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -ErrorAction SilentlyContinue; Write-Host '------------------------------------------------------' -ForegroundColor Cyan; $status = & 'C:\Program Files\NetBird\netbird.exe' status; $nbIP = ($status | Select-String 'NetBird IP:').ToString().Split(':')[1].Trim().Split('/')[0]; $accessCmd = \"netbird ssh contics@$nbIP\"; Write-Host ' CONFIGURACION COMPLETADA' -ForegroundColor Green; Write-Host \" IP ASIGNADA: $nbIP\" -ForegroundColor White; Write-Host ' COMANDO PARA TU PC:' -ForegroundColor Yellow; Write-Host \" $accessCmd\" -ForegroundColor White -BackgroundColor DarkBlue; $accessCmd | clip; Write-Host '------------------------------------------------------' -ForegroundColor Cyan; Write-Host ' El comando ya esta en el portapapeles.' -ForegroundColor Gray; Start-Process %mUrl%"

echo.
echo Proceso terminado. Pasa el comando a tu hermano.
pause >nul
