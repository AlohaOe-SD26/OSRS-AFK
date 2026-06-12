@echo off
:: Remote-Start.bat — double-click me.
:: Portable: keep this and Remote-Start.ps1 together in a folder
:: INSIDE your project's root folder. The script auto-detects the
:: project root as that folder's parent — no editing needed.
:: This wrapper bypasses PowerShell's script-execution policy for
:: this one launch only (no system settings changed).
powershell -NoLogo -ExecutionPolicy Bypass -File "%~dp0Remote-Start.ps1"
