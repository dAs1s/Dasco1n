<#[
  repair-stream-stack.ps1 (alias-aware)
  - Ensures required keys exist (no overwrites if alias present)
  - Installs node deps using npm via cmd.exe (streams output)
  - Smoke tests: Discord REST, Twitch IRC, OBS TCP, StreamElements (optional REST)
]#>
[CmdletBinding()]
param(
  [ValidateScript({ Test-Path $_ -PathType Container })][string]$RootPath='C:\Dasco1n',
  [switch]$InstallNodeDeps,
  [switch]$RunSmokeTests,
  [switch]$OnlineValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

function Write-Log { param([string]$Level='INFO',[string]$Message)
  $p=("[{0}] [{1}] {2}" -f (Get-Date -Format 'u'),$Level,$Message)
  switch($Level){'INFO'{Write-Host $p};'WARN'{Write-Warning $Message};'ERROR'{Write-Error $Message};'DEBUG'{Write-Verbose $Message -Verbose}}
}

function Parse-Env([string]$Path){ $kv=@{}; if(-not (Test-Path -LiteralPath $Path)){return $kv}; (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -EA SilentlyContinue) -split "`n" | ForEach-Object { $l=$_.Trim(); if(-not $l -or $l.StartsWith('#')){return}; $i=$l.IndexOf('='); if($i -lt 1){return}; $k=$l.Substring(0,$i).Trim(); $v=$l.Substring($i+1).Trim().Trim('"').Trim("'"); $kv[$k]=$v }; $kv }
function Set-EnvKV([string]$Path,[string]$Key,[string]$Value){ if(-not (Test-Path -LiteralPath $Path)){ New-Item -ItemType File -Path $Path -Force | Out-Null }; $lines= if(Test-Path $Path){ Get-Content -LiteralPath $Path -Encoding UTF8 } else {@()}; $pat=('^{0}\s*=' -f [regex]::Escape($Key)); $newline="$Key=$Value"; $upd=$false; for($i=0;$i -lt $lines.Count;$i++){ if($lines[$i] -match $pat){ $lines[$i]=$newline; $upd=$true } }; if(-not $upd){ $lines+=$newline }; Set-Content -LiteralPath $Path -Encoding UTF8 -Value ($lines -join [Environment]::NewLine) }
function Mask([string]$v){ if([string]::IsNullOrWhiteSpace($v)){return ''}; $v=$v.Trim(); if($v.Length -le 5){return ('*'*$v.Length)}; $v.Substring(0,3)+('*'*(($v.Length)-5))+$v.Substring($v.Length-2) }

function Resolve-Canon($env){
  [ordered]@{
    Twitch = [ordered]@{
      username = @($env['TWITCH_BOT_USERNAME'],$env['TMI_USERNAME'],$env['TWITCH_USERNAME']) | Where-Object { $_ } | Select-Object -First 1
      oauth    = @($env['TWITCH_OAUTH'],$env['TWITCH_OAUTH_TOKEN'],$env['TMI_PASSWORD']) | Where-Object { $_ } | Select-Object -First 1
      channels = @($env['TWITCH_CHANNELS']) | Where-Object { $_ } | Select-Object -First 1
    }
    Discord = [ordered]@{
      token    = @($env['DISCORD_BOT_TOKEN'],$env['DISCORD_TOKEN']) | Where-Object { $_ } | Select-Object -First 1
      clientId = $env['DISCORD_CLIENT_ID']
      guildId  = $env['DISCORD_GUILD_ID']
    }
    OBS = [ordered]@{
      host = @($env['OBS_HOST'],'127.0.0.1') | Where-Object { $_ } | Select-Object -First 1
      port = @($env['OBS_WEBSOCKET_PORT'],'4455') | Where-Object { $_ } | Select-Object -First 1
      password = $env['OBS_PASSWORD']
    }
    SE = [ordered]@{
      jwt = @($env['SE_JWT'],$env['STREAMELEMENTS_JWT']) | Where-Object { $_ } | Select-Object -First 1
      channel = @($env['SE_CHANNEL_ID'],$env['STREAMELEMENTS_CHANNEL']) | Where-Object { $_ } | Select-Object -First 1
    }
  }
}

function Ensure-KeysSmart([string]$envPath){
  $envMap = Parse-Env $envPath
  $canon  = Resolve-Canon $envMap
  $sets = @(
    @{ Any=@('TWITCH_OAUTH','TWITCH_OAUTH_TOKEN','TMI_PASSWORD');   Prefer='TWITCH_OAUTH_TOKEN' }
    @{ Any=@('DISCORD_BOT_TOKEN','DISCORD_TOKEN');                  Prefer='DISCORD_BOT_TOKEN' }
    @{ Any=@('OBS_HOST');                                          Prefer='OBS_HOST' }
    @{ Any=@('OBS_WEBSOCKET_PORT');                                Prefer='OBS_WEBSOCKET_PORT' }
    @{ Any=@('SE_JWT','STREAMELEMENTS_JWT');                        Prefer='SE_JWT' }
    @{ Any=@('TWITCH_BOT_USERNAME');                                Prefer='TWITCH_BOT_USERNAME' }
  )
  foreach($s in $sets){ $have = $false; foreach($k in $s.Any){ if($envMap.ContainsKey($k) -and $envMap[$k]){ $have=$true; break } }; if(-not $have){ Set-EnvKV -Path $envPath -Key $s.Prefer -Value '' ; Write-Log WARN ("Placeholder added: {0}" -f $s.Prefer) } }
}

function Find-PackageJson([string]$Root){ Get-ChildItem -LiteralPath $Root -Recurse -File -Filter package.json -EA SilentlyContinue | Where-Object { $_.FullName -notmatch '\\node_modules\\' } | Select-Object -ExpandProperty FullName }
function Install-NodePackages([string]$Root){ $pkgs=Find-PackageJson $Root; if(-not $pkgs){ Write-Log WARN "No package.json found"; return }; foreach($pkg in $pkgs){ $dir=Split-Path -Parent $pkg; $lock=Join-Path $dir 'package-lock.json'; $cmd= if(Test-Path $lock){'ci'} else {'install'}; Write-Log INFO ("[{0}] npm {1} ..." -f $dir,$cmd); Push-Location $dir; try{ & $env:ComSpec /d /c "npm $cmd --loglevel warn --no-audit --no-fund"; $ec=$LASTEXITCODE; if($ec -ne 0){ Write-Log WARN ("[{0}] npm {1} exit={2}; retry install" -f $dir,$cmd,$ec); & $env:ComSpec /d /c "npm install --loglevel warn --no-audit --no-fund"; $ec=$LASTEXITCODE }; if($ec -eq 0){ Write-Log INFO ("[{0}] npm OK" -f $dir) } else { Write-Log ERROR ("[{0}] npm failed exit={1}" -f $dir,$ec) } } finally { Pop-Location } } }

function Try-Net([string]$Host,[int]$Port){ try{ [bool](Test-NetConnection -ComputerName $Host -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue) } catch{ $false } }
function Test-DiscordLoginRest([string]$Token){ if([string]::IsNullOrWhiteSpace($Token)){ Write-Log WARN 'Discord: token missing; skip'; return }; try{ $r=Invoke-RestMethod -Method Get -Uri 'https://discord.com/api/v10/users/@me' -Headers @{Authorization = "Bot $Token"}; if($r -and $r.id){ Write-Log INFO ("Discord: token OK -> {0}#{1} (id={2})" -f $r.username,$r.discriminator,$r.id) } else { Write-Log WARN 'Discord: unexpected /users/@me' } } catch { Write-Log WARN ("Discord: token check failed: {0}" -f $_.Exception.Message) } }
function Test-TwitchIrc([string]$User,[string]$OAuth){ if([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($OAuth)){ Write-Log WARN 'Twitch: username or oauth missing; skip'; return }; if($OAuth -notmatch '^oauth:'){ Write-Log WARN ("Twitch: oauth must start with 'oauth:' (masked {0})" -f (Mask $OAuth)); return }; if(-not (Try-Net 'irc.chat.twitch.tv' 6697)){ Write-Log WARN 'Twitch: irc.chat.twitch.tv:6697 not reachable'; return }; try{ $c=New-Object Net.Sockets.TcpClient; $ar=$c.BeginConnect('irc.chat.twitch.tv',6697,$null,$null); if(-not $ar.AsyncWaitHandle.WaitOne(7000)){ throw 'Connect timeout' }; $c.EndConnect($ar); $ns=$c.GetStream(); $ssl=New-Object Net.Security.SslStream($ns,$false,({$true})); $ssl.AuthenticateAsClient('irc.chat.twitch.tv'); $sr=New-Object IO.StreamReader($ssl); $sw=New-Object IO.StreamWriter($ssl); $sw.NewLine="`r`n"; $sw.AutoFlush=$true; $sw.WriteLine("PASS $OAuth"); $sw.WriteLine("NICK $User"); $deadline=(Get-Date).AddSeconds(10); $ok=$false; while((Get-Date)-lt $deadline -and $ssl.CanRead){ Start-Sleep -Milliseconds 200; if($ns.DataAvailable){ $line=$sr.ReadLine(); if($line -and ($line -match ' 001 ' -or $line -match '(?i)Welcome' -or $line -match 'GLOBALUSERSTATE')){ $ok=$true; break } } }; if($ok){ Write-Log INFO ("Twitch: IRC login OK as {0}" -f $User) } else { Write-Log WARN 'Twitch: IRC login not confirmed' } } catch { Write-Log WARN ("Twitch: IRC check failed: {0}" -f $_.Exception.Message) } finally { try{$sr.Dispose()}catch{}; try{$sw.Dispose()}catch{}; try{$ssl.Dispose()}catch{}; try{$c.Close()}catch{} } }
function Test-OBS([string]$Host,[int]$Port){ if(Try-Net $Host $Port){ Write-Log INFO ("OBS: TCP reachable {0}:{1}" -f $Host,$Port) } else { Write-Log WARN ("OBS: NOT reachable at {0}:{1}. In OBS: enable WebSocket (port 4455), set password." -f $Host,$Port) } }
function Test-SE([string]$Jwt,[switch]$Online){ if([string]::IsNullOrWhiteSpace($Jwt)){ Write-Log WARN 'SE: SE_JWT missing; skip'; return }; if(-not $Online){ Write-Log INFO ("SE: JWT present (masked {0})" -f (Mask $Jwt)); return }; try{ $r=Invoke-RestMethod -Method Get -Uri 'https://api.streamelements.com/kappa/v2/users/me' -Headers @{Authorization="Bearer $Jwt"}; if($r -and $r._id){ Write-Log INFO ("SE: JWT OK for {0}" -f $r.username) } else { Write-Log WARN 'SE: unexpected response' } } catch { Write-Log WARN ("SE: check failed: {0}" -f $_.Exception.Message) } }

# ---- MAIN ----
Write-Log INFO '=== REPAIR / SMOKETEST START ==='
$envPath = Join-Path $RootPath '.env'
Ensure-KeysSmart $envPath
$envMap = Parse-Env $envPath
$canon  = Resolve-Canon $envMap

if($InstallNodeDeps){ Install-NodePackages $RootPath }

if($RunSmokeTests){
  Test-DiscordLoginRest $canon.Discord.token
  Test-TwitchIrc $canon.Twitch.username $canon.Twitch.oauth
  Test-OBS $canon.OBS.host ([int]$canon.OBS.port)
  Test-SE $canon.SE.jwt -Online:$OnlineValidation
}

Write-Log INFO '=== REPAIR / SMOKETEST END ==='
