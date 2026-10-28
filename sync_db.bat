@echo off

set ADB="%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist %ADB% (
    set ADB=adb
)

echo ====================================================================
echo   Recuperation de la base SQLite depuis l'emulateur Android...
echo ====================================================================

:: Methode 1 : run-as
%ADB% exec-out run-as com.example.flutter_mobile_app cat databases/ekrili_vehicles.db > "%~dp0ekrili_vehicles_tmp.db" 2>nul

for %%I in ("%~dp0ekrili_vehicles_tmp.db") do set size=%%~zI
if not defined size set size=0

if %size% GTR 1024 (
    move /y "%~dp0ekrili_vehicles_tmp.db" "%~dp0ekrili_vehicles.db" >nul
    echo.
    echo [SUCCES] Base SQLite extraite avec succes de l'emulateur.
    echo Fichier mis a jour : %~dp0ekrili_vehicles.db
    echo.
    echo -> Fermez et rouvrez l'onglet 'ekrili_vehicles.db' dans VS Code
    echo    pour voir vos nouveaux ajouts dans SQLite Viewer.
    echo.
    goto :fin
)

:: Methode 2 : fallback via root
%ADB% shell "su 0 cp /data/data/com.example.flutter_mobile_app/databases/ekrili_vehicles.db /sdcard/ekrili_vehicles.db" 2>nul
%ADB% pull /sdcard/ekrili_vehicles.db "%~dp0ekrili_vehicles.db" >nul 2>nul

for %%I in ("%~dp0ekrili_vehicles.db") do set size2=%%~zI
if not defined size2 set size2=0

if %size2% GTR 1024 (
    if exist "%~dp0ekrili_vehicles_tmp.db" del "%~dp0ekrili_vehicles_tmp.db"
    echo.
    echo [SUCCES] Base SQLite extraite avec succes.
    echo Fichier mis a jour : %~dp0ekrili_vehicles.db
    echo.
    echo -> Fermez et rouvrez l'onglet 'ekrili_vehicles.db' dans VS Code.
    echo.
    goto :fin
)

if exist "%~dp0ekrili_vehicles_tmp.db" del "%~dp0ekrili_vehicles_tmp.db"
echo.
echo [ATTENTION] Aucun emulateur actif ou application non detectee.
echo Verifiez que votre emulateur tourne avec l'application ouverte.
echo.

:fin
pause
