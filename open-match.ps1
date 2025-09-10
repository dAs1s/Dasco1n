param(
  [string]$P1 = "Alice",
  [string]$P2 = "Bob",
  [string]$Channel = "default",
  [string]$OpenedBy = "cli"
)

$body = @{ p1 = $P1; p2 = $P2; channelId = $Channel; openedBy = $OpenedBy } | ConvertTo-Json
try {
  $resp = Invoke-RestMethod -Uri "http://localhost:3000/api/matches/open" `
            -Method POST -ContentType "application/json" -Body $body
  $resp | ConvertTo-Json -Depth 6
} catch {
  $errBody = $_.ErrorDetails.Message
  if (-not $errBody) {
    $stream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $errBody = $reader.ReadToEnd()
  }
  Write-Host "❌ API error: $errBody" -f Red
}
