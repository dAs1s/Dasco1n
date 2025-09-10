<# check-connections.ps1  (PowerShell 5.1 safe)
    - Auto-detect .env / .env.local next to this script or in C:\Dasco1n
    - Network HEAD checks
    - Token validation (Discord, Twitch); optional StreamElements JWT check
#>

param([string]$EnvFile = '')

# Force TLS1.2 on .NET 4.x
try {
  [System.Net.ServicePointManager]::SecurityProtocol =
    [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
} catch {}

# ---------- helpers ----------
function Write-Status {
  param([ValidateSet('OK','WARN','FAIL','INFO')][string]$Level,[string]$Msg)
  $color='White'
  switch ($Level) {
    'OK'   { $color='Green' }
    'WARN' { $color='Yellow' }
    'FAIL' { $color='Red' }
    'INFO' { $color='Cyan' }
  }
  Write-Host ("[{0}] {1}" -f $Level, $Msg) -ForegroundColor $color
}

function Load-DotEnv {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return @{} }
  $map = @{}
  Get-Content -LiteralPath $Path | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    $kv = $_ -split '=', 2
    if ($kv.Count -lt 2) { return }
    $k = $kv[0].Trim()
    $v = $kv[1].Trim() -replace '^\s*"(.*)"\s*$', '$1' -replace "^\s*'(.*)'\s*$", '$1'
    if ($k) { $map[$k] = $v; Set-Item -Path ("Env:{0}" -f $k) -Value $v | Out-Null }
  }
  return $map
}

function Resolve-EnvFile {
  param([string]$Preferred)
  if ($Preferred -and (Test-Path -LiteralPath $Preferred)) { return $Preferred }
  $candidates = @()
  if ($PSScriptRoot) {
    $candidates += @( (Join-Path $PSScriptRoot '.env.local'),
                      (Join-Path $PSScriptRoot '.env') )
  }
  $candidates += @( (Join-Path (Get-Location) '.env.local'),
                    (Join-Path (Get-Location) '.env'),
                    'C:\Dasco1n\.env.local',
                    'C:\Dasco1n\.env' )
  foreach ($p in $candidates) { if (Test-Path -LiteralPath $p) { return $p } }
  return ''
}

function Test-HttpReachable {
  param([Parameter(Mandatory)][string]$Url, [int]$TimeoutMs = 8000)
  try {
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = 'HEAD'
    $req.AllowAutoRedirect = $true
    $req.Timeout = $TimeoutMs
    $req.ReadWriteTimeout = $TimeoutMs
    $resp = $req.GetResponse()
    $code = [int]$resp.StatusCode
    $resp.Close()
    return [pscustomobject]@{ Success=$true; Detail=("HTTP {0}" -f $code) }
  } catch [System.Net.WebException] {
    if ($_.Exception.Response) {
      $code = [int]$_.Exception.Response.StatusCode
      $_.Exception.Response.Close()
      return [pscustomobject]@{ Success=$true; Detail=("HTTP {0}" -f $code) }
    } else {
      return [pscustomobject]@{ Success=$false; Detail=$_.Exception.Message }
    }
  } catch {
    return [pscustomobject]@{ Success=$false; Detail=$_.Exception.Message }
  }
}

function Check-DiscordAuth {
  param([string]$Token)
  if (-not $Token) { return [pscustomobject]@{ Success=$false; Detail='Missing Discord token' } }
  try {
    $headers = @{ Authorization = ("Bot {0}" -f $Token) }
    $me = Invoke-RestMethod -Method Get -Uri 'https://discord.com/api/v10/users/@me' -Headers $headers -TimeoutSec 10
    $tag = $me.username
    if ($me.discriminator) { $tag = ("{0}#{1}" -f $me.username,$me.discriminator) }
    return [pscustomobject]@{ Success=$true; Detail=("Valid for {0} (ID {1})" -f $tag,$me.id) }
  } catch {
    return [pscustomobject]@{ Success=$false; Detail=("API error: {0}" -f $_.Exception.Message) }
  }
}

function Check-TwitchToken {
  param([string]$OAuthLike)
  if (-not $OAuthLike) { return [pscustomobject]@{ Success=$false; Detail='Missing Twitch OAuth token' } }
  $raw = $OAuthLike
  if ($raw -like 'oauth:*') { $raw = $raw.Substring(6) }
  try {
    $headers = @{ Authorization = ("OAuth {0}" -f $raw) }
    $v = Invoke-RestMethod -Method Get -Uri 'https://id.twitch.tv/oauth2/validate' -Headers $headers -TimeoutSec 10
    $who = if ($v.login) { $v.login } else { $v.user_name }
    $cid = $v.client_id
    return [pscustomobject]@{ Success=$true; Detail=("Valid token for {0} (client_id {1})" -f $who,$cid) }
  } catch {
    return [pscustomobject]@{ Success=$false; Detail=("Validate error: {0}" -f $_.Exception.Message) }
  }
}

function Check-StreamElementsJwt {
  param([string]$Jwt)
  if (-not $Jwt -or $Jwt -match '^\s*(your_|<|placeholder)') {
    return [pscustomobject]@{ Success=$false; Detail='No StreamElements JWT set (skipping auth check)' }
  }
  try {
    $headers = @{ Authorization = ("Bearer {0}" -f $Jwt) }
    $me = Invoke-RestMethod -Method Get -Uri 'https://api.streamelements.com/kappa/v2/users/me' -Headers $headers -TimeoutSec 10
    $name = if ($me.displayName) { $me.displayName } else { $me.username }
    return [pscustomobject]@{ Success=$true; Detail=("JWT valid (user {0})" -f $name) }
  } catch {
    return [pscustomobject]@{ Success=$false; Detail=("JWT error: {0}" -f $_.Exception.Message) }
  }
}

# ---------- load env ----------
Write-Host ""
$envPath = Resolve-EnvFile -Preferred $EnvFile
if ($envPath -and $envPath.Trim() -ne '') {
  Load-DotEnv -Path $envPath | Out-Null
  Write-Status -Level 'OK' -Msg ("Loaded env file: {0}" -f $envPath)
} else {
  Write-Status -Level 'INFO' -Msg 'Proceeding with current process environment (no .env found).'
}

# ---------- gather env ----------
# Prefer DISCORD_TOKEN; fall back to DISCORD_BOT_TOKEN
$discordToken = $null
if ($env:DISCORD_TOKEN)      { $discordToken = $env:DISCORD_TOKEN }
elseif ($env:DISCORD_BOT_TOKEN) { $discordToken = $env:DISCORD_BOT_TOKEN }

# Prefer TWITCH_OAUTH; fall back to TWITCH_OAUTH_TOKEN
$twitchOAuth = $null
if ($env:TWITCH_OAUTH)       { $twitchOAuth = $env:TWITCH_OAUTH }
elseif ($env:TWITCH_OAUTH_TOKEN) { $twitchOAuth = $env:TWITCH_OAUTH_TOKEN }

$seJwt = $env:SE_JWT

# ---------- DISCORD ----------
Write-Host ""
Write-Status -Level 'INFO' -Msg 'Discord'
$netD = Test-HttpReachable -Url 'https://discord.com/api/v10'
if ($netD.Success) { Write-Status -Level 'OK' -Msg $netD.Detail } else { Write-Status -Level 'FAIL' -Msg ("Network: {0}" -f $netD.Detail) }

if ($discordToken) {
  $auth = Check-DiscordAuth -Token $discordToken
  if ($auth.Success) { Write-Status -Level 'OK' -Msg ("Token: {0}" -f $auth.Detail) }
  else               { Write-Status -Level 'FAIL' -Msg ("Token: {0}" -f $auth.Detail) }
} else {
  Write-Status -Level 'WARN' -Msg 'No Discord token found (set DISCORD_TOKEN or DISCORD_BOT_TOKEN in your .env).'
}

# ---------- TWITCH ----------
Write-Host ""
Write-Status -Level 'INFO' -Msg 'Twitch'
$netT = Test-HttpReachable -Url 'https://id.twitch.tv/oauth2/validate'
if ($netT.Success) { Write-Status -Level 'OK' -Msg $netT.Detail } else { Write-Status -Level 'FAIL' -Msg ("Network: {0}" -f $netT.Detail) }

if ($twitchOAuth) {
  $tv = Check-TwitchToken -OAuthLike $twitchOAuth
  if ($tv.Success) { Write-Status -Level 'OK' -Msg ("OAuth: {0}" -f $tv.Detail) }
  else             { Write-Status -Level 'FAIL' -Msg ("OAuth: {0}" -f $tv.Detail) }
} else {
  Write-Status -Level 'WARN' -Msg 'No Twitch OAuth token found (set TWITCH_OAUTH or TWITCH_OAUTH_TOKEN in your .env).'
}

# ---------- STREAMELEMENTS ----------
Write-Host ""
Write-Status -Level 'INFO' -Msg 'StreamElements'
$seApi = Test-HttpReachable -Url 'https://api.streamelements.com/'
$seRt  = Test-HttpReachable -Url 'https://realtime.streamelements.com/'
if ($seApi.Success) { Write-Status -Level 'OK' -Msg ("API: {0}" -f $seApi.Detail) } else { Write-Status -Level 'FAIL' -Msg ("API network: {0}" -f $seApi.Detail) }
if ($seRt.Success)  { Write-Status -Level 'OK' -Msg ("Realtime: {0}" -f $seRt.Detail) } else { Write-Status -Level 'FAIL' -Msg ("Realtime network: {0}" -f $seRt.Detail) }

# Optional JWT validation
$seCheck = Check-StreamElementsJwt -Jwt $seJwt
if ($seCheck.Success) { Write-Status -Level 'OK' -Msg ("JWT: {0}" -f $seCheck.Detail) }
else                  { Write-Status -Level 'WARN' -Msg ("JWT: {0}" -f $seCheck.Detail) }

# ---------- Hints ----------
Write-Host ""
Write-Status -Level 'INFO' -Msg 'Hints'
if (-not $discordToken) { Write-Host '  - Put DISCORD_TOKEN (or DISCORD_BOT_TOKEN) in your .env to test Discord auth.' }
if (-not $twitchOAuth)  { Write-Host '  - Put TWITCH_OAUTH (value like oauth:xxxxxxxx) or TWITCH_OAUTH_TOKEN in your .env.' }
if (-not $seJwt)        { Write-Host '  - (Optional) Put SE_JWT in your .env to validate StreamElements auth.' }
Write-Host ""
