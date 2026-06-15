#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$scripts = @(
    "install.ps1",
    "skills\claude-code-dispatch\scripts\dispatch-claude-code.ps1",
    "skills\claude-code-dispatch\scripts\get-claude-workflow-status.ps1"
)

foreach ($script in $scripts) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path -LiteralPath $script),
        [ref]$tokens,
        [ref]$errors)

    if ($errors.Count -gt 0) {
        throw "PowerShell parse failed: $script`n$($errors | Out-String)"
    }
    Write-Host "PARSE_OK $script"
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "claude-code-dispatch-skill-test"
if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}

$work = Join-Path $testRoot "work"
$installRoot = Join-Path $testRoot "skills"
$backupRoot = Join-Path $testRoot "backups"
New-Item -ItemType Directory -Path $work -Force | Out-Null

try {
    $dispatch = Resolve-Path -LiteralPath "skills\claude-code-dispatch\scripts\dispatch-claude-code.ps1"
    $prompt = Resolve-Path -LiteralPath "examples\task-prompt.md"

    & $dispatch `
        -PromptPath $prompt `
        -WorkingDirectory $work `
        -ClaudePath "claude-not-required-for-prepare-only" `
        -DispatchMode ultracode `
        -WorkflowName "repository-self-test" `
        -PrepareOnly | Out-Null

    $artifactRoot = Join-Path $work ".claude-dispatch"
    $stateFile = Get-ChildItem -LiteralPath $artifactRoot -Filter "*.state.json" | Select-Object -First 1
    $promptFile = Get-ChildItem -LiteralPath $artifactRoot -Filter "*.prompt.md" |
        Where-Object { $_.Name -notlike "*.source.prompt.md" } |
        Select-Object -First 1

    if ($null -eq $stateFile -or $null -eq $promptFile) {
        throw "PrepareOnly did not create expected artifacts."
    }

    $state = Get-Content -LiteralPath $stateFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $generatedPrompt = Get-Content -LiteralPath $promptFile.FullName -Raw -Encoding UTF8

    if ($state.dispatch_mode -ne "ultracode" -or
        $state.workflow_name -ne "repository-self-test" -or
        -not $state.prepared_only) {
        throw "PrepareOnly state is invalid."
    }

    if (-not $generatedPrompt.StartsWith("ultracode: use a dynamic workflow for development.")) {
        throw "Ultracode bootstrap is missing."
    }

    & .\install.ps1 -DestinationRoot $installRoot -BackupRoot $backupRoot | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $installRoot "claude-code-dispatch\SKILL.md"))) {
        throw "Installer did not copy the skill."
    }

    & .\install.ps1 -DestinationRoot $installRoot -BackupRoot $backupRoot -Force | Out-Null
    $backups = @(Get-ChildItem -LiteralPath $backupRoot -Directory)
    if ($backups.Count -ne 1 -or
        -not (Test-Path -LiteralPath (Join-Path $backups[0].FullName "SKILL.md"))) {
        throw "Force install did not create a valid external backup."
    }

    Write-Host "PREPARE_ONLY_OK"
    Write-Host "INSTALL_OK"
    Write-Host "FORCE_BACKUP_OK"
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
