# claude_set/home 을 %USERPROFILE%\.claude 로 설치한다.
# 주의: 우분투에서 작성했고 윈도우에서 아직 검증하지 않았다.
param([switch]$Status, [switch]$Pull, [switch]$Help)
$ErrorActionPreference = "Stop"

$Repo  = Split-Path -Parent $PSScriptRoot
$Src   = Join-Path $Repo "home"
$Dest  = Join-Path $env:USERPROFILE ".claude"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$SrcSettings  = Join-Path $Src "settings.json"
$DestSettings = Join-Path $Dest "settings.json"

if ($Help) {
@"
Usage: sync-claude.ps1 [-Status | -Pull | -Help]

  (no option)  Copy home\ into ~\.claude\ and merge shared settings
  -Status      Compare both sides, change nothing
  -Pull        Copy changes from ~\.claude\ back into home\
  -Help        Show this message
"@
  exit 0
}

# settings.json 은 병합으로 따로 처리한다
function Get-Items { Get-ChildItem -Path $Src | Where-Object { $_.Name -ne "settings.json" } }

# 파일이면 해시로, 폴더면 하위 파일 전체를 비교한다
function Test-Same($a, $b) {
  if (-not (Test-Path $b)) { return $false }
  if (Test-Path $a -PathType Container) {
    $x = Get-ChildItem -Recurse -File $a | ForEach-Object { $_.FullName.Substring($a.Length) + (Get-FileHash $_.FullName).Hash }
    $y = Get-ChildItem -Recurse -File $b | ForEach-Object { $_.FullName.Substring($b.Length) + (Get-FileHash $_.FullName).Hash }
    return ($null -eq (Compare-Object -ReferenceObject @($x) -DifferenceObject @($y)))
  }
  return (Get-FileHash $a).Hash -eq (Get-FileHash $b).Hash
}

# 공유 항목만 덮어쓰고 나머지 설정은 그대로 둔다
function Merge-Settings {
  $shared = Get-Content $SrcSettings -Raw | ConvertFrom-Json
  if (Test-Path $DestSettings) {
    Copy-Item $DestSettings "$DestSettings.backup-$Stamp"
    $current = Get-Content $DestSettings -Raw | ConvertFrom-Json
  } else {
    $current = [PSCustomObject]@{}
  }
  foreach ($p in $shared.PSObject.Properties) {
    $current | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
    Write-Host "  merged: $($p.Name)"
  }
  $current | ConvertTo-Json -Depth 20 | Set-Content $DestSettings -Encoding UTF8
}

if (-not (Test-Path $Src)) { Write-Host "Not found: $Src"; exit 1 }
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

if ($Status) {
  Write-Host "Repo   : $Src"
  Write-Host "Target : $Dest"
  foreach ($item in Get-Items) {
    $dst = Join-Path $Dest $item.Name
    if (-not (Test-Path $dst)) { Write-Host "  [none] $($item.Name)" }
    elseif (Test-Same $item.FullName $dst) { Write-Host "  [ok  ] $($item.Name)" }
    else { Write-Host "  [DIFF] $($item.Name)" }
  }
  exit 0
}

# 홈에서 고친 것을 저장소로 되돌린다
if ($Pull) {
  foreach ($item in Get-Items) {
    $dst = Join-Path $Dest $item.Name
    if (-not (Test-Path $dst)) { Write-Host "  skipped: $($item.Name)"; continue }
    if (Test-Same $item.FullName $dst) { Write-Host "  unchanged: $($item.Name)"; continue }
    Copy-Item $dst $item.FullName -Recurse -Force
    Write-Host "  pulled: $($item.Name)"
  }
  Write-Host "Review with: git -C $Repo diff"
  exit 0
}

Write-Host "Installing from $Src"
foreach ($item in Get-Items) {
  $dst = Join-Path $Dest $item.Name
  # 내용이 다르면 백업을 남긴다
  if ((Test-Path $dst) -and -not (Test-Same $item.FullName $dst)) {
    Copy-Item $dst "$dst.backup-$Stamp" -Recurse
    Write-Host "  backed up: $($item.Name)"
  }
  Copy-Item $item.FullName $Dest -Recurse -Force
  Write-Host "  installed: $($item.Name)"
}
Write-Host "Merging shared settings into $DestSettings"
Merge-Settings
