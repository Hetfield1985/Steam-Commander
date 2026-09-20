<#
.SYNOPSIS
    Builds "Steam Commander.exe" from src\Steam_Commander.ps1 using ps2exe.

.DESCRIPTION
    Requires the ps2exe module:  Install-Module ps2exe -Scope CurrentUser
    The version is read from `$global:appVersion in the script, so the exe
    metadata always matches the source. Output goes to .\dist.
#>
[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path $PSScriptRoot '..\dist')
)

$ErrorActionPreference = 'Stop'

$root   = Resolve-Path (Join-Path $PSScriptRoot '..')
$script = Join-Path $root 'src\Steam_Commander.ps1'
$icon   = Join-Path $root 'assets\icon\steam_commander.ico'

if (-not (Test-Path $script)) { throw "Script not found: $script" }
if (-not (Test-Path $icon))   { throw "Icon not found: $icon" }

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    throw "The 'ps2exe' module is not installed. Run: Install-Module ps2exe -Scope CurrentUser"
}
Import-Module ps2exe

# Read title and version from the script (single source of truth).
$text = Get-Content -LiteralPath $script -Raw -Encoding UTF8
$version = if ($text -match '\$global:appVersion\s*=\s*"([\d\.]+)"') { $Matches[1] } else { throw 'appVersion not found in script.' }
$title   = if ($text -match '\$global:appTitle\s*=\s*"([^"]+)"')      { $Matches[1] } else { 'Steam Commander' }

# ps2exe wants a 4-part version.
$parts = @($version.Split('.'))
while ($parts.Count -lt 4) { $parts += '0' }
$fileVersion = ($parts | Select-Object -First 4) -join '.'

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$exe = Join-Path $OutputDir "$title.exe"

Write-Host "Building $title $version -> $exe"

Invoke-ps2exe `
    -inputFile   $script `
    -outputFile  $exe `
    -iconFile    $icon `
    -noConsole `
    -STA `
    -requireAdmin `
    -title       $title `
    -product     $title `
    -description "Two-panel manager for non-Steam games" `
    -version     $fileVersion `
    -copyright   "MIT License"

Write-Host "Done: $exe"
