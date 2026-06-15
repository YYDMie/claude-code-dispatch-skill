#Requires -Version 5.1

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [string]$WorkflowName,

    [datetime]$Since = (Get-Date).AddDays(-1),

    [switch]$WaitForCompletion,

    [ValidateRange(15, 3600)]
    [int]$PollSeconds = 60,

    [ValidateRange(1, 1440)]
    [int]$TimeoutMinutes = 180
)

$ErrorActionPreference = "Stop"

$resolvedWorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory).Path
$projectKey = $resolvedWorkingDirectory -replace '[^A-Za-z0-9.-]', '-'
$projectRoot = Join-Path (Join-Path $HOME ".claude\projects") $projectKey
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)

function Get-LatestWorkflowState {
    if (-not (Test-Path -LiteralPath $projectRoot)) {
        return $null
    }

    $states = foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Recurse -Filter "wf_*.json" -File -ErrorAction SilentlyContinue) {
        if ($file.LastWriteTime -lt $Since) {
            continue
        }

        try {
            $data = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not [string]::IsNullOrWhiteSpace($WorkflowName) -and $data.workflowName -ne $WorkflowName) {
                continue
            }

            [pscustomobject]@{
                Data = $data
                File = $file
            }
        } catch {
            continue
        }
    }

    return $states | Sort-Object { $_.File.LastWriteTime } -Descending | Select-Object -First 1
}

while ($true) {
    $latest = Get-LatestWorkflowState
    if ($null -ne $latest) {
        $data = $latest.Data
        $output = [ordered]@{
            found = $true
            run_id = $data.runId
            workflow_name = $data.workflowName
            status = $data.status
            agent_count = $data.agentCount
            total_tokens = $data.totalTokens
            total_tool_calls = $data.totalToolCalls
            duration_ms = $data.durationMs
            script_path = $data.scriptPath
            state_file = $latest.File.FullName
            state_updated_at = $latest.File.LastWriteTime.ToString("o")
            result_available = ($null -ne $data.result)
        }

        if (-not $WaitForCompletion -or $data.status -in @("completed", "failed", "cancelled")) {
            $output | ConvertTo-Json -Depth 6
            exit 0
        }
    } elseif (-not $WaitForCompletion) {
        [ordered]@{
            found = $false
            workflow_name = $WorkflowName
            project_root = $projectRoot
            since = $Since.ToString("o")
        } | ConvertTo-Json -Depth 4
        exit 0
    }

    if ((Get-Date) -ge $deadline) {
        [ordered]@{
            found = ($null -ne $latest)
            timed_out = $true
            workflow_name = $WorkflowName
            project_root = $projectRoot
            timeout_minutes = $TimeoutMinutes
        } | ConvertTo-Json -Depth 4
        exit 2
    }

    Start-Sleep -Seconds $PollSeconds
}
