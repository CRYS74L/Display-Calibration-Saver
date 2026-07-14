@echo off
chcp 65001 >nul
title Display Calibration Saver
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Save-Display-Calibration.ps1"
echo.
pause
