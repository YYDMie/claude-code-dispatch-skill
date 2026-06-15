---
name: claude-code-dispatch
description: Launch local Claude Code from Codex using a scoped prompt file, tracked state and logs, optional visible interaction, and optional ultracode dynamic workflows. Use when the user asks Codex to dispatch, hand off, start, monitor, or validate a Claude Code development task, or asks to use Claude Code multi-agent workflows and return to Codex for independent acceptance.
---

# Claude Code Dispatch

Use the bundled PowerShell scripts to hand a scoped task from Codex to local Claude Code and retain evidence for later Codex acceptance.

## Select A Mode

- Use `direct` for a narrow task with one ownership area.
- Use `ultracode` for a multi-area task that benefits from read-only audits, non-overlapping implementation ownership, integration, and independent acceptance.
- Avoid dynamic workflows for small tasks because multi-agent runs can consume substantially more time and tokens.

`ultracode` is a prompt protocol that requires Claude Code to invoke its built-in `Workflow` tool. It is not a Claude CLI option or plugin. Read [references/ultracode-workflows.md](references/ultracode-workflows.md) before using workflow mode.

## Dispatch

1. Confirm Claude Code is available:

```powershell
Get-Command claude
claude --version
```

2. Check for an existing matching run:

```powershell
Get-Process | Where-Object { $_.ProcessName -like 'claude*' }
```

3. Launch a visible direct task:

```powershell
$skill = "$HOME\.codex\skills\claude-code-dispatch"

powershell -NoProfile -ExecutionPolicy Bypass `
  -File "$skill\scripts\dispatch-claude-code.ps1" `
  -PromptPath "C:\work\project\.tasks\feature-a.md" `
  -WorkingDirectory "C:\work\project" `
  -LogPrefix "feature-a" `
  -Name "Project-Feature-A" `
  -PermissionMode auto `
  -Effort high `
  -VisibleInteractive
```

4. Launch a visible ultracode workflow:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "$skill\scripts\dispatch-claude-code.ps1" `
  -PromptPath "C:\work\project\.tasks\release-prep.md" `
  -WorkingDirectory "C:\work\project" `
  -AddDir "C:\work\shared-contracts" `
  -LogPrefix "release-prep" `
  -Name "Project-Release-Prep" `
  -DispatchMode ultracode `
  -WorkflowName "project-release-prep" `
  -PermissionMode auto `
  -Effort high `
  -VisibleInteractive
```

5. Omit `-VisibleInteractive` for hidden execution.

6. Use `-PrepareOnly` to generate and inspect the final prompt without launching Claude.

## Monitor

For hidden mode, read the returned output and error log paths.

For ultracode, prefer workflow state over transcript polling:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "$skill\scripts\get-claude-workflow-status.ps1" `
  -WorkingDirectory "C:\work\project" `
  -WorkflowName "project-release-prep"
```

Use meaningful polling intervals. Interactive TUI transcripts may not contain Claude's complete screen output.

## Accept

When Claude finishes:

1. Inspect `git status --short --branch`.
2. Read the requested result report.
3. Inspect the real diff and changed-file boundaries.
4. Run the relevant tests and builds independently.
5. Write a narrow repair prompt when acceptance fails.
6. Commit or push only when the user explicitly requests it.

For workflow mode, require:

- A `wf_*.json` state with `status: completed`.
- A nonzero `agentCount`.
- A result report containing exact verification commands.
- Independent Codex validation of the actual working tree.

## Defaults

- Run Claude in `WorkingDirectory`.
- Snapshot the prompt before launch.
- Write dispatch artifacts to `<WorkingDirectory>\.claude-dispatch` unless `-LogDirectory` is supplied.
- Close visible windows automatically after Claude exits unless `-KeepOpenAfterExit` is set.
- Use permission mode `auto`.
- Use effort `high` for implementation and `medium` for small review tasks.
- Do not silently fall back to direct development when ultracode was explicitly requested. Report `BLOCKED` if Workflow is unavailable.

## Safety

- Dispatch only scoped prompts with explicit boundaries and verification.
- Keep credentials and production secrets out of prompts and logs.
- Do not enable `-DangerouslySkipPermissions` by default.
- Do not run parallel writer agents against overlapping files.
- Treat Claude and workflow summaries as claims, not acceptance evidence.
- Clean or ignore `.claude-dispatch` before committing a repository.

## Resources

- Use `scripts/dispatch-claude-code.ps1` to launch tasks.
- Use `scripts/get-claude-workflow-status.ps1` for low-frequency workflow checks.
- Read `references/ultracode-workflows.md` for workflow DSL and orchestration guidance.
