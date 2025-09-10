# File: scripts/Analyze-Project.MIN.ps1
# Version: 0.1 (Windows PowerShell 5.1)
# Purpose: Minimal, robust inventory for large trees. No JSON parsing, no LOC, no nested funcs.
# Output: .analysis\run_YYYY-MM-DD_HH-mm-ss\min_bundle.zip with:
#   - file_inventory.csv (RelativePath, SizeBytes, ModifiedUtc, Extension)
#   - top_extensions.csv (Extension, Count, TotalBytes)
#   - tree.txt (ASCII directory tree; directories only)
#   - summary.txt (quick counters)
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File C:\Dasco1n\scripts\Analyze-Project.MIN.ps1 -Path 'C:\dasco1n'
# Optional:
#   -OutDir 'C:\dasco1n\.analysis'  -Exclude 'node_modules,.git,dist,build,.venv,vendor'  -MaxFiles 50000

[CmdletBinding()] param(
  [Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()] [string]$Path,
  [string]$OutDir,
  [int]$MaxFiles = 0,
  [string]$Exclude = '.git,node_modules,dist,build,out,target,bin,obj,coverage,logs,.idea,.vscode,.venv,venv,vendor,Pods,__pycache__'
)

$ErrorActionPreference = 'Stop'

# Helper: ensure dir
function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p | Out-Null } (Resolve-Path -LiteralPath $p).Path }

# Setup
$root = (Resolve-Path -LiteralPath $Path).Path
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Not a directory: $root" }
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $root '.analysis' }
$run = 'run_' + (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')
$runDir = Join-Path (Ensure-Dir $OutDir) $run
$reports = Ensure-Dir (Join-Path $runDir 'reports')
$bundle = Join-Path $runDir 'min_bundle.zip'

Write-Host ('[INFO ] Root:   ' + $root) -ForegroundColor Cyan
Write-Host ('[INFO ] OutDir: ' + $runDir) -ForegroundColor Cyan
Write-Host ('[INFO ] Bundle: ' + $bundle) -ForegroundColor Cyan

# Build exclude regex once (match any segment)
$exList = @()
foreach($seg in ($Exclude -split ',')) { $s=$seg.Trim(); if($s.Length -gt 0){ $exList += [regex]::Escape($s) } }
$excludePattern = if ($exList.Count -gt 0) { '(?i)(\\|/)(' + ($exList -join '|') + ')(\\|/)' } else { '$a^' }

# Inventory (files only)
$files = @(
  Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch $excludePattern }
)
if ($MaxFiles -gt 0 -and $files.Count -gt $MaxFiles) { $files = $files | Select-Object -First $MaxFiles }

# Emit CSV
$invCsv = Join-Path $reports 'file_inventory.csv'
$rows = foreach($f in $files) {
  $rel = $f.FullName.Substring($root.Length).TrimStart([char]92,[char]47)
  [pscustomobject]@{
    RelativePath = $rel
    SizeBytes    = [int64]$f.Length
    ModifiedUtc  = $f.LastWriteTimeUtc
    Extension    = $f.Extension.ToLowerInvariant()
  }
}
$rows | Sort-Object RelativePath | Export-Csv -LiteralPath $invCsv -NoTypeInformation -Encoding utf8

# Top extensions
$topCsv = Join-Path $reports 'top_extensions.csv'
$byExt = $rows | Group-Object Extension | ForEach-Object {
  $sum = ($_.Group | Measure-Object -Property SizeBytes -Sum).Sum
  [pscustomobject]@{ Extension=$_.Name; Count=$_.Count; TotalBytes=$sum }
} | Sort-Object Count -Descending
$byExt | Export-Csv -LiteralPath $topCsv -NoTypeInformation -Encoding utf8

# Tree (directories only) via cmd's TREE to keep it fast and ASCII-only
$treeTxt = Join-Path $reports 'tree.txt'
$treeCmd = 'cmd.exe'
$treeArgs = "/c","tree","/A","$root"
& $treeCmd $treeArgs | Out-File -FilePath $treeTxt -Encoding ascii

# Summary
$summaryTxt = Join-Path $reports 'summary.txt'
$totalBytes = ($rows | Measure-Object -Property SizeBytes -Sum).Sum
@(
  'Root:      ' + $root,
  'Generated: ' + (Get-Date).ToString('o'),
  'Files:     ' + $rows.Count,
  'TotalBytes:' + $totalBytes,
  'Excluded:  ' + $Exclude
) | Out-File -FilePath $summaryTxt -Encoding utf8

# Bundle
if (Test-Path -LiteralPath $bundle) { Remove-Item -LiteralPath $bundle -Force }
Compress-Archive -Path (Join-Path $reports '*') -DestinationPath $bundle -Force

Write-Host ''
Write-Host '===== MIN ANALYSIS COMPLETE =====' -ForegroundColor Green
Write-Host ('Bundle: ' + $bundle)
