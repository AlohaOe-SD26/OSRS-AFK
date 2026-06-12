@echo off
:: Bootstrap-Project.bat — double-click me.
:: Portable: keep the whole PROJECT KIT folder together, placed
:: INSIDE your project's root folder. The script auto-detects the
:: project root as this folder's parent — no editing needed.
:: This wrapper bypasses PowerShell's script-execution policy for
:: this one launch only (no system settings changed).
powershell -NoLogo -ExecutionPolicy Bypass -File "%~dp0Bootstrap-Project.ps1"
