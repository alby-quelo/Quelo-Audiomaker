@echo off
setlocal
cd /d "%~dp0"
echo Quelo Audiomaker — ricomposizione ISO 0.08-alpha
echo Cartella: %CD%
echo.
if not exist "Quelo-Audiomaker-0.08-alpha.iso.part00" goto missing
if not exist "Quelo-Audiomaker-0.08-alpha.iso.part01" goto missing
echo Unione in corso...
copy /b Quelo-Audiomaker-0.08-alpha.iso.part00 + Quelo-Audiomaker-0.08-alpha.iso.part01 Quelo-Audiomaker-0.08-alpha.iso
if errorlevel 1 goto fail
echo OK: creato Quelo-Audiomaker-0.08-alpha.iso
goto end
:missing
echo ERRORE: mancano una o piu parti .part00-.part01
echo Scaricale nella stessa cartella di questo script, poi rilancia.
goto end
:fail
echo ERRORE durante l'unione.
:end
pause
