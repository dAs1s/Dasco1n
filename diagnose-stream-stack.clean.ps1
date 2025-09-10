<#  diagnose-stream-stack.clean.ps1  # read-only diagnostics
    Outputs: C:\Dasco1n\_diagnostics\run-<ts>\{logs,reports}\diagnostics.(json|md)
#>
[CmdletBinding()]
param(
  [ValidateScript({ Test-Path $_ -PathType Container })][string]$RootPath='C:\Dasco1n',
  [string]$OutputPath,
  [switch]$OnlineValidation,
  [switch]$CheckDependencies,
  [ValidateRange(64,20480)][int]$MaxFileKB=512
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$PSDefaultParameterValues['Out-File:Encoding']='utf8'

function New-ReportPaths{
  param([string]$Root,[string]$Out)
  $ts=Get-Date -Format 'yyyyMMdd-HHmmss'
  $base=if($Out){$Out}else{Join-Path $Root '_diagnostics'}
  $run =Join-Path $base ('run-'+$ts)
  $logs=Join-Path $run 'logs'
  $reps=Join-Path $run 'reports'
  foreach($p in @($base,$run,$logs,$reps)){ New-Item -ItemType Directory -Path $p -Force | Out-Null }
  [ordered]@{ Base=$base;Run=$run;Logs=$logs;Reports=$reps }
}
$Paths=New-ReportPaths -Root $RootPath -Out $OutputPath
$Global:LogFile=Join-Path $Paths.Logs 'diagnostics.log'

function Write-Log{
  param(
    [ValidateSet('INFO','WARN','ERROR','DEBUG','VERBOSE')][string]$Level='INFO',
    [Parameter(Mandatory=$true)][string]$Message
  )
  $prefix="[$(Get-Date -Format 'u')] [$Level] "
  $line=$prefix+$Message
  switch($Level){
    'INFO'    { Write-Host    $line }
    'WARN'    { Write-Warning $Message }
    'ERROR'   { Write-Error   $Message }
    'DEBUG'   { Write-Verbose $Message -Verbose }
    'VERBOSE' { Write-Verbose $Message }
  }
  try{ $line | Out-File -FilePath $Global:LogFile -Append }catch{}
}

function Mask-Secret{ param([string]$Value,[int]$KeepStart=3,[int]$KeepEnd=2)
  if([string]::IsNullOrWhiteSpace($Value)){return $Value}
  $v=$Value.Trim(); $len=$v.Length
  if($len -le ($KeepStart+$KeepEnd)){ return ('*'*$len) }
  $v.Substring(0,$KeepStart)+(''*($len-$KeepStart-$KeepEnd))+$v.Substring($len-$KeepEnd)
}

function Invoke-Safely{ param([scriptblock]$Script,[string]$Context='op')
  try{ & $Script }catch{ Write-Log -Level 'ERROR' -Message ("$Context failed: "+$_.Exception.Message); $null }
}

function Get-SafeContent{ param([string]$Path)
  try{
    $fi=Get-Item -LiteralPath $Path -ErrorAction Stop
    if($fi.Length -gt ($MaxFileKB*1KB)){
      Write-Log VERBOSE "Skip large file: $Path ($([math]::Round($fi.Length/1KB)) KB)"; return $null
    }
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  }catch{ Write-Log ERROR "Read failed: $Path :: $($_.Exception.Message)"; $null }
}

function ConvertFrom-JsonSafe{ param([string]$Text,[string]$Ctx)
  if([string]::IsNullOrWhiteSpace($Text)){ return $null }
  try{ $Text | ConvertFrom-Json -ErrorAction Stop }catch{ Write-Log WARN "JSON parse failed ($Ctx): $($_.Exception.Message)"; $null }
}

$Global:YAMLAvailable=$false
Invoke-Safely -Context 'Import powershell-yaml' -Script {
  if(Get-Module -ListAvailable -Name 'powershell-yaml'){ Import-Module powershell-yaml -ErrorAction Stop; $Global:YAMLAvailable=$true; Write-Log VERBOSE 'powershell-yaml loaded' }
}
function ConvertFrom-YamlSafe{ param([string]$Text,[string]$Context)
  if(-not $Global:YAMLAvailable -or [string]::IsNullOrWhiteSpace($Text)){ return $null }
  try{ ConvertFrom-Yaml -Yaml $Text }catch{ Write-Log WARN "YAML parse failed ($Context): $($_.Exception.Message)"; $null }
}

function Parse-EnvFile{ param([string]$Text)
  $result=@{}; if([string]::IsNullOrWhiteSpace($Text)){return $result}
  foreach($ln in ($Text -split "`n")){
    $line=$ln.Trim(); if(-not $line -or $line.StartsWith('#')){continue}
    $i=$line.IndexOf('='); if($i -lt 1){continue}
    $k=$line.Substring(0,$i).Trim(); $v=$line.Substring($i+1).Trim().Trim('"').Trim("'")
    $result[$k]=$v
  }; $result
}

function Get-FileInventory{
  param(
    [string]$Root,
    [string[]]$ExcludeDirs=@('node_modules','.git','.vscode','.vs','dist','build','out','coverage','__pycache__','venv','.venv','env','bin','obj','.idea','.turbo'),
    [int]$MaxItems=120000
  )
  Write-Log INFO "Fast scan: $Root"
  $inv=[ordered]@{
    All=@(); EnvFiles=@(); JsonFiles=@(); YamlFiles=@()
    Node=[ordered]@{ PackageJson=@(); LockFiles=@(); TypeScript=@(); JavaScript=@() }
    Python=[ordered]@{ Requirements=@(); Pipfile=@(); PyProject=@(); Python=@() }
    DotNet=[ordered]@{ CsProj=@(); Solutions=@(); CSharp=@() }
    Commands=@(); Docs=@()
  }
  $q=New-Object System.Collections.Generic.Queue[System.IO.DirectoryInfo]
  $rootDir=Get-Item -LiteralPath $Root -ErrorAction Stop
  $q.Enqueue($rootDir)
  while($q.Count -gt 0){
    $dir=$q.Dequeue()
    if($ExcludeDirs -contains $dir.Name){ continue }
    $subs = @(Get-ChildItem -LiteralPath $dir.FullName -Directory -Force -ErrorAction SilentlyContinue)
    foreach($sd in $subs){ if($ExcludeDirs -contains $sd.Name){continue}; $q.Enqueue($sd) }
    $files=@(Get-ChildItem -LiteralPath $dir.FullName -File -Force -ErrorAction SilentlyContinue)
    foreach($f in $files){
      if($inv.All.Count -ge $MaxItems){ Write-Log WARN "Hit MaxItems=$MaxItems; stopping early."; break }
      $p=$f.FullName; $inv.All+=$p; $name=$f.Name; $ext=$f.Extension.ToLowerInvariant()
      if($name -match '^\.(env|env\..+)$'){ $inv.EnvFiles+=$p; continue }
      switch($ext){
        '.json'   { if($f.Length -le 1MB){ $inv.JsonFiles+=$p } }
        '.yml'    { $inv.YamlFiles+=$p }
        '.yaml'   { $inv.YamlFiles+=$p }
        '.ts'     { $inv.Node.TypeScript+=$p }
        '.js'     { $inv.Node.JavaScript+=$p }
        '.py'     { $inv.Python.Python+=$p }
        '.csproj' { $inv.DotNet.CsProj+=$p }
        '.sln'    { $inv.DotNet.Solutions+=$p }
        '.cs'     { $inv.DotNet.CSharp+=$p }
      }
      if($name -ieq 'package.json'){ $inv.Node.PackageJson+=$p }
      elseif($name -match '^(package-lock\.json|yarn\.lock|pnpm-lock\.yaml)$'){ $inv.Node.LockFiles+=$p }
      elseif($name -ieq 'requirements.txt'){ $inv.Python.Requirements+=$p }
      elseif($name -ieq 'Pipfile'){ $inv.Python.Pipfile+=$p }
      elseif($name -ieq 'pyproject.toml'){ $inv.Python.PyProject+=$p }
      elseif($name -match '^(README|README\.md|README\.txt)$'){ $inv.Docs+=$p }
      if($p -match '(?i)\\(commands|slash-commands|cogs|handlers\\commands)\\'){ $inv.Commands+=$p }
    }
  }
  # Skip heavyweight/derived JSONs for content parsing
  $inv.JsonFiles=@($inv.JsonFiles | Where-Object { [IO.Path]::GetFileName($_) -ine 'package-lock.json' })
  Write-Log INFO ("Fast scan complete. Files="+$inv.All.Count)
  $inv
}

function Detect-TechStacks{ param($Inventory)
  $stacks=[ordered]@{ Node=[ordered]@{ Present=$false; Dependencies=@{} }; Python=[ordered]@{ Present=$false; Dependencies=@{} }; DotNet=[ordered]@{ Present=$false; Packages=@{} } }
  foreach($pkg in $Inventory.Node.PackageJson){
    $text=Get-SafeContent $pkg; $json=ConvertFrom-JsonSafe -Text $text -Ctx $pkg
    if($json){
      $stacks.Node.Present=$true
      foreach($sec in 'dependencies','devDependencies','optionalDependencies'){
        $prop=$json.PSObject.Properties[$sec]
        if($prop -and $null -ne $prop.Value){
          foreach($kv in $prop.Value.PSObject.Properties){ $stacks.Node.Dependencies[$kv.Name]=$kv.Value }
        }
      }
    }
  }
  foreach($req in $Inventory.Python.Requirements){
    $stacks.Python.Present=$true
    $text=Get-SafeContent $req
    if($text){
      foreach($ln in ($text -split "`n")){
        $l=($ln.Split('#')[0]).Trim(); if(-not $l){continue}
        $name=($l -split '==|>=|<=|~=|>|<')[0].Trim(); if($name){ $stacks.Python.Dependencies[$name]=$true }
      }
    }
  }
  foreach($cs in $Inventory.DotNet.CsProj){
    $xml=Invoke-Safely -Context "Parse csproj $cs" -Script { [xml](Get-SafeContent $cs) }
    if($xml){
      $stacks.DotNet.Present=$true
      if($xml.Project.ItemGroup.PackageReference){
        foreach($pr in $xml.Project.ItemGroup.PackageReference){ $stacks.DotNet.Packages[$pr.Include]=$pr.Version }
      }
    }
  }
  $stacks
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
}

function Check-NodeRuntime{
  $r=[ordered]@{ NodeFound=$false; NodeVersion=$null; NpmFound=$false; NpmVersion=$null }
  $node=Get-Command node -ErrorAction SilentlyContinue
  if($node){ $r.NodeFound=$true; try{ $r.NodeVersion=(node -v) 2>$null }catch{} }
  $npm=Get-Command npm -ErrorAction SilentlyContinue
  if($npm){ $r.NpmFound=$true; try{ $r.NpmVersion=(npm -v) 2>$null }catch{} }
  $r
}
function Check-PythonRuntime{
  $r=[ordered]@{ PythonFound=$false; PythonVersion=$null; PipFound=$false; PipVersion=$null }
  $py=Get-Command python -ErrorAction SilentlyContinue; if(-not $py){ $py=Get-Command py -ErrorAction SilentlyContinue }
  if($py){ $r.PythonFound=$true; try{ $r.PythonVersion=(& $py.Path --version) 2>&1 }catch{} }
  $pip=Get-Command pip -ErrorAction SilentlyContinue
  if($pip){ $r.PipFound=$true; try{ $r.PipVersion=(& $pip.Path -V) 2>&1 }catch{} }
  elseif($py){ try{ $r.PipFound=$true; $r.PipVersion=(& $py.Path -m pip -V) 2>&1 }catch{} }
  $r
}

function Check-NodePackages{
  param($Inventory,[switch]$RunNpmList)
  $pk=[ordered]@{ Deps=@{}; Missing=@(); NodeModulesExists=$false; NpmListOutput=$null }
  $pkgJson=$Inventory.Node.PackageJson | Select-Object -First 1
  if(-not $pkgJson){ return $pk }
  $dir=Split-Path -Parent $pkgJson
  $nm =Join-Path $dir 'node_modules'
  $pk.NodeModulesExists=Test-Path $nm -PathType Container
  $json=ConvertFrom-JsonSafe -Text (Get-SafeContent $pkgJson) -Ctx $pkgJson
  if($json){
    foreach($sec in 'dependencies','devDependencies','optionalDependencies'){
      $prop=$json.PSObject.Properties[$sec]
      if($prop -and $null -ne $prop.Value){
        foreach($kv in $prop.Value.PSObject.Properties){
          $name=$kv.Name; $pk.Deps[$name]=$kv.Value
          if($pk.NodeModulesExists -and -not (Test-Path (Join-Path $nm $name))){ $pk.Missing+=$name }
        }
      }
    }
  }
  if($RunNpmList -and (Get-Command npm -ErrorAction SilentlyContinue)){
    try{ Push-Location $dir; $pk.NpmListOutput=(npm ls --depth=0 2>&1 | Out-String) }finally{ Pop-Location }
  }
  $pk
}

function Check-PythonPackages{
  param($Inventory)
  $pk=[ordered]@{ Deps=@(); Missing=@() }
  $req=$Inventory.Python.Requirements | Select-Object -First 1
  if(-not $req){ return $pk }
  $t=Get-SafeContent $req
  if($t){ foreach($ln in ($t -split "`n")){ $l=($ln.Split('#')[0]).Trim(); if($l){ $n=($l -split '==|>=|<=|~=|>|<')[0].Trim(); if($n){ $pk.Deps+=$n } } } }
  if($pk.Deps.Count -gt 0 -and (Get-Command pip -ErrorAction SilentlyContinue)){
    foreach($n in $pk.Deps){ try{ $null=pip show $n 2>$null; if($LASTEXITCODE -ne 0){ $pk.Missing+=$n } }catch{ $pk.Missing+=$n } }
  }
  $pk
}

function Test-TcpConnectivity{ param([string]$TargetHost,[int]$Port)
  try{ $ok=Test-NetConnection -ComputerName $TargetHost -Port $Port -WarningAction SilentlyContinue -InformationLevel Quiet; @{ Host=$TargetHost; Port=$Port; Reachable=[bool]$ok } }
  catch{ @{ Host=$TargetHost; Port=$Port; Reachable=$false; Error=$_.Exception.Message } }
}

function Analyze-Twitch{ param($Configs,$Stacks)
  $res=[ordered]@{ Present=$false; Issues=@(); Details=@{} }
  $vals=@{}; foreach($k in $Configs.Twitch.Values.Keys){ $vals[$k]=$Configs.Twitch.Values[$k] }
  $keys='TWITCH_CLIENT_ID','TWITCH_CLIENT_SECRET','TWITCH_BOT_USERNAME','TWITCH_OAUTH','TWITCH_OAUTH_TOKEN','password','oauth','token','username','channels'
  $found=@{}; foreach($k in $keys){ if($vals.ContainsKey($k)){ $found[$k]=$vals[$k] } }
  if($found.Count -gt 0){ $res.Present=$true }
  if($found.ContainsKey('TWITCH_OAUTH_TOKEN') -or $found.ContainsKey('TWITCH_OAUTH') -or $found.ContainsKey('oauth')){
    $pw=$found['TWITCH_OAUTH_TOKEN']; if(-not $pw){ $pw=$found['TWITCH_OAUTH']; if(-not $pw){ $pw=$found['oauth'] } }
    if($pw -and -not ($pw -like 'oauth:*')){ $res.Issues+='Twitch IRC OAuth should start with "oauth:".' }
  }
  $res.Details.Values=@{}; foreach($kv in $found.GetEnumerator()){ $res.Details.Values[$kv.Key]=Mask-Secret $kv.Value }
  $res.Details.Connectivity=[ordered]@{}
  $res.Details.Connectivity.Tcp_irc_chat_twitch_tv_6697=Test-TcpConnectivity -TargetHost 'irc.chat.twitch.tv' -Port 6697
  $res.Details.Connectivity.Tcp_irc_chat_twitch_tv_6667=Test-TcpConnectivity -TargetHost 'irc.chat.twitch.tv' -Port 6667
  $res
}

function Analyze-Discord{ param($Configs,$Stacks)
  $res=[ordered]@{ Present=$false; Issues=@(); Details=@{} }
  $vals=@{}; foreach($k in $Configs.Discord.Values.Keys){ $vals[$k]=$Configs.Discord.Values[$k] }
  $keys='DISCORD_TOKEN','DISCORD_BOT_TOKEN','token','DISCORD_CLIENT_ID','clientId','client_id','DISCORD_GUILD_ID','guildId'
  $found=@{}; foreach($k in $keys){ if($vals.ContainsKey($k)){ $found[$k]=$vals[$k] } }
  if($found.Count -gt 0){ $res.Present=$true }
  $tok=if($found['DISCORD_BOT_TOKEN']){ $found['DISCORD_BOT_TOKEN'] } elseif($found['DISCORD_TOKEN']){ $found['DISCORD_TOKEN'] } else { $found['token'] }
  if($tok -and ($tok -match '\s')){ $res.Issues+='Discord token contains whitespace (quotes/line breaks?)' }
  $res.Details.Values=@{}; foreach($kv in $found.GetEnumerator()){ $res.Details.Values[$kv.Key]=Mask-Secret $kv.Value }
  $res.Details.Connectivity=[ordered]@{}
  $res.Details.Connectivity.Tcp_discord_com_443=Test-TcpConnectivity -TargetHost 'discord.com' -Port 443
  $res
}

function Analyze-OBS{ param($Configs,$Stacks)
  $res=[ordered]@{ Present=$false; Issues=@(); Details=@{} }
  $vals=@{}; foreach($k in $Configs.OBS.Values.Keys){ $vals[$k]=$Configs.OBS.Values[$k] }
  $keys='OBS_HOST','host','OBS_PORT','port','OBS_PASSWORD','password','OBS_WS_URL','url','OBS_WEBSOCKET_PORT'
  $found=@{}; foreach($k in $keys){ if($vals.ContainsKey($k)){ $found[$k]=$vals[$k] } }
  if($found.Count -gt 0){ $res.Present=$true }
  $ObsHost=if($found['OBS_HOST']){ $found['OBS_HOST'] } elseif($found['host']){ $found['host'] } else { '127.0.0.1' }
  $port=if($found['OBS_WEBSOCKET_PORT']){ [int]$found['OBS_WEBSOCKET_PORT'] } elseif($found['OBS_PORT']){ [int]$found['OBS_PORT'] } elseif($found['port']){ [int]$found['port'] } else { 4455 }
  $res.Details.Values=@{ host=$ObsHost; port=$port; password= if($found['OBS_PASSWORD']){ Mask-Secret $found['OBS_PASSWORD'] } elseif($found['password']){ Mask-Secret $found['password'] } else { $null } }
  $res.Details.Connectivity=[ordered]@{}
  $res.Details.Connectivity.("Tcp_{0}_{1}" -f $ObsHost,$port)=Test-TcpConnectivity -TargetHost $ObsHost -Port $port
  if($port -ne 4444){ $res.Details.Connectivity.("Tcp_{0}_4444" -f $ObsHost)=Test-TcpConnectivity -TargetHost $ObsHost -Port 4444 }
  $res
}

function Analyze-StreamElements{ param($Configs,$Stacks)
  $res=[ordered]@{ Present=$false; Issues=@(); Details=@{} }
  $vals=@{}; foreach($k in $Configs.StreamElements.Values.Keys){ $vals[$k]=$Configs.StreamElements.Values[$k] }
  $keys='SE_JWT','STREAMELEMENTS_JWT','jwt','channel','STREAMELEMENTS_CHANNEL','SE_CHANNEL','SE_CHANNEL_ID'
  $found=@{}; foreach($k in $keys){ if($vals.ContainsKey($k)){ $found[$k]=$vals[$k] } }
  if($found.Count -gt 0){ $res.Present=$true }
  $res.Details.Values=@{}; foreach($kv in $found.GetEnumerator()){ $res.Details.Values[$kv.Key]=Mask-Secret $kv.Value }
  $res.Details.Connectivity=[ordered]@{}
  $res.Details.Connectivity.Tcp_api_streamelements_com_443=Test-TcpConnectivity -TargetHost 'api.streamelements.com' -Port 443
  $res
}

function Analyze-Commands{ param($Inventory,$Stacks)
  $res=[ordered]@{ Count=0; ByLang=@{ Node=@(); Python=@(); DotNet=@() }; Notes=@() }
  foreach($p in $Inventory.Commands){ $ext=[IO.Path]::GetExtension($p).ToLowerInvariant(); switch($ext){ '.js'{$res.ByLang.Node+=$p};'.ts'{$res.ByLang.Node+=$p};'.py'{$res.ByLang.Python+=$p};'.cs'{$res.ByLang.DotNet+=$p} } }
  $res.Count=$Inventory.Commands.Count
  foreach($f in $res.ByLang.Node){ $t=Get-SafeContent $f; if($t -and ($t -notmatch '(?i)(registerCommand|new\s+SlashCommandBuilder|module\.exports|export\s+default)')){ $res.Notes+="Node command export/registration not detected: $f" } }
  foreach($f in $res.ByLang.Python){ $t=Get-SafeContent $f; if($t -and ($t -notmatch '(?i)@bot\.command|@commands\.command|class\s+.*\(commands\.Cog\)')){ $res.Notes+="Python command/cog patterns not detected: $f" } }
  $res
}

function New-Report{
  param($Inventory,$Stacks,$Configs,$NodeRT,$PyRT,$NodePkgs,$PyPkgs,$Twitch,$Discord,$OBS,$SE)
  $summary=[ordered]@{
    Timestamp=(Get-Date).ToString('u'); RootPath=$RootPath; PowerShell=$PSVersionTable.PSVersion.ToString()
    OS=$null; Node=$NodeRT; Python=$PyRT; Stacks=$Stacks
    Services=[ordered]@{ Twitch=$Twitch; Discord=$Discord; OBS=$OBS; StreamElements=$SE }
    InventorySummary=[ordered]@{
      Files=$Inventory.All.Count; Env=$Inventory.EnvFiles.Count; JSON=$Inventory.JsonFiles.Count; YAML=$Inventory.YamlFiles.Count
      Node=$Inventory.Node.PackageJson.Count; PythonReq=$Inventory.Python.Requirements.Count; CsProj=$Inventory.DotNet.CsProj.Count; Commands=$Inventory.Commands.Count
    }
    NodePackages=$NodePkgs; PythonPackages=$PyPkgs
  }
  try{ $summary.OS=(Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty Caption) }catch{ $summary.OS=$env:OS }
  $jsonPath=Join-Path $Paths.Reports 'diagnostics.json'
  ($summary | ConvertTo-Json -Depth 8) | Out-File -FilePath $jsonPath -Encoding utf8
  $md=New-Object 'System.Collections.Generic.List[string]'
  $md.Add('# Stream Stack Diagnostics')
  $md.Add("- Timestamp: $($summary.Timestamp)")
  $md.Add("- Root: `$RootPath = $($summary.RootPath)")
  $md.Add("- PowerShell: $($summary.PowerShell)")
  $md.Add("- OS: $($summary.OS)")
  $md.Add('')
  $md.Add('## Runtimes')
  $md.Add("- Node: Found=$($NodeRT.NodeFound) Version=$($NodeRT.NodeVersion) NPM=$($NodeRT.NpmFound)")
  $md.Add("- Python: Found=$($PyRT.PythonFound) Version=$($PyRT.PythonVersion) Pip=$($PyRT.PipFound)")
  $md.Add('')
  $md.Add('## Detected Stacks'); $md.Add('```json'); $md.Add(($Stacks | ConvertTo-Json -Depth 6)); $md.Add('```'); $md.Add('')
  $md.Add('## Inventory Summary'); $md.Add('```json'); $md.Add(($summary.InventorySummary | ConvertTo-Json)); $md.Add('```'); $md.Add('')
  $md.Add('## Services')
  foreach($svcName in 'Twitch','Discord','OBS','StreamElements'){ $md.Add("### $svcName"); $svc=$summary.Services.$svcName; $md.Add('```json'); $md.Add(($svc | ConvertTo-Json -Depth 8)); $md.Add('```') }
  $md.Add(''); $md.Add('## Node Packages'); $md.Add('```json'); $md.Add(($NodePkgs | ConvertTo-Json -Depth 6)); $md.Add('```')
  $md.Add(''); $md.Add('## Python Packages'); $md.Add('```json'); $md.Add(($PyPkgs | ConvertTo-Json -Depth 6)); $md.Add('```')
  $mdPath=Join-Path $Paths.Reports 'diagnostics.md'
  ($md -join "`n") | Out-File -FilePath $mdPath -Encoding utf8
  Write-Log INFO "Report written: $jsonPath"
  Write-Log INFO "Report written: $mdPath"
  @{ Json=$jsonPath; Markdown=$mdPath }
}

# --- MAIN ---
$sw=[System.Diagnostics.Stopwatch]::StartNew()
Write-Log INFO '=== Stream Stack Diagnostics START ==='
Write-Log VERBOSE ("Parameters: RootPath={0}, OutputPath={1}, OnlineValidation={2}, CheckDependencies={3}, MaxFileKB={4}" -f $RootPath,$OutputPath,$OnlineValidation,$CheckDependencies,$MaxFileKB)

$Inventory=Get-FileInventory -Root $RootPath
$Stacks   =Detect-TechStacks -Inventory $Inventory
$Configs  =Find-Configs -Inventory $Inventory

$NodeRT=Check-NodeRuntime
$PyRT  =Check-PythonRuntime

$NodePkgs=Check-NodePackages -Inventory $Inventory -RunNpmList:$CheckDependencies
$PyPkgs  =Check-PythonPackages -Inventory $Inventory

$Twitch =Analyze-Twitch -Configs $Configs -Stacks $Stacks
$Discord=Analyze-Discord -Configs $Configs -Stacks $Stacks
$OBS    =Analyze-OBS -Configs $Configs -Stacks $Stacks
$SE     =Analyze-StreamElements -Configs $Configs -Stacks $Stacks

$reports=New-Report -Inventory $Inventory -Stacks $Stacks -Configs $Configs -NodeRT $NodeRT -PyRT $PyRT -NodePkgs $NodePkgs -PyPkgs $PyPkgs -Twitch $Twitch -Discord $Discord -OBS $OBS -SE $SE

$sw.Stop()
Write-Log INFO ("Elapsed: "+$sw.Elapsed.ToString())
Write-Log INFO '=== Stream Stack Diagnostics END ==='
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host ("1) Open: {0}" -f $reports.Markdown) -ForegroundColor Cyan
Write-Host "2) Paste diagnostics.md here for targeted fixes." -ForegroundColor Cyan




