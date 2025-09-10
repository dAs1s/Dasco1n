# File: scripts/Analyze-Project.ps1
# Version: 1.3 (ASCII-only; Windows PowerShell 5.1 safe)
# Notes: No nested functions or inline if-expressions. Designed for large trees with progress and Fast/Deep modes.
# Usage (first run):
#   powershell -NoProfile -ExecutionPolicy Bypass -File C:\Dasco1n\scripts\Analyze-Project.ps1 -Path 'C:\dasco1n' -Fast
# Deep run:
#   powershell -NoProfile -ExecutionPolicy Bypass -File C:\Dasco1n\scripts\Analyze-Project.ps1 -Path 'C:\dasco1n' -Deep

[CmdletBinding()] param(
  [Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()] [string]$Path,
  [string]$OutDir,
  [string]$BundleName = 'project_analysis_bundle',
  [int]$MaxFileSizeMB = 5,
  [int]$SecretsMaxFileSizeMB = 1,
  [int]$MaxFiles = 0,
  [switch]$Fast,
  [switch]$Deep,
  [switch]$NoGit
)

begin {
  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'
  $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

  function New-DirectorySafe([string]$Dir) {
    if (-not [string]::IsNullOrWhiteSpace($Dir)) {
      if (-not (Test-Path -LiteralPath $Dir)) { New-Item -ItemType Directory -Path $Dir | Out-Null }
    }
    return (Resolve-Path -LiteralPath $Dir).Path
  }

  function Get-Timestamp() { (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss') }
  function Info($m){ Write-Host ('[INFO ] {0}' -f $m) -ForegroundColor Cyan }
  function Warn($m){ Write-Host ('[WARN ] {0}' -f $m) -ForegroundColor Yellow }
  function Err ($m){ Write-Host ('[ERROR] {0}' -f $m) -ForegroundColor Red }

  $root = (Resolve-Path -LiteralPath $Path).Path
  if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw ('Not a directory: {0}' -f $root) }

  if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $base = Join-Path $root '.analysis'
    $run  = 'run_' + (Get-Timestamp)
    $OutDir = Join-Path (New-DirectorySafe $base) $run
  }
  $OutDir = New-DirectorySafe $OutDir

  $reportsDir   = New-DirectorySafe (Join-Path $OutDir 'reports')
  $artifactsDir = New-DirectorySafe (Join-Path $OutDir 'artifacts')
  $depsDir      = New-DirectorySafe (Join-Path $reportsDir 'dependencies')
  $docsDir      = New-DirectorySafe (Join-Path $reportsDir 'docs')
  $bundleZip    = Join-Path $OutDir ($BundleName + '.zip')

  Info ('Root:   ' + $root)
  Info ('OutDir: ' + $OutDir)
  Info ('Bundle: ' + $bundleZip)

  $ExcludeDirs = @(
    '.git','node_modules','bower_components','dist','build','out','target','bin','obj','coverage','logs','.idea','.vscode',
    '.venv','venv','.tox','.pytest_cache','.mypy_cache','.cache','.gradle','.nuget','vendor','packages','Pods','__pycache__'
  )
  $ExcludeFileGlobs = @('*.min.*','*.lock','*.log','*.png','*.jpg','*.jpeg','*.gif','*.bmp','*.ico','*.svg','*.pdf','*.zip','*.7z','*.tar','*.gz','*.rar','*.dll','*.exe')

  $LangMap = @{
    '.ps1'='PowerShell'; '.psm1'='PowerShell'; '.bat'='Batch'; '.cmd'='Batch'; '.sh'='Shell';
    '.py'='Python'; '.ipynb'='Jupyter'; '.rb'='Ruby'; '.go'='Go';
    '.js'='JavaScript'; '.mjs'='JavaScript'; '.cjs'='JavaScript'; '.ts'='TypeScript'; '.tsx'='TypeScript'; '.jsx'='JavaScript';
    '.java'='Java'; '.kt'='Kotlin'; '.kts'='Kotlin'; '.groovy'='Groovy';
    '.cs'='.NET/C#'; '.vb'='.NET/VB'; '.fs'='.NET/F#'; '.sln'='.NET/Solution'; '.csproj'='.NET/Project'; '.vbproj'='.NET/Project'; '.fsproj'='.NET/Project';
    '.cpp'='C++'; '.cc'='C++'; '.cxx'='C++'; '.hpp'='C++'; '.h'='C/C++'; '.c'='C';
    '.rs'='Rust'; '.toml'='TOML';
    '.php'='PHP'; '.phtml'='PHP'; '.twig'='Twig';
    '.swift'='Swift'; '.m'='Objective-C'; '.mm'='Objective-C++';
    '.r'='R'; '.jl'='Julia'; '.lua'='Lua'; '.pl'='Perl'; '.scala'='Scala'; '.hs'='Haskell'; '.dart'='Dart';
    '.html'='HTML'; '.css'='CSS'; '.scss'='SCSS'; '.less'='LESS'; '.json'='JSON'; '.yml'='YAML'; '.yaml'='YAML'; '.xml'='XML'; '.md'='Markdown'; '.rst'='reStructuredText';
    '.sql'='SQL'; '.cmake'='CMake'; 'CMakeLists.txt'='CMake'; 'Makefile'='Make'; '.mk'='Make'
  }

  $SecretPatterns = @(
    @{ Name='AWS Access Key';       Pattern='AKIA[0-9A-Z]{16}'; },
    @{ Name='GitHub Token';         Pattern='ghp_[A-Za-z0-9]{36,}'; },
    @{ Name='Private Key Block';    Pattern='-----BEGIN (RSA|EC|DSA|OPENSSH|PGP) PRIVATE KEY-----'; },
    @{ Name='Generic API/Token';    Pattern='(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*["'']?([A-Za-z0-9_\-]{12,})'; },
    @{ Name='AWS Secret heuristic'; Pattern='(?i)aws[_-]?secret.*?[:=]\s*["'']?[A-Za-z0-9\/+=]{40}'; }
  )

  function Test-IsTextFile([System.IO.FileInfo]$f) {
    try {
      $fs = [System.IO.File]::Open($f.FullName,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
      try {
        $len = [Math]::Min(4096, [int]$fs.Length)
        $buf = New-Object byte[] $len
        [void]$fs.Read($buf,0,$len)
        for ($i=0; $i -lt $len; $i++) { if ($buf[$i] -eq 0) { return $false } }
        $np = 0; foreach ($b in $buf) { if ($b -lt 9 -or ($b -gt 13 -and $b -lt 32)) { $np++ } }
        return ($np / [Math]::Max(1,$len)) -lt 0.10
      } finally { $fs.Dispose() }
    } catch { return $false }
  }

  function Get-LineCount([System.IO.FileInfo]$f) {
    try {
      $c=0; $enc = New-Object System.Text.UTF8Encoding($false,$true)
      $sr = New-Object System.IO.StreamReader($f.FullName,$enc,$true)
      try { while ($null -ne ($line=$sr.ReadLine())) { $c++ } } finally { $sr.Dispose() }
      return $c
    } catch { return $null }
  }

  function Should-Exclude([System.IO.FileSystemInfo]$item) {
    try {
      foreach ($n in $ExcludeDirs) { if ($item.PSIsContainer -and ($item.Name -ieq $n)) { return $true } }
      foreach ($g in $ExcludeFileGlobs) { if (-not $item.PSIsContainer -and ($item.Name -like $g)) { return $true } }
      return $false
    } catch { return $false }
  }

  function Get-DirectoryTree([string]$RootPath) {
    $sb = New-Object System.Text.StringBuilder
    $stack = New-Object System.Collections.Stack

    $rootLeaf = Split-Path -Leaf $RootPath
    [void]$sb.AppendLine($rootLeaf)

    $stack.Push(@{ Path=$RootPath; Prefix='' })

    while ($stack.Count -gt 0) {
      $frame = $stack.Pop()
      $dir = [string]$frame.Path
      $prefix = [string]$frame.Prefix

      $children = Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue |
                   Where-Object { -not (Should-Exclude $_) } |
                   Sort-Object @{Expression='PSIsContainer';Descending=$true}, @{Expression='Name'}

      $children = @($children)
      $cnt = $children.Count

      for ($i=0; $i -lt $cnt; $i++) {
        $child = $children[$i]
        $isLast = ($i -eq ($cnt-1))
        $branch = '+-- '
        if (-not $isLast) { $branch = '|-- ' }
        [void]$sb.AppendLine($prefix + $branch + $child.Name)
      }

      for ($j = $cnt - 1; $j -ge 0; $j--) {
        $c2 = $children[$j]
        if ($c2.PSIsContainer) {
          $isLast2 = ($j -eq ($cnt-1))
          $newPrefix2 = $prefix
          if ($isLast2) { $newPrefix2 = $prefix + '    ' } else { $newPrefix2 = $prefix + '|   ' }
          $stack.Push(@{ Path=$c2.FullName; Prefix=$newPrefix2 })
        }
      }
    }

    return $sb.ToString()
  }

  function Detect-Lang([System.IO.FileInfo]$f) {
    $ext = $f.Extension
    $k = $ext
    if ([string]::IsNullOrEmpty($ext)) { $k = $f.Name } else { $k = $ext.ToLowerInvariant() }
    if ($LangMap.ContainsKey($k)) { return $LangMap[$k] } else { return 'Other' }
  }

  function JWrite($obj,[string]$p){ ($obj | ConvertTo-Json -Depth 10) | Out-File -FilePath $p -Encoding utf8; return $p }
  function JRead ([string]$p){ try { (Get-Content -LiteralPath $p -Raw) | ConvertFrom-Json -ErrorAction Stop } catch { $null } }

  function Extract-Dependencies([string]$r){
    $out = @()
    $pkg = Join-Path $r 'package.json'
    if (Test-Path -LiteralPath $pkg){
      $pj = JRead $pkg
      if ($pj -ne $null){
        $out += [ordered]@{ manager='node'; file=(Resolve-Path $pkg).Path; dependencies=$pj.dependencies; devDependencies=$pj.devDependencies; scripts=$pj.scripts }
        Copy-Item -LiteralPath $pkg -Destination (Join-Path $depsDir 'package.json') -Force
        foreach($lock in 'package-lock.json','yarn.lock','pnpm-lock.yaml'){
          $lp = Join-Path $r $lock; if (Test-Path -LiteralPath $lp){ Copy-Item -LiteralPath $lp -Destination (Join-Path $depsDir $lock) -Force }
        }
      }
    }
    foreach($py in 'requirements.txt','requirements-dev.txt','Pipfile','Pipfile.lock','pyproject.toml','poetry.lock','setup.py','environment.yml'){
      $pp = Join-Path $r $py; if (Test-Path -LiteralPath $pp){ Copy-Item -LiteralPath $pp -Destination (Join-Path $depsDir $py) -Force; $c = Get-Content -LiteralPath $pp -Raw -ErrorAction SilentlyContinue; if($null -ne $c){ $out += @{ manager='python'; file=(Resolve-Path $pp).Path; preview=$c.Substring(0,[Math]::Min(2000,$c.Length)) } } }
    }
    $slns = Get-ChildItem -LiteralPath $r -Recurse -Filter *.sln -ErrorAction SilentlyContinue
    foreach($s in $slns){ Copy-Item $s.FullName -Destination (Join-Path $depsDir $s.Name) -Force; $raw = Get-Content $s.FullName -Raw -ErrorAction SilentlyContinue; if($null -ne $raw){ $out += @{ manager='.NET'; file=$s.FullName; preview=$raw.Substring(0,[Math]::Min(2000,$raw.Length)) } } }
    $projs = Get-ChildItem -LiteralPath $r -Recurse -Include *.csproj,*.vbproj,*.fsproj -ErrorAction SilentlyContinue
    foreach($p in $projs){ Copy-Item $p.FullName -Destination (Join-Path $depsDir $p.Name) -Force }
    $nugets = Get-ChildItem -LiteralPath $r -Recurse -Include packages.config -ErrorAction SilentlyContinue
    foreach($n in $nugets){ Copy-Item $n.FullName -Destination (Join-Path $depsDir $n.Name) -Force }
    $poms = Get-ChildItem -LiteralPath $r -Recurse -Filter pom.xml -ErrorAction SilentlyContinue
    foreach($p in $poms){ Copy-Item $p.FullName -Destination (Join-Path $depsDir $p.Name) -Force; $out += @{ manager='maven'; file=$p.FullName } }
    $gradle = Get-ChildItem -LiteralPath $r -Recurse -Include build.gradle,build.gradle.kts,settings.gradle,settings.gradle.kts,gradle.properties -ErrorAction SilentlyContinue
    foreach($g in $gradle){ Copy-Item $g.FullName -Destination (Join-Path $depsDir $g.Name) -Force; $out += @{ manager='gradle'; file=$g.FullName } }
    foreach($gm in 'go.mod','go.sum'){ $gp = Join-Path $r $gm; if(Test-Path -LiteralPath $gp){ Copy-Item $gp -Destination (Join-Path $depsDir $gm) -Force; $out += @{ manager='go'; file=(Resolve-Path $gp).Path } } }
    foreach($rf in 'Cargo.toml','Cargo.lock'){ $rp = Join-Path $r $rf; if(Test-Path -LiteralPath $rp){ Copy-Item $rp -Destination (Join-Path $depsDir $rf) -Force; $out += @{ manager='rust'; file=(Resolve-Path $rp).Path } } }
    foreach($ph in 'composer.json','composer.lock'){ $cp = Join-Path $r $ph; if(Test-Path -LiteralPath $cp){ Copy-Item $cp -Destination (Join-Path $depsDir $ph) -Force; $out += @{ manager='php'; file=(Resolve-Path $cp).Path } } }
    foreach($rb in 'Gemfile','Gemfile.lock'){ $rp = Join-Path $r $rb; if(Test-Path -LiteralPath $rp){ Copy-Item $rp -Destination (Join-Path $depsDir $rb) -Force; $out += @{ manager='ruby'; file=(Resolve-Path $rp).Path } } }
    foreach($dk in 'Dockerfile','docker-compose.yml','docker-compose.yaml'){ $dp = Join-Path $r $dk; if(Test-Path -LiteralPath $dp){ Copy-Item $dp -Destination (Join-Path $depsDir $dk) -Force; $out += @{ manager='container'; file=(Resolve-Path $dp).Path } } }
    $ciPattern = '\.github\\workflows|\.gitlab-ci|azure-pipelines|\.circleci|\.drone'
    $ciFiles = Get-ChildItem -LiteralPath $r -Recurse -Include *.yml,*.yaml -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match $ciPattern }
    foreach($ci in $ciFiles){ Copy-Item $ci.FullName -Destination (Join-Path $depsDir $ci.Name) -Force }

    JWrite $out (Join-Path $depsDir 'dependencies.summary.json') | Out-Null
  }

  function Probe-Git([string]$r){
    $gd = Join-Path $r '.git'; if (-not (Test-Path -LiteralPath $gd)) { return $null }
    $res = [ordered]@{}
    try {
      $git = 'git'
      $isRepo = & $git rev-parse --is-inside-work-tree 2>$null
      if ($LASTEXITCODE -ne 0) { return $null }
      $res.isRepo = $true
      $res.root   = (& $git rev-parse --show-toplevel).Trim()
      $res.branch = (& $git rev-parse --abbrev-ref HEAD).Trim()
      $res.remotes= ((& $git remote -v) -join "`n")
      $res.status = ((& $git status --porcelain=v1 -b) -join "`n")
      $res.recent = ((& $git log --date=iso --pretty=format:'%h`t%an`t%ad`t%s' -n 25) -join "`n")
    } catch {}
    return $res
  }

  function Scan-Secrets([System.IO.FileInfo[]]$files,[int]$maxBytes){
    $find = New-Object System.Collections.Generic.List[object]
    foreach($f in $files){
      try {
        if ($f.Length -gt $maxBytes) { continue }
        if (-not (Test-IsTextFile $f)) { continue }
        $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
        $lines = $content -split "`n"; $ln = 0
        foreach($line in $lines){
          $ln++
          foreach($pat in $SecretPatterns){
            $m=[regex]::Matches($line,$pat.Pattern)
            foreach($x in $m){
              $v=$x.Value
              if($v.Length -gt 8){ $v=('*' * [Math]::Max(0,$v.Length-4)) + $v.Substring($v.Length-4) }
              $find.Add([pscustomobject]@{File=$f.FullName;Line=$ln;Pattern=$pat.Name;Match=$v;Snippet=($line.Trim().Substring(0,[Math]::Min(160,$line.Length)))}) | Out-Null
            }
          }
        }
      } catch {}
    }
    return $find
  }

  function Collect-Docs([string]$r){
    foreach($n in 'README','README.md','README.rst','CONTRIBUTING.md','CODE_OF_CONDUCT.md','LICENSE','LICENSE.md','COPYING','SECURITY.md','NOTICE','CHANGELOG.md'){
      $p = Join-Path $r $n; if(Test-Path -LiteralPath $p){ Copy-Item -LiteralPath $p -Destination (Join-Path $docsDir (Split-Path -Leaf $p)) -Force }
    }
    $docsSub = Join-Path $r 'docs'
    if (Test-Path -LiteralPath $docsSub -PathType Container){
      $toCopy = Get-ChildItem -LiteralPath $docsSub -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.md','.rst','.txt') }
      foreach($f in $toCopy){ $rel = $f.FullName.Substring($docsSub.Length).TrimStart([char]92,[char]47); $dest = Join-Path $docsDir $rel; New-DirectorySafe (Split-Path -Path $dest -Parent) | Out-Null; Copy-Item -LiteralPath $f.FullName -Destination $dest -Force }
    }
  }
}

process {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  Info 'Enumerating files...'
  $all = Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object { -not (Should-Exclude $_) }
  Info ('Files considered: ' + (@($all).Count))

  if ($MaxFiles -gt 0 -and $all.Count -gt $MaxFiles) { $all = $all | Select-Object -First $MaxFiles; Warn ('Capped to first ' + $MaxFiles + ' files via -MaxFiles.') }
  if (-not $Fast.IsPresent -and -not $Deep.IsPresent -and $all.Count -gt 10000) { $Fast = $true; Warn 'Auto-enabled -Fast for large tree (>10k). Use -Deep to override.' }
  if ($Deep.IsPresent) { $Fast = $false }

  $maxInvBytes = $MaxFileSizeMB * 1MB
  $maxSecBytes = $SecretsMaxFileSizeMB * 1MB

  $inv = New-Object System.Collections.Generic.List[object]
  $langCounts = @{}

  $total = [double](@($all).Count)
  $i = 0
  foreach($f in $all){
    $i++
    if (($i % 1000) -eq 0 -or $i -eq 1 -or $i -eq $total) { Write-Progress -Activity 'Analyzing files' -Status ("{0}/{1}" -f $i,[int]$total) -PercentComplete ([int](100.0*($i/$total))) }
    $isText = $false; $loc = $null
    if (-not $Fast){ $isText = Test-IsTextFile $f; if ($isText -and $f.Length -le $maxInvBytes){ $loc = Get-LineCount $f } }
    $lang = Detect-Lang $f
    if (-not $langCounts.ContainsKey($lang)) { $langCounts[$lang] = 0 }
    $langCounts[$lang] = $langCounts[$lang] + 1
    $inv.Add([pscustomobject]@{ Path=$f.FullName; RelativePath=$f.FullName.Substring($root.Length).TrimStart([char]92,[char]47); Name=$f.Name; Extension=$f.Extension; Language=$lang; SizeBytes=[int64]$f.Length; IsText=[bool]$isText; Lines=$loc; ModifiedUtc=$f.LastWriteTimeUtc }) | Out-Null
  }
  Write-Progress -Activity 'Analyzing files' -Completed

  $invCsv  = Join-Path $reportsDir 'file_inventory.csv'
  $inv | Sort-Object RelativePath | Export-Csv -LiteralPath $invCsv -NoTypeInformation -Encoding utf8
  $invJson = Join-Path $reportsDir 'file_inventory.json'; JWrite $inv $invJson | Out-Null
  $treeTxt = Join-Path $reportsDir 'tree.txt'; (Get-DirectoryTree $root) | Out-File -FilePath $treeTxt -Encoding utf8

  $largest = $inv | Sort-Object SizeBytes -Descending | Select-Object -First 25
  $recent  = $inv | Sort-Object ModifiedUtc -Descending | Select-Object -First 25

  $langsOrdered = $langCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { @{ name=$_.Key; files=$_.Value } }
  $summary = [ordered]@{
    root=$root; generatedAt=(Get-Date).ToString('o'); fileCount=$inv.Count;
    totalBytes = ($inv | Measure-Object -Property SizeBytes -Sum).Sum;
    languages=$langsOrdered; largestFiles=$largest; recentFiles=$recent;
    settings=@{ MaxFileSizeMB=$MaxFileSizeMB; SecretsMaxFileSizeMB=$SecretsMaxFileSizeMB; Fast=$Fast.IsPresent; Deep=$Deep.IsPresent; MaxFiles=$MaxFiles };
    excludes=@{ dirs=$ExcludeDirs; fileGlobs=$ExcludeFileGlobs }
  }
  $summaryPath = Join-Path $reportsDir 'analysis_summary.json'; JWrite $summary $summaryPath | Out-Null

  $gitReport = Join-Path $reportsDir 'git_summary.txt'
  if (-not $NoGit){
    $g = Probe-Git $root
    if ($g -ne $null){
      @(
        ('isRepo: ' + $g.isRepo),
        ('root:   ' + $g.root),
        ('branch: ' + $g.branch),
        '', '[remotes]', $g.remotes, '', '[status]', $g.status, '', '[recent commits]', $g.recent
      ) | Out-File -FilePath $gitReport -Encoding utf8
    } else { 'No Git data available or git not installed.' | Out-File -FilePath $gitReport -Encoding utf8 }
  } else { 'Git probing disabled.' | Out-File -FilePath $gitReport -Encoding utf8 }

  Extract-Dependencies $root
  Collect-Docs $root

  $secretsCsv = Join-Path $reportsDir 'potential_secrets.csv'
  if (-not $Fast){
    Info 'Scanning for potential secrets (heuristic)...'
    $scanSet = $inv | Where-Object { $_.IsText -eq $true -and $_.SizeBytes -le $maxSecBytes }
    $find = Scan-Secrets ($scanSet | ForEach-Object { Get-Item -LiteralPath $_.Path }) $maxSecBytes
    $find | Export-Csv -LiteralPath $secretsCsv -NoTypeInformation -Encoding utf8
  } else { 'Fast mode enabled; secrets scan skipped.' | Out-File -FilePath $secretsCsv -Encoding utf8 }

  Info 'Bundling reports and key manifests...'
  $bundleRoot = New-DirectorySafe (Join-Path $artifactsDir 'bundle')
  Copy-Item -LiteralPath $summaryPath -Destination $bundleRoot -Force
  Copy-Item -LiteralPath $invCsv -Destination $bundleRoot -Force
  Copy-Item -LiteralPath $invJson -Destination $bundleRoot -Force
  Copy-Item -LiteralPath $treeTxt -Destination $bundleRoot -Force
  if (Test-Path -LiteralPath $depsDir)   { Copy-Item -LiteralPath $depsDir -Destination (Join-Path $bundleRoot 'dependencies') -Recurse -Force }
  if (Test-Path -LiteralPath $docsDir)   { Copy-Item -LiteralPath $docsDir -Destination (Join-Path $bundleRoot 'docs') -Recurse -Force }
  if (Test-Path -LiteralPath $secretsCsv){ Copy-Item -LiteralPath $secretsCsv -Destination $bundleRoot -Force }
  $gitReportPath = Join-Path $bundleRoot 'git_summary.txt'
  if (Test-Path -LiteralPath $gitReport) { Copy-Item -LiteralPath $gitReport -Destination $gitReportPath -Force }

  if (Test-Path -LiteralPath $bundleZip) { Remove-Item -LiteralPath $bundleZip -Force }
  Compress-Archive -Path (Join-Path $bundleRoot '*') -DestinationPath $bundleZip -Force

  Write-Host ''
  Write-Host '===== ANALYSIS COMPLETE =====' -ForegroundColor Green
  Write-Host ('Reports: ' + $reportsDir)
  Write-Host ('Bundle:  ' + $bundleZip)
  Write-Host ('Files:   ' + $summary.fileCount)
  Write-Host ('Total:   ' + ('{0:N0}' -f $summary.totalBytes) + ' bytes')
  $top = $summary.languages | Select-Object -First 5 | ForEach-Object { '{0} ({1})' -f $_.name,$_.files }
  Write-Host ('Top languages: ' + ($top -join ', '))
  Write-Host ('Elapsed: ' + $sw.Elapsed)
}

end {
  if (-not (Test-Path -LiteralPath $bundleZip)) { exit 1 } else { exit 0 }
}
