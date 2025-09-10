<# collect-project-info.ps1  (PS 5.1 safe)
   - Auto-detect project root (walks up until it finds bots\discord\package.json)
   - Prints absolute paths for root/bots/app
   - Lists Discord commands in src\commands
   - Shows package.json "start" scripts
   - Lists .env files + key envs (masked)
   - Computes effective API_BASE the bot will use and probes it
   - Writes JSON report to <root>\project-scan.json
#>

param([string]$Root='')

function Write-Status {
  param([ValidateSet('OK','WARN','FAIL','INFO')][string]$Level,[string]$Msg)
  $color='White'; switch ($Level) { 'OK'{$color='Green'} 'WARN'{$color='Yellow'} 'FAIL'{$color='Red'} 'INFO'{$color='Cyan'} }
  Write-Host ("[{0}] {1}" -f $Level,$Msg) -ForegroundColor $color
}
function Mask-Value([string]$v){ if(-not $v){return ''}; $v=$v.Trim(); if($v.Length -le 8){return ('*'*$v.Length)}; ($v.Substring(0,4)+'…'+$v.Substring($v.Length-4)) }
function Read-JsonFile([string]$p){ if(-not(Test-Path -LiteralPath $p)){return $null}; try{ (Get-Content -LiteralPath $p -Raw -Encoding UTF8)|ConvertFrom-Json }catch{ $null } }
function Read-DotEnv([string]$p){
  $m=@{}; if(-not(Test-Path -LiteralPath $p)){return $m}
  Get-Content -LiteralPath $p -Encoding UTF8 | ForEach-Object {
    if($_ -match '^\s*#' -or $_ -match '^\s*$'){return}
    $kv = $_ -split '=',2; if($kv.Count -lt 2){return}
    $k=$kv[0].Trim(); $v=$kv[1].Trim() -replace '^\s*"(.*)"\s*$','$1' -replace "^\s*'(.*)'\s*$",'$1'
    if($k){ $m[$k]=$v }
  }
  $m
}
function Grep-Files([System.IO.FileInfo[]]$Files,[string]$Pattern){
  $hits=@()
  foreach($f in $Files){ try{
    $i=0; Get-Content -LiteralPath $f.FullName -Encoding UTF8 | ForEach-Object {
      $i++; if($_ -match $Pattern){
        $hits += [pscustomobject]@{File=$f.FullName;Line=$i;Text=$_.Trim()}
      }
    }
  }catch{} }
  $hits
}
function Test-Http([string]$url,[int]$TimeoutMs=5000){
  try{
    $req=[System.Net.HttpWebRequest]::Create($url); $req.Method='HEAD'; $req.Timeout=$TimeoutMs; $req.AllowAutoRedirect=$true
    $resp=$req.GetResponse(); $code=[int]$resp.StatusCode; $resp.Close()
    [pscustomobject]@{Success=$true; Detail=("HTTP {0}" -f $code)}
  }catch [System.Net.WebException]{
    if($_.Exception.Response){ $code=[int]$_.Exception.Response.StatusCode; $_.Exception.Response.Close(); return [pscustomobject]@{Success=$true;Detail=("HTTP {0}" -f $code)} }
    [pscustomobject]@{Success=$false; Detail=$_.Exception.Message}
  }catch{ [pscustomobject]@{Success=$false; Detail=$_.Exception.Message} }
}
function Resolve-ProjectRoot([string]$start){
  if(-not $start -or $start.Trim() -eq ''){ $start=(Get-Location).Path }
  $cur = (Resolve-Path -LiteralPath $start).Path
  for($i=0; $i -lt 8; $i++){
    $probe = Join-Path $cur 'bots\discord\package.json'
    if(Test-Path -LiteralPath $probe){ return $cur }
    $parent = Split-Path -Parent $cur
    if(-not $parent -or $parent -eq $cur){ break }
    $cur = $parent
  }
  $start
}

$Root = Resolve-ProjectRoot -start $Root
Write-Status INFO ("Root: {0}" -f $Root)

# ----- paths -----
$paths = [ordered]@{}
$bd = Join-Path $Root 'bots\discord'
$bt = Join-Path $Root 'bots\twitch'
$app= Join-Path $Root 'app'
if(Test-Path -LiteralPath $bd){ $paths.bots_discord = (Resolve-Path -LiteralPath $bd).Path } else { $paths.bots_discord = $null }
if(Test-Path -LiteralPath $bt){ $paths.bots_twitch  = (Resolve-Path -LiteralPath $bt).Path } else { $paths.bots_twitch  = $null }
if(Test-Path -LiteralPath $app){$paths.app          = (Resolve-Path -LiteralPath $app).Path} else { $paths.app          = $null }

if($paths.bots_discord){ Write-Status OK   ("Found: {0}" -f $paths.bots_discord) } else { Write-Status WARN "bots\discord missing" }
if($paths.bots_twitch ){ Write-Status OK   ("Found: {0}" -f $paths.bots_twitch ) } else { Write-Status WARN "bots\twitch missing" }
if($paths.app         ){ Write-Status OK   ("Found: {0}" -f $paths.app         ) } else { Write-Status WARN "app missing" }

# ----- env files -----
$envTargets=@()
$envTargets += (Join-Path $Root '.env')
$envTargets += (Join-Path $Root '.env.local')
if($paths.bots_discord){ $envTargets += (Join-Path $paths.bots_discord '.env'); $envTargets += (Join-Path $paths.bots_discord '.env.local') }
if($paths.bots_twitch ){ $envTargets += (Join-Path $paths.bots_twitch  '.env'); $envTargets += (Join-Path $paths.bots_twitch  '.env.local') }
if($paths.app         ){ $envTargets += (Join-Path $paths.app         '.env'); $envTargets += (Join-Path $paths.app         '.env.local') }
$envTargets = $envTargets | Select-Object -Unique

$keyWhitelist=@('DISCORD_TOKEN','PREFIX','API_BASE','PORT','TWITCH_OAUTH','TWITCH_OAUTH_TOKEN','TWITCH_NICK','SE_JWT','SE_CHANNEL_ID','STREAMELEMENTS_JWT','STREAMELEMENTS_CHANNEL','TWITCH_CHANNEL')

$envSummary=@()
foreach($p in $envTargets){
  if(Test-Path -LiteralPath $p){
    $m = Read-DotEnv -Path $p
    $keys=@()
    foreach($k in $keyWhitelist){
      if($m.ContainsKey($k)){ $keys += [pscustomobject]@{Key=$k; Value=$m[$k]; Masked=(Mask-Value $m[$k])} }
    }
    $envSummary += [pscustomobject]@{ Path=(Resolve-Path -LiteralPath $p).Path; Keys=$keys }
  }
}
Write-Status INFO "Env files (masked):"
foreach($e in $envSummary){
  Write-Host ("  {0}" -f $e.Path)
  foreach($kv in $e.Keys){ Write-Host ("    - {0} = {1}" -f $kv.Key,$kv.Masked) }
}

# ----- effective API_BASE -----
$rootEnvMap=@{}; $botEnvMap=@{}
$rootEnv=Join-Path $Root '.env'; if(Test-Path -LiteralPath $rootEnv){ $rootEnvMap = Read-DotEnv -Path $rootEnv }
if($paths.bots_discord){ $botEnv=Join-Path $paths.bots_discord '.env'; if(Test-Path -LiteralPath $botEnv){ $botEnvMap = Read-DotEnv -Path $botEnv } }
$effectiveApiBase = ''
if($rootEnvMap.ContainsKey('API_BASE')){ $effectiveApiBase = $rootEnvMap['API_BASE'] }
elseif($botEnvMap.ContainsKey('API_BASE')){ $effectiveApiBase = $botEnvMap['API_BASE'] }
elseif($rootEnvMap.ContainsKey('PORT')){ $effectiveApiBase = ('http://127.0.0.1:{0}' -f $rootEnvMap['PORT']) }
elseif($botEnvMap.ContainsKey('PORT')){ $effectiveApiBase = ('http://127.0.0.1:{0}' -f $botEnvMap['PORT']) }
else{ $effectiveApiBase = 'http://127.0.0.1:3000' }
Write-Status INFO ("Effective API_BASE guess: {0}" -f $effectiveApiBase)

# Probe API_BASE safely
$baseNoSlash = $effectiveApiBase
if($baseNoSlash.EndsWith('/')){ $baseNoSlash = $baseNoSlash.Substring(0,$baseNoSlash.Length-1) }
$probeUrls = @("$baseNoSlash/health","$baseNoSlash/","$effectiveApiBase")
foreach($u in $probeUrls){
  $r = Test-Http -url $u
  if($r.Success){ Write-Status OK ("Probe {0} -> {1}" -f $u,$r.Detail) } else { Write-Status WARN ("Probe {0} -> {1}" -f $u,$r.Detail) }
}

# ----- Discord bot scan -----
$discord=@{}
if($paths.bots_discord){
  $discord.Dir=$paths.bots_discord
  $discord.PackagePath = Join-Path $paths.bots_discord 'package.json'
  $pkg = Read-JsonFile -Path $discord.PackagePath
  if($pkg -ne $null){ $discord.Name=$pkg.name; $discord.Scripts=$pkg.scripts; $discord.Dependencies=$pkg.dependencies }

  $discord.IndexTs=$null
  foreach($ci in @('src\index.ts','src\main.ts','index.ts')){
    $pp=Join-Path $paths.bots_discord $ci; if(Test-Path -LiteralPath $pp){ $discord.IndexTs=(Resolve-Path -LiteralPath $pp).Path; break }
  }

  $discord.CommandsDir=$null
  foreach($cd in @('src\commands','commands','src\cmd','src\bot\commands')){
    $pp=Join-Path $paths.bots_discord $cd; if(Test-Path -LiteralPath $pp){ $discord.CommandsDir=(Resolve-Path -LiteralPath $pp).Path; break }
  }

  $discord.CommandFiles=@()
  if($discord.CommandsDir){ $discord.CommandFiles = Get-ChildItem -LiteralPath $discord.CommandsDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.ts' } | ForEach-Object { $_.FullName } }

  Write-Status INFO "Discord bot:"
  if($pkg -ne $null){ Write-Host ("  name          : {0}" -f $pkg.name) }
  Write-Host ("  dir           : {0}" -f $paths.bots_discord)
  Write-Host ("  index.ts      : {0}" -f ($(if($discord.IndexTs){$discord.IndexTs}else{'<missing>'})))
  Write-Host ("  commands dir  : {0}" -f ($(if($discord.CommandsDir){$discord.CommandsDir}else{'<missing>'})))
  $startScript = '<none>'; if($pkg -and $pkg.scripts -and $pkg.scripts.start){ $startScript = $pkg.scripts.start }
  Write-Host ("  scripts.start : {0}" -f $startScript)
  Write-Host ("  commands (*.ts):"); foreach($f in $discord.CommandFiles){ Write-Host ("    - {0}" -f $f) }

  $srcTs = Get-ChildItem -LiteralPath (Join-Path $paths.bots_discord 'src') -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.ts','.js') }
  $onMessage = Grep-Files -Files $srcTs -Pattern "messageCreate"
  Write-Host ("  messageCreate handlers: {0}" -f $onMessage.Count)
  foreach($h in $onMessage){ Write-Host ("    - {0}:{1}  {2}" -f $h.File,$h.Line,$h.Text) }
}

# ----- Twitch bot (light) -----
$twitch=@{}
if($paths.bots_twitch){
  $twitch.Dir=$paths.bots_twitch
  $twitch.PackagePath=Join-Path $paths.bots_twitch 'package.json'
  $pkgT=Read-JsonFile -Path $twitch.PackagePath
  if($pkgT -ne $null){
    Write-Status INFO "Twitch bot:"
    Write-Host ("  dir           : {0}" -f $paths.bots_twitch)
    $tStart = '<none>'; if($pkgT.scripts -and $pkgT.scripts.start){ $tStart = $pkgT.scripts.start }
    Write-Host ("  scripts.start : {0}" -f $tStart)
  }
}

# ----- App (light) -----
$appInfo=@{}
if($paths.app){
  $appInfo.Dir=$paths.app
  $appInfo.PackagePath=Join-Path $paths.app 'package.json'
  $pkgA=Read-JsonFile -Path $appInfo.PackagePath
  if($pkgA -ne $null){
    Write-Status INFO "App:"
    Write-Host ("  dir           : {0}" -f $paths.app)
    $aStart='<none>'; if($pkgA.scripts -and $pkgA.scripts.start){ $aStart=$pkgA.scripts.start }
    Write-Host ("  scripts.start : {0}" -f $aStart)
  }
}

# ----- JSON report -----
$report = [ordered]@{
  Root = $Root
  Paths = $paths
  EnvSummary = $envSummary
  EffectiveApiBase = $effectiveApiBase
  Discord = $discord
  Twitch = $twitch
  App = $appInfo
  Timestamp = (Get-Date).ToString('s')
}
try{
  $json = $report | ConvertTo-Json -Depth 6
  $outPath = Join-Path $Root 'project-scan.json'
  Set-Content -LiteralPath $outPath -Value $json -Encoding UTF8
  Write-Status OK ("Wrote report: {0}" -f $outPath)
}catch{
  Write-Status WARN ("Failed to write report: {0}" -f $_.Exception.Message)
}
