$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
  throw "Python 3 is required for the local preview. Install Python from python.org."
}
Write-Host "Opening Kingdom Treasure at http://localhost:8000" -ForegroundColor Green
Write-Host "Keep this PowerShell window open. Press Ctrl+C to stop."
python -m http.server 8000
