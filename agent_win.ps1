# SCRIPT CONTICS 2026 - REVISION ULTRA-ESTABLE
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File',$PSCommandPath -Verb RunAs
    exit
}

$mUrl = 'https://contics-admin.duckdns.org'
$sKey = '8552E0C2-4E0A-490D-8B93-E2CD69CDC007'
$nbPath = 'C:\Program Files\NetBird\netbird.exe'

Write-Host '======================================================' -ForegroundColor Cyan
Write-Host '     ACTIVANDO NODO DE RED - CONTICS' -ForegroundColor Cyan
Write-Host '======================================================'

if (!(Test-Path $nbPath)) {
    Write-Host '[1/3] Instalando NetBird...' -ForegroundColor Yellow
    $installer = "$env:TEMP\nb.exe"
    Invoke-WebRequest -Uri 'https://github.com/netbirdio/netbird/releases/latest/download/netbird_installer_windows_amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/S', '/component=service' -Wait
    Start-Sleep -Seconds 5
}

Write-Host '[2/3] Conectando al panel...' -ForegroundColor Yellow
& $nbPath down | Out-Null
& $nbPath up --management-url $mUrl --setup-key $sKey | Out-Null

Write-Host '[3/3] Finalizando...' -ForegroundColor Yellow
if (Test-Path 'C:\Users\Public\Desktop\NetBird.lnk') { Remove-Item -Path 'C:\Users\Public\Desktop\NetBird.lnk' -Force }
Start-Sleep -Seconds 8

$status = & $nbPath status
$lineaIP = $status | Select-String 'NetBird IP:'

if ($lineaIP) {
    $nbIP = ($lineaIP.ToString() -split ':')[1].Trim()
    $nbIP = ($nbIP -split '/')[0].Trim()
    Write-Host '------------------------------------------------------' -ForegroundColor Cyan
    Write-Host ' OK: NODO CONECTADO' -ForegroundColor Green
    Write-Host " IP: $nbIP" -ForegroundColor White
    $nbIP | clip
    Write-Host ' IP copiada al portapapeles.' -ForegroundColor Gray
} else {
    Write-Host ' AVISO: Revisa el panel web.' -ForegroundColor Red
}

Write-Host '------------------------------------------------------' -ForegroundColor Cyan
Start-Process $mUrl
Write-Host 'Terminado. Presione ENTER.'
Read-Host
