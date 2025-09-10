# C:\Dasco1n\tools\stream-ops.ps1  (PS 5.1-safe)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
  param([string]$Level='INFO',[string]$Message)
  $p = ("[{0}] [{1}] {2}" -f (Get-Date -Format 'u'), $Level, $Message)
  switch ($Level) {
    'INFO'  { Write-Host $p }
    'WARN'  { Write-Warning $Message }
    'ERROR' { Write-Error $Message }
    'DEBUG' { Write-Verbose $Message -Verbose }
    default { Write-Host $p }
  }
}

function Get-StreamPaths {
  param([string]$RootPath='C:\Dasco1n')
  [ordered]@{
    Root     = $RootPath
    Diagnose = (Join-Path $RootPath 'diagnose-stream-stack.ps1')
    Repair   = (Join-Path $RootPath 'repair-stream-stack.ps1')
    DiagBase = (Join-Path $RootPath '_diagnostics')
  }
}

function Get-LatestDiagnostics {
  param([string]$DiagBase)
  if (-not (Test-Path -LiteralPath $DiagBase)) { return [ordered]@{ Report=$null; Log=$null } }
  $md  = Get-ChildItem -Path $DiagBase -Recurse -File -Filter 'diagnostics.md'  -EA SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 1
  $log = Get-ChildItem -Path $DiagBase -Recurse -File -Filter 'diagnostics.log' -EA SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 1
  [ordered]@{ Report=$md; Log=$log }
}

function Invoke-StreamDiagnose {
  param([string]$RootPath='C:\Dasco1n',[switch]$OnlineValidation,[switch]$CheckDependencies,[switch]$OpenReport,[switch]$TailLog)
  $p = Get-StreamPaths -RootPath $RootPath
  if (-not (Test-Path -LiteralPath $p.Diagnose)) { throw "Missing: $($p.Diagnose)" }
  Write-Log INFO ("Running diagnostics for {0} (OnlineValidation={1}, CheckDependencies={2})" -f $RootPath,$OnlineValidation,$CheckDependencies)
  & $p.Diagnose -RootPath $RootPath -OnlineValidation:$OnlineValidation -CheckDependencies:$CheckDependencies -Verbose
  $latest = Get-LatestDiagnostics -DiagBase $p.DiagBase
  if ($OpenReport -and $latest.Report) { Write-Log INFO ("Opening {0}" -f $latest.Report.FullName); Invoke-Item -LiteralPath $latest.Report.FullName }
  elseif ($TailLog -and $latest.Log)   { Write-Log INFO ("Tailing {0}"  -f $latest.Log.FullName);  Get-Content -LiteralPath $latest.Log.FullName -Tail 120 }
}

function Invoke-StreamRepair {
  param([string]$RootPath='C:\Dasco1n',[switch]$InstallNodeDeps,[switch]$RunSmokeTests,[switch]$OnlineValidation)
  $p = Get-StreamPaths -RootPath $RootPath
  if (-not (Test-Path -LiteralPath $p.Repair)) { throw "Missing: $($p.Repair)" }
  Write-Log INFO ("Running repair/smoke for {0} (InstallNodeDeps={1}, RunSmokeTests={2}, OnlineValidation={3})" -f $RootPath,$InstallNodeDeps,$RunSmokeTests,$OnlineValidation)
  & $p.Repair -RootPath $RootPath -InstallNodeDeps:$InstallNodeDeps -RunSmokeTests:$RunSmokeTests -OnlineValidation:$OnlineValidation
}

function diag { param([string]$RootPath='C:\Dasco1n',[switch]$Heavy,[switch]$Open,[switch]$Tail)
  Invoke-StreamDiagnose -RootPath $RootPath -OnlineValidation:$Heavy -CheckDependencies:$Heavy -OpenReport:$Open -TailLog:$Tail
}
function repair { param([string]$RootPath='C:\Dasco1n',[switch]$Deps,[switch]$Tests,[switch]$Online)
  Invoke-StreamRepair -RootPath $RootPath -InstallNodeDeps:$Deps -RunSmokeTests:$Tests -OnlineValidation:$Online
}
function diagrepair { param([string]$RootPath='C:\Dasco1n',[switch]$Heavy)
  diag -RootPath $RootPath -Heavy:$Heavy -Tail
  repair -RootPath $RootPath -Deps -Tests -Online:$Heavy
  diag -RootPath $RootPath -Heavy:$Heavy -Open
}

# Simple debounced watcher
$script:Watcher = $null
function Start-StreamWatch {
  param([string]$RootPath='C:\Dasco1n',[string]$OnChange='diag')  # 'diag' or 'diagrepair'
  if ($script:Watcher) { Write-Log WARN 'Watcher already running. Use Stop-StreamWatch first.'; return }
  if ($OnChange -notin @('diag','diagrepair')) { throw "OnChange must be 'diag' or 'diagrepair'" }
  $fsw = New-Object IO.FileSystemWatcher -Property @{ Path=$RootPath; IncludeSubdirectories=$true; Filter='*.*' }
  $fsw.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite, Size'
  $fsw.EnableRaisingEvents = $true
  $script:Watcher = [pscustomobject]@{ FSW=$fsw; Mode=$OnChange; Root=$RootPath; LastRun=(Get-Date).AddMinutes(-10); Reg=@() }
  $action = {
    if (((Get-Date) - $script:Watcher.LastRun).TotalSeconds -lt 5) { return }
    $script:Watcher.LastRun = Get-Date
    try {
      Write-Log INFO ("Change detected -> running {0}" -f $script:Watcher.Mode)
      if ($script:Watcher.Mode -eq 'diagrepair') { diag -RootPath $script:Watcher.Root -Tail; repair -RootPath $script:Watcher.Root -Deps -Tests; diag -RootPath $script:Watcher.Root -Open }
      else { diag -RootPath $script:Watcher.Root -Tail }
    } catch { Write-Log ERROR ("Watcher action failed: {0}" -f $_.Exception.Message) }
  }
  $script:Watcher.Reg += Register-ObjectEvent -InputObject $fsw -EventName Changed -Action $action
  $script:Watcher.Reg += Register-ObjectEvent -InputObject $fsw -EventName Created -Action $action
  $script:Watcher.Reg += Register-ObjectEvent -InputObject $fsw -EventName Deleted -Action $action
  Write-Log INFO ("Watcher started for {0}" -f $RootPath)
}
function Stop-StreamWatch {
  if ($script:Watcher) {
    $script:Watcher.Reg | Unregister-Event -ErrorAction SilentlyContinue
    try { $script:Watcher.FSW.EnableRaisingEvents=$false; $script:Watcher.FSW.Dispose() } catch {}
    $script:Watcher = $null
    Write-Log INFO 'Watcher stopped.'
  } else { Write-Log WARN 'No watcher running.' }
}

function Install-StreamOpsProfile {
  $profilePath = $PROFILE
  $dir = Split-Path -Parent $profilePath
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (-not (Test-Path -LiteralPath $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }
  $import = ". 'C:\Dasco1n\tools\stream-ops.ps1'"
  $cur = Get-Content -LiteralPath $profilePath -Raw -EA SilentlyContinue
  if ($cur -notlike '*stream-ops.ps1*') { Add-Content -LiteralPath $profilePath -Value $import; Write-Log INFO ("Profile updated -> {0}" -f $profilePath) }
  else { Write-Log INFO 'Profile already imports stream-ops.ps1' }
}
