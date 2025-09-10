# Save as: C:\Dasco1n\tools\patch-find-configs.ps1
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File C:\Dasco1n\tools\patch-find-configs.ps1

$ErrorActionPreference = 'Stop'

# Targets
$targets = @(
  'C:\Dasco1n\diagnose-stream-stack.clean.ps1',
  'C:\Dasco1n\diagnose-stream-stack.ps1'
) | Where-Object { Test-Path -LiteralPath $_ }

if (-not $targets) { Write-Error 'No target files found.'; exit 1 }

function Replace-InFunction {
  param(
    [string]$Text,
    [string]$FuncName,
    [string]$NewBody      # full `function NAME { ... }`
  )
  $pattern = "(?is)function\s+$([regex]::Escape($FuncName))\s*\{"
  $m = [regex]::Match($Text, $pattern)
  if (-not $m.Success) { return $Text }

  $start = $m.Index
  $depth = 0
  $end   = $null
  for ($i = $start; $i -lt $Text.Length; $i++) {
    $ch = $Text[$i]
    if ($ch -eq '{') { $depth++ }
    elseif ($ch -eq '}') {
      if ($depth -gt 0) { $depth-- }
      if ($depth -eq 0 -and $i -gt $start) { $end = $i; break }
    }
  }
  if (-not $end) { return $Text }
  $Text.Remove($start, $end - $start + 1).Insert($start, $NewBody)
}

$newFn = @'
function Find-Configs {
  param($Inventory)

  $cfg = [ordered]@{
    Env=@(); Json=@(); Yaml=@()
    Twitch=[ordered]@{ Candidates=@(); Values=@{} }
    Discord=[ordered]@{ Candidates=@(); Values=@{} }
    OBS=[ordered]@{ Candidates=@(); Values=@{} }
    StreamElements=[ordered]@{ Candidates=@(); Values=@{} }
  }

  function Add-IfValue([hashtable]$bag, [string]$key, $value) {
    if ($null -ne $value) {
      $s = [string]$value
      if (-not [string]::IsNullOrWhiteSpace($s)) {
        if (-not $bag.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($bag[$key])) {
          $bag[$key] = $s
        }
      }
    }
  }

  function Coalesce($o, [string]$name) {
    if ($null -eq $o) { return $null }
    $prop = $o.PSObject.Properties[$name]
    if ($prop) { return $prop.Value }
    return $null
  }

  function Expand($obj) {
    if ($null -eq $obj) { return @() }
    if ($obj -is [string]) { return @($obj) }
    if ($obj -is [System.Collections.IEnumerable]) { return @($obj) }
    return @($obj)
  }

  # --- ENV ---
  $envKeys = @(
    'TWITCH_CLIENT_ID','TWITCH_CLIENT_SECRET','TWITCH_BOT_USERNAME','TWITCH_OAUTH','TWITCH_OAUTH_TOKEN','TMI_USERNAME','TMI_PASSWORD',
    'DISCORD_TOKEN','DISCORD_BOT_TOKEN','DISCORD_CLIENT_ID','DISCORD_CLIENT_SECRET','DISCORD_GUILD_ID',
    'OBS_HOST','OBS_PORT','OBS_PASSWORD','OBS_WS_URL','OBS_WEBSOCKET_PORT',
    'SE_JWT','STREAMELEMENTS_JWT','STREAMELEMENTS_CHANNEL','SE_CHANNEL','SE_CHANNEL_ID'
  )

  foreach ($e in $Inventory.EnvFiles) {
    $name = [IO.Path]::GetFileName($e)
    if ($name -match '(?i)\.env\.(example|bak|backup|dist)$') { continue }

    $kv = Parse-EnvFile (Get-SafeContent $e)
    $cfg.Env += @{ Path=$e; Keys=$kv.Keys }

    $vals = @{}
    foreach ($k in $envKeys) {
      if ($kv.ContainsKey($k)) {
        $v = $kv[$k]
        if (-not [string]::IsNullOrWhiteSpace($v)) { $vals[$k] = $v }
      }
    }

    if (-not $vals.ContainsKey('DISCORD_TOKEN') -and $vals.ContainsKey('DISCORD_BOT_TOKEN')) {
      $vals['DISCORD_TOKEN'] = $vals['DISCORD_BOT_TOKEN']
    }
    if (-not $vals.ContainsKey('TWITCH_OAUTH') -and $vals.ContainsKey('TWITCH_OAUTH_TOKEN')) {
      $tok = $vals['TWITCH_OAUTH_TOKEN'].Trim('"').Trim("'")
      if ($tok -and $tok -notlike 'oauth:*') { $tok = 'oauth:' + $tok }
      $vals['TWITCH_OAUTH'] = $tok
    }

    foreach ($pair in $vals.GetEnumerator()) {
      $k = $pair.Key; $v = $pair.Value
      if     ($k -like 'TWITCH_*' -or $k -like 'TMI_*')            { Add-IfValue $cfg.Twitch.Values $k $v }
      elseif ($k -like 'DISCORD_*' -or $k -eq 'token')             { Add-IfValue $cfg.Discord.Values $k $v }
      elseif ($k -like 'OBS_*')                                    { Add-IfValue $cfg.OBS.Values $k $v }
      elseif ($k -like '*SE*' -or $k -like 'STREAMELEMENTS_*')     { Add-IfValue $cfg.StreamElements.Values $k $v }
    }
  }

  # --- JSON ---
  foreach ($j in $Inventory.JsonFiles) {
    if ([IO.Path]::GetFileName($j) -ieq 'package-lock.json') { continue }
    $obj = ConvertFrom-JsonSafe (Get-SafeContent $j) $j
    if ($obj) {
      foreach ($o in (Expand $obj)) {
        if ($o -is [string]) { continue }
        $keys = @($o.PSObject.Properties | Select-Object -ExpandProperty Name)
        $cfg.Json += @{ Path=$j; Keys=$keys }
        foreach ($n in $keys) {
          switch -regex ($n) {
            '(?i)twitch'  { $cfg.Twitch.Candidates += $j }
            '(?i)discord' { $cfg.Discord.Candidates += $j }
            '(?i)obs'     { $cfg.OBS.Candidates += $j }
            '(?i)element' { $cfg.StreamElements.Candidates += $j }
          }
        }
        $t = Coalesce $o 'twitch'
        if ($t) {
          foreach ($k in 'clientId','client_id','username','password','token','oauth') {
            $pv = Coalesce $t $k; if ($null -ne $pv) { Add-IfValue $cfg.Twitch.Values $k $pv }
          }
        }
        $d = Coalesce $o 'discord'
        if ($d) {
          foreach ($k in 'token','clientId','client_id','guildId') {
            $pv = Coalesce $d $k; if ($null -ne $pv) { Add-IfValue $cfg.Discord.Values $k $pv }
          }
        }
        $o2 = Coalesce $o 'obs'
        if ($o2) {
          foreach ($k in 'host','port','password','url') {
            $pv = Coalesce $o2 $k; if ($null -ne $pv) { Add-IfValue $cfg.OBS.Values $k $pv }
          }
        }
        $se = Coalesce $o 'streamelements'
        if ($se) {
          foreach ($k in 'jwt','channel','channel_id') {
            $pv = Coalesce $se $k; if ($null -ne $pv) { Add-IfValue $cfg.StreamElements.Values $k $pv }
          }
        }
      }
    }
  }

  # --- YAML ---
  foreach ($y in $Inventory.YamlFiles) {
    $obj = ConvertFrom-YamlSafe (Get-SafeContent $y) $y
    if ($obj) {
      foreach ($o in (Expand $obj)) {
        if ($o -is [string]) { continue }
        $keys = @($o.PSObject.Properties | Select-Object -ExpandProperty Name)
        $cfg.Yaml += @{ Path=$y; Keys=$keys }
        foreach ($n in $keys) {
          switch -regex ($n) {
            '(?i)twitch'  { $cfg.Twitch.Candidates += $y }
            '(?i)discord' { $cfg.Discord.Candidates += $y }
            '(?i)obs'     { $cfg.OBS.Candidates += $y }
            '(?i)element' { $cfg.StreamElements.Candidates += $y }
          }
        }
      }
    } else { $cfg.Yaml += @{ Path=$y; Keys=@() } }
  }

  return $cfg
}
'@

foreach ($file in $targets) {
  $bak = "$file.bak_$(Get-Date -Format yyyyMMddHHmmss)"
  Copy-Item -LiteralPath $file -Destination $bak -Force
  Write-Host "Backup -> $bak" -ForegroundColor Cyan

  $raw = Get-Content -LiteralPath $file -Raw
  $patched = Replace-InFunction -Text $raw -FuncName 'Find-Configs' -NewBody $newFn
  Set-Content -LiteralPath $file -Encoding UTF8 -Value $patched
  Write-Host "Patched -> $file" -ForegroundColor Green
}

# Re-run clean diag
$diagArgs = @{ RootPath = 'C:\Dasco1n'; OnlineValidation = $true; CheckDependencies = $false; Verbose = $true }
& 'C:\Dasco1n\diagnose-stream-stack.clean.ps1' @diagArgs

# Open newest report
$base = 'C:\Dasco1n\_diagnostics'
$md = Get-ChildItem -Path $base -Recurse -File -Filter diagnostics.md -EA SilentlyContinue |
      Sort-Object LastWriteTime -Desc | Select-Object -First 1
if ($md) { Write-Host "Opening $($md.FullName)" -ForegroundColor Green; Invoke-Item -LiteralPath $md.FullName }
