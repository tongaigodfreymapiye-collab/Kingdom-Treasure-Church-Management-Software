[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ProjectUrl,
 [Parameter(Mandatory=$true)][string]$PublishableKey
)
$ErrorActionPreference = "Stop"
$ProjectUrl = $ProjectUrl.TrimEnd('/')
if ($ProjectUrl -notmatch '^https://[a-zA-Z0-9-]+\.supabase\.co$') {
 throw "Project URL format is invalid. Expected https://PROJECT-REF.supabase.co"
}
if ([string]::IsNullOrWhiteSpace($PublishableKey) -or $PublishableKey -match 'service_role|secret') {
 throw "Supply only the public anon/publishable key. Never use service_role or a secret key."
}
$Headers = @{ apikey = $PublishableKey }
Write-Host "Testing Supabase Authentication API reachability..." -ForegroundColor Cyan
try {
 $r = Invoke-RestMethod -Uri "$ProjectUrl/auth/v1/health" -Headers $Headers -Method Get
 Write-Host "Supabase Authentication API is reachable and accepted the public key." -ForegroundColor Green
 $r | Format-List
} catch {
 $status = $_.Exception.Response.StatusCode.value__
 $body = $null
 try {
   $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
   $body = $reader.ReadToEnd()
 } catch {}
 throw "Supabase Auth health check failed (HTTP $status). $body"
}
