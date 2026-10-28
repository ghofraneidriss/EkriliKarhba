$ErrorActionPreference = 'Stop'

$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adbPath)) {
    $adbPath = "adb"
}

$destPath = Join-Path $PSScriptRoot "ekrili_vehicles.db"

Write-Host "Recuperation de la base SQLite depuis l'emulateur Android..." -ForegroundColor Cyan

try {
    & $adbPath exec-out run-as com.example.flutter_mobile_app cat databases/ekrili_vehicles.db | Set-Content -Path $destPath -AsByteStream -Force
    Write-Host "[SUCCES] Base SQLite synchronisee dans $destPath" -ForegroundColor Green
    Write-Host "Fermez puis rouvrez 'ekrili_vehicles.db' dans VS Code pour voir les nouveaux ajouts." -ForegroundColor Yellow
} catch {
    Write-Host "[ERREUR] Impossible de recuperer la base. Verifiez que l'emulateur tourne." -ForegroundColor Red
}

