[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ProjectRef,
  [Parameter(Mandatory=$true)][string]$AppOrigin
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$FunctionDir = Join-Path $Root "supabase/functions/invite-user"

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  throw "Supabase CLI not found. Install it using: npm install -g supabase"
}
if (-not (Test-Path $FunctionDir)) { throw "Edge Function folder not found: $FunctionDir" }

Write-Host "Logging in to Supabase. Complete the browser/device authorization." -ForegroundColor Cyan
supabase login
if ($LASTEXITCODE -ne 0) { throw "supabase login failed." }

Write-Host "Linking project $ProjectRef. Supabase may ask for the database password." -ForegroundColor Cyan
supabase link --project-ref $ProjectRef
if ($LASTEXITCODE -ne 0) { throw "Project linking failed." }

Write-Host "Setting the exact application origin for Edge Function CORS and redirects." -ForegroundColor Cyan
supabase secrets set "APP_ORIGIN=$AppOrigin"
if ($LASTEXITCODE -ne 0) { throw "Could not set APP_ORIGIN." }

Write-Host "Deploying invite-user Edge Function..." -ForegroundColor Cyan
supabase functions deploy invite-user
if ($LASTEXITCODE -ne 0) { throw "Edge Function deployment failed." }

Write-Host "`nEdge Function deployed. Supabase supplies SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY to the function runtime. Do not add these secrets to frontend files." -ForegroundColor Green
