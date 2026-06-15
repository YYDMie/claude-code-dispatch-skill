#Requires -Version 5.1

param(
    [string]$DestinationRoot = (Join-Path $HOME ".codex\skills"),
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$source = Join-Path $PSScriptRoot "skills\claude-code-dispatch"
$destinationRootFull = [System.IO.Path]::GetFullPath($DestinationRoot)
$destination = Join-Path $destinationRootFull "claude-code-dispatch"

if (-not (Test-Path -LiteralPath (Join-Path $source "SKILL.md"))) {
    throw "Skill source not found: $source"
}

if (-not (Test-Path -LiteralPath $destinationRootFull)) {
    New-Item -ItemType Directory -Path $destinationRootFull -Force | Out-Null
}

$backup = $null
if (Test-Path -LiteralPath $destination) {
    if (-not $Force) {
        throw "Skill already exists at $destination. Re-run with -Force to back it up and replace it."
    }

    $backup = "$destination.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item -LiteralPath $destination -Destination $backup
}

try {
    Copy-Item -LiteralPath $source -Destination $destination -Recurse
} catch {
    if ($null -ne $backup -and (Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $destination)) {
        Move-Item -LiteralPath $backup -Destination $destination
    }
    throw
}

[ordered]@{
    installed = $true
    source = $source
    destination = $destination
    backup = $backup
} | ConvertTo-Json -Depth 3
