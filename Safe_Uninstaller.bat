@echo off
rem start lets this file exit at once, so the uninstaller can also remove it.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Safe_Uninstaller.ps1"
