[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ProjectUrl,
 [Parameter(Mandatory=$true)][string]$PublishableKey
)
$ErrorActionPreference = "Stop"
$ProjectUrl = $ProjectUrl.TrimEnd('/')
$Headers = @{ apikey = $PublishableKey; Authorization = "Bearer $PublishableKey" }
Write-Host "Testing Supabase REST API reachability..." -ForegroundColor Cyan
try {
 $r = Invoke-WebRequest -Uri "$ProjectUrl/rest/v1/" -Headers $Headers -Method Get
 Write-Host "Supabase endpoint reachable. HTTP $($r.StatusCode)" -ForegroundColor Green
} catch {
 $status = $_.Exception.Response.StatusCode.value__
 if ($status -in @(401,403)) {
   Write-Host "Endpoint is reachable but returned HTTP $status. Check the public key and API settings." -ForegroundColor Yellow
 } else {
   throw "Supabase API test failed: $($_.Exception.Message)"
 }
}
