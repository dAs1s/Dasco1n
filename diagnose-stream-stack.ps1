<#[
  diagnose-stream-stack.ps1 (alias-aware)
  - Fast inventory
  - Canonicalize config values from multiple env key variants
  - PS 5.1 safe
]#>
[CmdletBinding()]
param(
  [ValidateScript({ Test-Path $_ -PathType Container })][string]$RootPath = 'C:\Dasco1n',
  [string]$OutputPath,
  [switch]$OnlineValidation,
  [switch]$CheckDependencies,
  [ValidateRange(64,20480)][int]$MaxFileKB = 512
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

function Write-Log { param([string]$Level='INFO',[string]$Message)
  $p = ("[{0}] [{1}] {2}" -f (Get-Date -Format 'u'), $Level, $Message)
  switch($Level){ 'INFO'{Write-Host $p}; 'WARN'{Write-Warning $Message}; 'ERROR'{Write-Error $Message}; 'DEBUG'{Write-Verbose $Message -Verbose} }
}

function New-ReportPaths { param([string]$Root,[string]$Out)
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $base = if ($Out) { $Out } else { Join-Path $Root '_diagnostics' }
  $run  = Join-Path $base ('run-' + $ts)
  $logs = Join-Path $run 'logs'
  $reps = Join-Path $run 'reports'
  foreach($p in @($base,$run,$logs,$reps)){ New-Item -ItemType Directory -Path $p -Force | Out-Null }
  [ordered]@{ Base=$base; Run=$run; Logs=$logs; Reports=$reps }
}
$Paths = New-ReportPaths -Root $RootPath -Out $OutputPath
$Global:LogFile = Join-Path $Paths.Logs 'diagnostics.log'

function Mask-Secret { param([string]$Value,[int]$KeepStart=3,[int]$KeepEnd=2)
  if([string]::IsNullOrWhiteSpace($Value)){return $Value}
  $v=$Value.Trim(); $n=$v.Length
  if($n -le ($KeepStart+$KeepEnd)){ return ('*'*$n) }
  $v.Substring(0,$KeepStart)+(''*($n-$KeepStart-$KeepEnd)).Replace("", "*")+$v.Substring($n-$KeepEnd)
}

function Get-SafeContent { param([string]$Path)
  try {
    $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($fi.Length -gt ($MaxFileKB * 1KB)) { Write-Log DEBUG ("Skip large file: {0} ({1} KB)" -f $Path,[math]::Round($fi.Length/1KB)); return $null }
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  } catch { Write-Log WARN ("Read failed: {0} :: {1}" -f $Path,$_.Exception.Message); $null }
}
function ConvertFrom-JsonSafe { param([string]$Text,[string]$Ctx)
  if([string]::IsNullOrWhiteSpace($Text)){return $null}
  try { $Text | ConvertFrom-Json -ErrorAction Stop } catch { Write-Log WARN ("JSON parse failed ({0}): {1}" -f $Ctx,$_.Exception.Message); $null }
}

# ---------- Inventory (fast BFS) ----------
function Get-FileInventory { param([string]$Root)
  Write-Log INFO ("Fast scan: {0}" -f $Root)
  $inv=[ordered]@{ All=@(); EnvFiles=@(); JsonFiles=@(); YamlFiles=@(); Node=[ordered]@{PackageJson=@();LockFiles=@()}; Python=[ordered]@{Requirements=@()}; DotNet=[ordered]@{CsProj=@()}; Commands=@() }
  $q = New-Object System.Collections.Generic.Queue[System.IO.DirectoryInfo]
  $q.Enqueue((Get-Item -LiteralPath $Root))
  $ex = @('node_modules','.git','.vscode','.vs','dist','build','out','coverage','__pycache__','venv','.venv','env','bin','obj','.idea')
  while($q.Count -gt 0){
    $d=$q.Dequeue(); if($ex -contains $d.Name){continue}
    $subs = @(Get-ChildItem -LiteralPath $d.FullName -Directory -Force -EA SilentlyContinue)
    foreach($s in $subs){ if($ex -contains $s.Name){continue}; $q.Enqueue($s) }
    $files = @(Get-ChildItem -LiteralPath $d.FullName -File -Force -EA SilentlyContinue)
    foreach($f in $files){
      $p=$f.FullName; $inv.All+=$p
      if($f.Name -match '^\.(env|env\..+)$'){ $inv.EnvFiles+=$p }
      if($f.Name -ieq 'package.json'){ $inv.Node.PackageJson+=$p }
      if($f.Name -match '^(package-lock\.json|yarn\.lock|pnpm-lock\.yaml)$'){ $inv.Node.LockFiles+=$p }
      if($f.Name -ieq 'requirements.txt'){ $inv.Python.Requirements+=$p }
      if($f.Extension -ieq '.json' -and $f.Length -le 1MB){ $inv.JsonFiles+=$p }
      if($f.Extension -ieq '.csproj'){ $inv.DotNet.CsProj+=$p }
      if($p -match '(?i)\\(commands|slash-commands|cogs|handlers\\commands)\\'){ $inv.Commands+=$p }
    }
  }
  Write-Log INFO ("Fast scan complete. Files={0}" -f $inv.All.Count)
  $inv
}

# ---------- Config parsing + alias resolution ----------
function Parse-EnvFile { param([string]$Text)
  $m=@{}; if([string]::IsNullOrWhiteSpace($Text)){return $m}
  foreach($ln in ($Text -split "`n")){
    $line=$ln.Trim(); if(-not $line -or $line.StartsWith('#')){continue}
    $i=$line.IndexOf('='); if($i -lt 1){continue}
    $k=$line.Substring(0,$i).Trim(); $v=$line.Substring($i+1).Trim().Trim('"').Trim("'")
    $m[$k]=$v
  }; $m
}
function Resolve-Aliases { param($cfg)
  $envVals = $cfg.__envVals
  # Twitch
  $tUser = @($envVals['TWITCH_BOT_USERNAME'],$envVals['TMI_USERNAME'],$envVals['TWITCH_USERNAME']) | Where-Object { $_ } | Select-Object -First 1
  $tOAuth= @($envVals['TWITCH_OAUTH'],$envVals['TWITCH_OAUTH_TOKEN'],$envVals['TMI_PASSWORD']) | Where-Object { $_ } | Select-Object -First 1
  $tChan = @($envVals['TWITCH_CHANNELS']) | Where-Object { $_ } | Select-Object -First 1
  $cfg.Twitch.Values['username']=$tUser; $cfg.Twitch.Values['oauth']=$tOAuth; if($tChan){ $cfg.Twitch.Values['channels']=$tChan }
  $cfg.Twitch.Values['client_id'] = @($envVals['TWITCH_CLIENT_ID']) | Where-Object { $_ } | Select-Object -First 1
  $cfg.Twitch.Values['client_secret'] = @($envVals['TWITCH_CLIENT_SECRET']) | Where-Object { $_ } | Select-Object -First 1
  # Discord
  $dTok = @($envVals['DISCORD_BOT_TOKEN'],$envVals['DISCORD_TOKEN']) | Where-Object { $_ } | Select-Object -First 1
  $cfg.Discord.Values['token']=$dTok
  $cfg.Discord.Values['client_id']=@($envVals['DISCORD_CLIENT_ID']) | Where-Object { $_ } | Select-Object -First 1
  $cfg.Discord.Values['guild_id']=@($envVals['DISCORD_GUILD_ID']) | Where-Object { $_ } | Select-Object -First 1
  $cfg.Discord.Values['mod_role_id']=@($envVals['DISCORD_MOD_ROLE_ID']) | Where-Object { $_ } | Select-Object -First 1
  # OBS
  $cfg.OBS.Values['host'] = @($envVals['OBS_HOST'],'127.0.0.1') | Where-Object { $_ } | Select-Object -First 1
  $cfg.OBS.Values['port'] = @($envVals['OBS_WEBSOCKET_PORT'],'4455') | Where-Object { $_ } | Select-Object -First 1
  $cfg.OBS.Values['password'] = @($envVals['OBS_PASSWORD']) | Where-Object { $_ } | Select-Object -First 1
  # StreamElements
  $cfg.StreamElements.Values['jwt']    = @($envVals['SE_JWT'],$envVals['STREAMELEMENTS_JWT']) | Where-Object { $_ } | Select-Object -First 1
  $cfg.StreamElements.Values['channel']= @($envVals['SE_CHANNEL_ID'],$envVals['STREAMELEMENTS_CHANNEL']) | Where-Object { $_ } | Select-Object -First 1
}
function Find-Configs {
  param($Inventory)

  # Helpers (avoid StrictMode property errors)
  function _GetPropValue {
    param([object]$Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    $p = $Obj.PSObject.Properties[$Name]
    if ($p) { return $p.Value } else { return $null }
  }
  function _IsBlank {
    param([object]$Val)
    if ($null -eq $Val) { return $true }
    $s = [string]$Val
    return [string]::IsNullOrWhiteSpace($s)
  }

  $cfg = [ordered]@{
    Env=@(); Json=@(); Yaml=@()
    Twitch=[ordered]@{ Candidates=@(); Values=@{} }
    Discord=[ordered]@{ Candidates=@(); Values=@{} }
    OBS=[ordered]@{ Candidates=@(); Values=@{} }
    StreamElements=[ordered]@{ Candidates=@(); Values=@{} }
  }

  $envKeys = @(
    'TWITCH_CLIENT_ID','TWITCH_CLIENT_SECRET','TWITCH_BOT_USERNAME','TWITCH_OAUTH','TWITCH_OAUTH_TOKEN','TWITCH_CHANNELS',
    'DISCORD_TOKEN','DISCORD_BOT_TOKEN','DISCORD_CLIENT_ID','DISCORD_CLIENT_SECRET','DISCORD_GUILD_ID',
    'OBS_HOST','OBS_PORT','OBS_PASSWORD','OBS_WS_URL','OBS_WEBSOCKET_PORT',
    'SE_JWT','STREAMELEMENTS_JWT','STREAMELEMENTS_CHANNEL','SE_CHANNEL','SE_CHANNEL_ID'
  )

  # ---- .env files
  foreach ($e in $Inventory.EnvFiles) {
    $kv = Parse-EnvFile (Get-SafeContent $e)
    $cfg.Env += @{ Path=$e; Keys=$kv.Keys }
    foreach ($k in $envKeys) {
      if ($kv.ContainsKey($k)) {
        if ($k -like 'TWITCH_*' -or $k -like 'TMI_*') { $cfg.Twitch.Values[$k] = $kv[$k] }
        elseif ($k -like 'DISCORD_*')                 { $cfg.Discord.Values[$k] = $kv[$k] }
        elseif ($k -like 'OBS_*')                     { $cfg.OBS.Values[$k]     = $kv[$k] }
        elseif ($k -like '*SE*' -or $k -like 'STREAMELEMENTS_*') { $cfg.StreamElements.Values[$k] = $kv[$k] }
      }
    }
  }

  # ---- JSON files (skip package-lock.json)
  foreach ($j in $Inventory.JsonFiles) {
    if ([IO.Path]::GetFileName($j) -ieq 'package-lock.json') { continue }
    $text = Get-SafeContent $j
    $obj  = ConvertFrom-JsonSafe -Text $text -Context $j
    if (-not $obj) { continue }

    # normalize to sequence
    if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) { $items = @($obj) } else { $items = @($obj) }

    foreach ($o in $items) {
      if ($null -eq $o) { continue }
      $names = @($o.PSObject.Properties | Select-Object -ExpandProperty Name)
      $cfg.Json += @{ Path=$j; Keys=$names }

      foreach ($n in $names) {
        if ($n -match '(?i)twitch')  { $cfg.Twitch.Candidates       += $j }
        elseif ($n -match '(?i)discord') { $cfg.Discord.Candidates  += $j }
        elseif ($n -match '(?i)\bobs\b') { $cfg.OBS.Candidates      += $j }
        elseif ($n -match '(?i)element') { $cfg.StreamElements.Candidates += $j }
      }

      # twitch
      $t = _GetPropValue $o 'twitch'
      if ($t) {
        foreach ($k in 'clientId','client_id','username','password','token','oauth','channels') {
          $v = _GetPropValue $t $k
          if (-not (_IsBlank $v)) { $cfg.Twitch.Values[$k] = [string]$v }
        }
      }
      # discord
      $d = _GetPropValue $o 'discord'
      if ($d) {
        foreach ($k in 'token','clientId','client_id','guildId') {
          $v = _GetPropValue $d $k
          if (-not (_IsBlank $v)) { $cfg.Discord.Values[$k] = [string]$v }
        }
      }
      # obs
      $ob = _GetPropValue $o 'obs'
      if ($ob) {
        foreach ($k in 'host','port','password','url') {
          $v = _GetPropValue $ob $k
          if (-not (_IsBlank $v)) { $cfg.OBS.Values[$k] = $v }
        }
      }
      # streamelements
      $se = _GetPropValue $o 'streamelements'
      if ($se) {
        foreach ($k in 'jwt','channel','channel_id') {
          $v = _GetPropValue $se $k
          if (-not (_IsBlank $v)) { $cfg.StreamElements.Values[$k] = [string]$v }
        }
      }
    }
  }

  # ---- YAML files (collect top-level keys and candidates only)
  foreach ($y in $Inventory.YamlFiles) {
    $yo = ConvertFrom-YamlSafe -Text (Get-SafeContent $y) -Context $y
    if ($yo) {
      $keys = @($yo.PSObject.Properties | Select-Object -ExpandProperty Name)
      $cfg.Yaml += @{ Path=$y; Keys=$keys }
      foreach ($n in $keys) {
        if ($n -match '(?i)twitch')  { $cfg.Twitch.Candidates       += $y }
        elseif ($n -match '(?i)discord') { $cfg.Discord.Candidates  += $y }
        elseif ($n -match '(?i)\bobs\b') { $cfg.OBS.Candidates      += $y }
        elseif ($n -match '(?i)element') { $cfg.StreamElements.Candidates += $y }
      }
    } else {
      $cfg.Yaml += @{ Path=$y; Keys=@() }
    }
  }

  # ---- Canonicalize & normalize
  # Discord token: prefer DISCORD_TOKEN
  $discordToken = $cfg.Discord.Values['DISCORD_TOKEN']
  if (_IsBlank $discordToken) { $discordToken = $cfg.Discord.Values['DISCORD_BOT_TOKEN'] }
  if (-not (_IsBlank $discordToken)) { $cfg.Discord.Values['token'] = $discordToken }

  # Twitch oauth: prefer TWITCH_OAUTH, enforce 'oauth:' prefix
  $twOauth = $cfg.Twitch.Values['TWITCH_OAUTH']
  if (_IsBlank $twOauth) { $twOauth = $cfg.Twitch.Values['TWITCH_OAUTH_TOKEN'] }
  if (-not (_IsBlank $twOauth)) {
    $twOauth = $twOauth.ToString().Trim('"').Trim("'")
    if ($twOauth -and $twOauth -notlike 'oauth:*') { $twOauth = 'oauth:' + $twOauth }
    $cfg.Twitch.Values['oauth'] = $twOauth
  }
  # Twitch channels (optional canonical)
  $twCh = $cfg.Twitch.Values['TWITCH_CHANNELS']
  if (-not (_IsBlank $twCh)) { $cfg.Twitch.Values['channels'] = $twCh }

  # OBS host/port/password canonical
  $obsHost = $cfg.OBS.Values['OBS_HOST']; if (-not (_IsBlank $obsHost)) { $cfg.OBS.Values['host'] = $obsHost }
  $obsPort = $cfg.OBS.Values['OBS_WEBSOCKET_PORT']; if (_IsBlank $obsPort) { $obsPort = $cfg.OBS.Values['OBS_PORT'] }
  if (-not (_IsBlank $obsPort)) { $cfg.OBS.Values['port'] = [int]$obsPort }
  $obsPass = $cfg.OBS.Values['OBS_PASSWORD']; if (-not (_IsBlank $obsPass)) { $cfg.OBS.Values['password'] = $obsPass }

  # StreamElements jwt canonical
  $seJwt = $cfg.StreamElements.Values['SE_JWT']
  if (_IsBlank $seJwt) { $seJwt = $cfg.StreamElements.Values['STREAMELEMENTS_JWT'] }
  if (-not (_IsBlank $seJwt)) { $cfg.StreamElements.Values['jwt'] = $seJwt }

  return $cfg
}function Check-NodeRuntime { $r=[ordered]@{NodeFound=$false;NodeVersion=$null;NpmFound=$false;NpmVersion=$null}; $n=Get-Command node -EA SilentlyContinue; if($n){$r.NodeFound=$true; try{$r.NodeVersion=(node -v) 2>$null}catch{}}; $m=Get-Command npm -EA SilentlyContinue; if($m){$r.NpmFound=$true; try{$r.NpmVersion=(npm -v) 2>$null}catch{}}; $r }
function Check-PythonRuntime { $r=[ordered]@{PythonFound=$false;PythonVersion=$null;PipFound=$false;PipVersion=$null}; $py=Get-Command python -EA SilentlyContinue; if(-not $py){$py=Get-Command py -EA SilentlyContinue}; if($py){$r.PythonFound=$true; try{$r.PythonVersion=(& $py.Path --version) 2>&1}catch{}}; $pip=Get-Command pip -EA SilentlyContinue; if($pip){$r.PipFound=$true; try{$r.PipVersion=(& $pip.Path -V) 2>&1}catch{}} elseif($py){ try{$r.PipFound=$true; $r.PipVersion=(& $py.Path -m pip -V) 2>&1}catch{}}; $r }
function Check-NodePackages { param($Inventory)
  $pk=[ordered]@{Deps=@{};Missing=@();NodeModulesExists=$false}
  $pkg = $Inventory.Node.PackageJson | Select-Object -First 1; if(-not $pkg){return $pk}
  $dir = Split-Path -Parent $pkg; $nm = Join-Path $dir 'node_modules'; $pk.NodeModulesExists = Test-Path $nm -PathType Container
  $json = ConvertFrom-JsonSafe (Get-SafeContent $pkg) $pkg
  if($json){ foreach($sec in 'dependencies','devDependencies','optionalDependencies'){ $prop=$json.PSObject.Properties[$sec]; if($prop -and $prop.Value){ foreach($kv in $prop.Value.PSObject.Properties){ $pk.Deps[$kv.Name]=$kv.Value; if($pk.NodeModulesExists -and -not (Test-Path (Join-Path $nm $kv.Name))){ $pk.Missing+=$kv.Name } } } } }
  $pk
}

# ---------- Analyzers ----------
function Test-TcpConnectivity { param([string]$TargetHost,[int]$Port) try{ @{Host=$TargetHost;Port=$Port;Reachable=[bool](Test-NetConnection -ComputerName $TargetHost -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue)} }catch{ @{Host=$TargetHost;Port=$Port;Reachable=$false;Error=$_.Exception.Message} } }

function Analyze-Twitch { param($cfg)
  $res=[ordered]@{Present=$false;Issues=@();Details=@{}}
  $u=$cfg.Twitch.Values['username']; $o=$cfg.Twitch.Values['oauth']
  if($u -or $o){ $res.Present=$true }
  if($o -and ($o -notmatch '^oauth:')){ $res.Issues += 'TWITCH_OAUTH/TWITCH_OAUTH_TOKEN must start with "oauth:"' }
  $res.Details.Values=@{ username=($u); oauth=(if($o){ Mask-Secret $o } else { $null }); channels=$cfg.Twitch.Values['channels'] }
  $res.Details.Connectivity=[ordered]@{}
  $res.Details.Connectivity.Tcp_irc_chat_twitch_tv_6697 = Test-TcpConnectivity -TargetHost 'irc.chat.twitch.tv' -Port 6697
  $res.Details.Connectivity.Tcp_irc_chat_twitch_tv_6667 = Test-TcpConnectivity -TargetHost 'irc.chat.twitch.tv' -Port 6667
  $res
}
function Analyze-Discord { param($cfg)
  $res=[ordered]@{Present=$false;Issues=@();Details=@{}}
  $tok=$cfg.Discord.Values['token']; if($tok){ $res.Present=$true; if($tok -match '\s'){ $res.Issues += 'Discord token contains whitespace' } }
  $res.Details.Values=@{ token=(if($tok){ Mask-Secret $tok } else { $null }); client_id=$cfg.Discord.Values['client_id']; guild_id=$cfg.Discord.Values['guild_id'] }
  $res.Details.Connectivity=[ordered]@{ Tcp_discord_com_443 = Test-TcpConnectivity -TargetHost 'discord.com' -Port 443 }
  $res
}
function Analyze-OBS { param($cfg)
  $res=[ordered]@{Present=$false;Issues=@();Details=@{}}
  $ObsHost=$cfg.OBS.Values['host']; $port=[int]($cfg.OBS.Values['port']); $pwd=$cfg.OBS.Values['password']
  if($ObsHost -or $port -or $pwd){ $res.Present=$true }
  $res.Details.Values=@{ host=$ObsHost; port=$port; password=(if($pwd){ Mask-Secret $pwd } else { $null }) }
  $res.Details.Connectivity=[ordered]@{ ("Tcp_{0}_{1}" -f $ObsHost,$port) = Test-TcpConnectivity -TargetHost $ObsHost -Port $port; ("Tcp_{0}_4444" -f $ObsHost) = Test-TcpConnectivity -TargetHost $ObsHost -Port 4444 }
  $res
}
function Analyze-StreamElements { param($cfg)
  $res=[ordered]@{Present=$false;Issues=@();Details=@{}}
  $jwt=$cfg.StreamElements.Values['jwt']; if($jwt){ $res.Present=$true }
  $res.Details.Values=@{ SE_JWT=(if($jwt){ Mask-Secret $jwt } else { $null }); channel=$cfg.StreamElements.Values['channel'] }
  $res.Details.Connectivity=[ordered]@{ Tcp_api_streamelements_com_443 = Test-TcpConnectivity -TargetHost 'api.streamelements.com' -Port 443 }
  $res
}

# ---------- Report ----------
function New-Report2 { param($Inventory,$Stacks,$Configs,$NodeRT,$PyRT,$NodePkgs,$Twitch,$Discord,$OBS,$SE)
  $summary=[ordered]@{ Timestamp=(Get-Date).ToString('u'); RootPath=$RootPath; PowerShell=$PSVersionTable.PSVersion.ToString(); OS=$env:OS; Node=$NodeRT; Python=$PyRT; Stacks=$Stacks; Services=[ordered]@{Twitch=$Twitch;Discord=$Discord;OBS=$OBS;StreamElements=$SE}; InventorySummary=[ordered]@{ Files=$Inventory.All.Count; Env=$Inventory.EnvFiles.Count; JSON=$Inventory.JsonFiles.Count; YAML=0; Node=$Inventory.Node.PackageJson.Count; PythonReq=$Inventory.Python.Requirements.Count; CsProj=$Inventory.DotNet.CsProj.Count; Commands=$Inventory.Commands.Count }; NodePackages=$NodePkgs }
  try { $summary.OS=(Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty Caption) } catch {}
  $jsonPath = Join-Path $Paths.Reports 'diagnostics.json'; ($summary | ConvertTo-Json -Depth 8) | Out-File -FilePath $jsonPath -Encoding utf8
  $md = New-Object 'System.Collections.Generic.List[string]'
  $md.Add('# Stream Stack Diagnostics'); $md.Add("- Timestamp: $($summary.Timestamp)"); $md.Add("- Root: `$RootPath = $($summary.RootPath)"); $md.Add("- PowerShell: $($summary.PowerShell)"); $md.Add("- OS: $($summary.OS)"); $md.Add(''); $md.Add('## Runtimes'); $md.Add("- Node: Found=$($NodeRT.NodeFound) Version=$($NodeRT.NodeVersion) NPM=$($NodeRT.NpmFound)"); $md.Add("- Python: Found=$($PyRT.PythonFound) Version=$($PyRT.PythonVersion) Pip=$($PyRT.PipFound)"); $md.Add(''); $md.Add('## Detected Stacks'); $md.Add('```json'); $md.Add(($Stacks | ConvertTo-Json -Depth 6)); $md.Add('```'); $md.Add(''); $md.Add('## Inventory Summary'); $md.Add('```json'); $md.Add(($summary.InventorySummary | ConvertTo-Json)); $md.Add('```'); $md.Add(''); $md.Add('## Services')
  foreach($svcName in 'Twitch','Discord','OBS','StreamElements'){ $md.Add("### $svcName"); $svc=$summary.Services.$svcName; $md.Add('```json'); $md.Add(($svc | ConvertTo-Json -Depth 8)); $md.Add('```') }
  $md.Add(''); $md.Add('## Node Packages'); $md.Add('```json'); $md.Add(($NodePkgs | ConvertTo-Json -Depth 6)); $md.Add('```')
  $mdPath = Join-Path $Paths.Reports 'diagnostics.md'; ($md -join "`n") | Out-File -FilePath $mdPath -Encoding utf8
  Write-Log INFO ("Report written: {0}" -f $mdPath); @{ Json=$jsonPath; Markdown=$mdPath }
}

# ---------- Main ----------
$sw=[System.Diagnostics.Stopwatch]::StartNew(); Write-Log INFO '=== Stream Stack Diagnostics START ==='
$Inventory = Get-FileInventory -Root $RootPath
$Inventory.JsonFiles = @($Inventory.JsonFiles | Where-Object { [IO.Path]::GetFileName($_) -ine 'package-lock.json' })
$Stacks    = [ordered]@{ Node=[ordered]@{Present=([bool]($Inventory.Node.PackageJson.Count))}; Python=[ordered]@{Present=([bool]($Inventory.Python.Requirements.Count))}; DotNet=[ordered]@{Present=([bool]($Inventory.DotNet.CsProj.Count))} }
$Configs   = Find-Configs -Inventory $Inventory
$NodeRT    = Check-NodeRuntime; $PyRT = Check-PythonRuntime
$NodePkgs  = Check-NodePackages2 -Inventory $Inventory
$Twitch    = Analyze-Twitch -cfg $Configs
$Discord   = Analyze-Discord -cfg $Configs
$OBS       = Analyze-OBS -cfg $Configs
$SE        = Analyze-StreamElements -cfg $Configs
$reports   = New-Report2 -Inventory $Inventory -Stacks $Stacks -Configs $Configs -NodeRT $NodeRT -PyRT $PyRT -NodePkgs $NodePkgs -Twitch $Twitch -Discord $Discord -OBS $OBS -SE $SE
$sw.Stop(); Write-Log INFO ("Elapsed: {0}" -f $sw.Elapsed)
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host ("1) Open: {0}" -f $reports.Markdown) -ForegroundColor Cyan
Write-Host '2) Paste diagnostics.md here for targeted fixes.' -ForegroundColor Cyan







function Check-NodePackages2 { 
  param($Inventory,[switch]$RunNpmList)
  $pk=[ordered]@{ Deps=@{}; Missing=@(); NodeModulesExists=$false; NpmListOutput=$null }
  $pkgJson = $Inventory.Node.PackageJson | Select-Object -First 1
  if (-not $pkgJson) { return $pk }

  $dir = Split-Path -Parent $pkgJson
  $nm  = Join-Path $dir 'node_modules'
  $pk.NodeModulesExists = Test-Path $nm -PathType Container

  $text = Get-SafeContent $pkgJson
  $json = ConvertFrom-JsonSafe -Text $text -Ctx $pkgJson
  if ($json) {
    foreach ($sec in 'dependencies','devDependencies','optionalDependencies') {
      $prop = $json.PSObject.Properties[$sec]
      if ($prop -and $null -ne $prop.Value) {
        foreach ($kv in $prop.Value.PSObject.Properties) {
          $name = $kv.Name
          $pk.Deps[$name] = $kv.Value
          if ($pk.NodeModulesExists -and -not (Test-Path (Join-Path $nm $name))) { $pk.Missing += $name }
        }
      }
    }
  }

  if ($RunNpmList -and (Get-Command npm -ErrorAction SilentlyContinue)) {
    try { Push-Location $dir; $pk.NpmListOutput = (npm ls --depth=0 2>&1 | Out-String) } finally { Pop-Location }
  }
  $pk
}





