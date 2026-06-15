#Requires -Version 5.1

param(
    [Parameter(Mandatory = $true)]
    [string]$PromptPath,

    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [string]$ClaudePath = "claude",

    [string[]]$AddDir = @(),

    [string]$LogPrefix = "claude-dispatch",

    [ValidateSet("default", "auto", "acceptEdits", "bypassPermissions", "dontAsk", "plan")]
    [string]$PermissionMode = "auto",

    [ValidateSet("low", "medium", "high", "xhigh", "max")]
    [string]$Effort = "high",

    [string]$Name = "Codex-dispatch",

    [string]$LogDirectory,

    [ValidateSet("direct", "ultracode")]
    [string]$DispatchMode = "direct",

    [string]$WorkflowName,

    [switch]$PrepareOnly,

    [switch]$VisibleInteractive,

    [switch]$KeepOpenAfterExit,

    [switch]$DangerouslySkipPermissions,

    [switch]$Wait
)

$ErrorActionPreference = "Stop"

$resolvedPrompt = (Resolve-Path -LiteralPath $PromptPath).Path
$resolvedWorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory).Path
$resolvedAddDirs = @()
foreach ($dir in $AddDir) {
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        $resolvedAddDirs += (Resolve-Path -LiteralPath $dir).Path
    }
}

if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
    $LogDirectory = Join-Path $resolvedWorkingDirectory ".claude-dispatch"
}

if (-not (Test-Path -LiteralPath $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory | Out-Null
}

$claudeCommand = Get-Command $ClaudePath -ErrorAction SilentlyContinue
if ($null -eq $claudeCommand) {
    if (-not $PrepareOnly) {
        throw "Claude Code executable not found: $ClaudePath"
    }
    $claudeExe = $ClaudePath
} else {
    $claudeExe = $claudeCommand.Source
    if ([string]::IsNullOrWhiteSpace($claudeExe)) {
        $claudeExe = $claudeCommand.Path
    }
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$safePrefix = $LogPrefix -replace '[^A-Za-z0-9_.-]', '-'
$base = Join-Path $LogDirectory "$safePrefix-$timestamp"
$promptSnapshot = "$base.prompt.md"
$outLog = "$base.out.log"
$errLog = "$base.err.log"
$pidFile = "$base.pid.txt"
$stateFile = "$base.state.json"
$sourcePromptSnapshot = $null
$resolvedWorkflowName = $null

if ($DispatchMode -eq "ultracode") {
    if ([string]::IsNullOrWhiteSpace($WorkflowName)) {
        $WorkflowName = $Name
    }
    $resolvedWorkflowName = $WorkflowName -replace '[^A-Za-z0-9_.-]', '-'
    $sourcePromptSnapshot = "$base.source.prompt.md"
    Copy-Item -LiteralPath $resolvedPrompt -Destination $sourcePromptSnapshot -Force
    $originalPrompt = Get-Content -LiteralPath $sourcePromptSnapshot -Raw -Encoding UTF8
    $workflowPrompt = @"
ultracode: use a dynamic workflow for development.

You must create and actually run a Claude Code built-in dynamic workflow.
Use this workflow name:
$resolvedWorkflowName

Hard requirements:
1. Invoke the Workflow tool and run the workflow. Do not switch to direct single-agent development after analysis.
2. Use phase() and agent() in the workflow script, parallel() where appropriate, and a structured return value.
3. Include at least these phases: read-only audit, implementation, integration verification, independent acceptance, and result reporting.
4. Read-only audits may run in parallel. Implementation agents may run in parallel only with explicit non-overlapping file ownership. Tasks that edit the same file must run sequentially.
5. The independent acceptance agent must inspect the actual diff, test results, and task boundaries instead of trusting implementation summaries.
6. The main session owns integration conflict resolution, final verification, and the requested result report.
7. Do not commit or push unless the original task explicitly requires it.
8. If the Workflow tool is unavailable, stop and report BLOCKED. Do not silently fall back to direct single-agent development.
9. The final response must include runId, workflowName, status, agentCount, and, when available, totalTokens, totalToolCalls, scriptPath, and the workflow state JSON path.

Original task source:
$resolvedPrompt

Original task snapshot:
$sourcePromptSnapshot

Complete original task:

--- BEGIN ORIGINAL TASK ---
$originalPrompt
--- END ORIGINAL TASK ---
"@
    Set-Content -LiteralPath $promptSnapshot -Value $workflowPrompt -Encoding UTF8
} else {
    Copy-Item -LiteralPath $resolvedPrompt -Destination $promptSnapshot -Force
}

function Quote-PowerShellSingle {
    param([string]$Value)
    return "'" + ($Value -replace "'", "''") + "'"
}

if ($PrepareOnly) {
    $state = [ordered]@{
        pid = $null
        mode = "prepare-only"
        prepared_at = (Get-Date).ToString("o")
        claude = $claudeExe
        working_directory = $resolvedWorkingDirectory
        add_dir = $resolvedAddDirs
        prompt = $resolvedPrompt
        source_prompt_snapshot = $sourcePromptSnapshot
        prompt_snapshot = $promptSnapshot
        pid_file = $pidFile
        state_file = $stateFile
        permission_mode = $PermissionMode
        effort = $Effort
        name = $Name
        dispatch_mode = $DispatchMode
        workflow_name = $resolvedWorkflowName
        prepared_only = $true
    }

    $stateText = ($state.GetEnumerator() | ForEach-Object {
        if ($_.Value -is [array]) {
            "$($_.Key)=$($_.Value -join ';')"
        } else {
            "$($_.Key)=$($_.Value)"
        }
    }) -join [Environment]::NewLine
    Set-Content -Path $pidFile -Value $stateText -Encoding UTF8
    $state | ConvertTo-Json -Depth 4 | Set-Content -Path $stateFile -Encoding UTF8
    $state | ConvertTo-Json -Depth 4
    exit 0
}

if ($VisibleInteractive) {
    $transcript = "$base.transcript.txt"
    $addDirArgText = ""
    foreach ($dir in $resolvedAddDirs) {
        $addDirArgText += " --add-dir " + (Quote-PowerShellSingle $dir)
    }

    $dangerArgText = ""
    if ($DangerouslySkipPermissions) {
        $dangerArgText = " --dangerously-skip-permissions"
    }
    $keepOpenLiteral = if ($KeepOpenAfterExit) { '$true' } else { '$false' }

    $launchScript = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $(Quote-PowerShellSingle $resolvedWorkingDirectory)
`$transcript = $(Quote-PowerShellSingle $transcript)
Start-Transcript -Path `$transcript -Append
Write-Host 'Claude Code visible interactive session'
Write-Host 'Working directory: $resolvedWorkingDirectory'
Write-Host 'Prompt snapshot: $promptSnapshot'
Write-Host 'Transcript: ' `$transcript
Write-Host ''
`$promptText = Get-Content -LiteralPath $(Quote-PowerShellSingle $promptSnapshot) -Raw -Encoding UTF8
& $(Quote-PowerShellSingle $claudeExe)$addDirArgText --permission-mode $(Quote-PowerShellSingle $PermissionMode) --effort $(Quote-PowerShellSingle $Effort) --name $(Quote-PowerShellSingle $Name)$dangerArgText -- `$promptText
Write-Host ''
Stop-Transcript
if ($keepOpenLiteral) {
    Write-Host 'Claude Code exited. Press Enter to close this window.'
    Read-Host
}
"@

    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($launchScript))
    $powerShellArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encoded)
    if ($KeepOpenAfterExit) {
        $powerShellArgs = @("-NoProfile", "-NoExit", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encoded)
    }

    $proc = Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList $powerShellArgs `
        -WorkingDirectory $resolvedWorkingDirectory `
        -PassThru

    $state = [ordered]@{
        pid = $proc.Id
        mode = "visible-interactive"
        started_at = (Get-Date).ToString("o")
        claude = $claudeExe
        working_directory = $resolvedWorkingDirectory
        add_dir = $resolvedAddDirs
        prompt = $resolvedPrompt
        source_prompt_snapshot = $sourcePromptSnapshot
        prompt_snapshot = $promptSnapshot
        transcript = $transcript
        pid_file = $pidFile
        state_file = $stateFile
        permission_mode = $PermissionMode
        effort = $Effort
        name = $Name
        dispatch_mode = $DispatchMode
        workflow_name = $resolvedWorkflowName
        keep_open_after_exit = [bool]$KeepOpenAfterExit
    }

    $stateText = ($state.GetEnumerator() | ForEach-Object {
        if ($_.Value -is [array]) {
            "$($_.Key)=$($_.Value -join ';')"
        } else {
            "$($_.Key)=$($_.Value)"
        }
    }) -join [Environment]::NewLine
    Set-Content -Path $pidFile -Value $stateText -Encoding UTF8
    $state | ConvertTo-Json -Depth 4 | Set-Content -Path $stateFile -Encoding UTF8
    $state | ConvertTo-Json -Depth 4
    exit 0
}

$arguments = @(
    "-p",
    "--permission-mode", $PermissionMode,
    "--effort", $Effort,
    "--output-format", "text",
    "--name", $Name
)

foreach ($dir in $resolvedAddDirs) {
    $arguments += @("--add-dir", $dir)
}

if ($DangerouslySkipPermissions) {
    $arguments += "--dangerously-skip-permissions"
}

$proc = Start-Process `
    -FilePath $claudeExe `
    -ArgumentList $arguments `
    -WorkingDirectory $resolvedWorkingDirectory `
    -RedirectStandardInput $promptSnapshot `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog `
    -WindowStyle Hidden `
    -PassThru

$state = [ordered]@{
    pid = $proc.Id
    mode = "hidden-non-interactive"
    started_at = (Get-Date).ToString("o")
    claude = $claudeExe
    working_directory = $resolvedWorkingDirectory
    add_dir = $resolvedAddDirs
    prompt = $resolvedPrompt
    source_prompt_snapshot = $sourcePromptSnapshot
    prompt_snapshot = $promptSnapshot
    out_log = $outLog
    err_log = $errLog
    pid_file = $pidFile
    state_file = $stateFile
    permission_mode = $PermissionMode
    effort = $Effort
    name = $Name
    dispatch_mode = $DispatchMode
    workflow_name = $resolvedWorkflowName
}

$stateText = ($state.GetEnumerator() | ForEach-Object {
    if ($_.Value -is [array]) {
        "$($_.Key)=$($_.Value -join ';')"
    } else {
        "$($_.Key)=$($_.Value)"
    }
}) -join [Environment]::NewLine
Set-Content -Path $pidFile -Value $stateText -Encoding UTF8
$state | ConvertTo-Json -Depth 4 | Set-Content -Path $stateFile -Encoding UTF8

if ($Wait) {
    Wait-Process -Id $proc.Id
    $state["exited_at"] = (Get-Date).ToString("o")
    $state["exit_observed"] = $true
    $state | ConvertTo-Json -Depth 4 | Set-Content -Path $stateFile -Encoding UTF8
}

$state | ConvertTo-Json -Depth 4
