# Ultracode Dynamic Workflows

## Overview

`ultracode` is a prompt convention that asks Claude Code to invoke its built-in `Workflow` tool. It is not a `claude` command-line option and is not an installed plugin.

Successful local workflow runs have produced:

- JavaScript workflow scripts under `~/.claude/projects/<project>/<session>/workflows/scripts/`.
- State and result files named `wf_*.json`.
- Agent transcripts under `subagents/workflows/<run-id>/`.

Claude Code's interactive `/workflows` view may also show live progress.

This behavior is version-sensitive. The skill was validated against Claude Code 2.1.177.

## DSL

The observed workflow DSL uses JavaScript modules and these primitives:

```javascript
export const meta = {
  name: 'project-release-prep',
  description: 'Implement and verify a scoped release task',
  phases: [
    { title: 'Audit', detail: 'Read-only scope and dependency audit' },
    { title: 'Implementation', detail: 'Implement non-overlapping work' },
    { title: 'Acceptance', detail: 'Independent diff and test review' },
  ],
}

phase('Audit')
const audits = await parallel([
  () => agent('Audit API behavior. Do not edit files.', {
    label: 'api-audit',
    phase: 'Audit',
    agentType: 'Explore',
  }),
  () => agent('Audit tests and acceptance criteria. Do not edit files.', {
    label: 'test-audit',
    phase: 'Audit',
    agentType: 'Explore',
  }),
])

phase('Implementation')
const implementation = await agent(
  `Implement the scoped task using this audit evidence:
${JSON.stringify(audits)}`,
  { label: 'implementation', phase: 'Implementation' }
)

phase('Acceptance')
const acceptance = await agent(
  'Inspect the actual diff and run exact acceptance commands. Do not trust summaries.',
  { label: 'acceptance', phase: 'Acceptance', agentType: 'Explore' }
)

return { audits, implementation, acceptance }
```

Observed agent options include:

- `label`
- `phase`
- `model`
- `schema`
- `agentType: 'Explore'`

Use `schema` for structured audit or acceptance results.

## Recommended Structure

1. Audit: parallel and read-only.
2. Implementation: parallel only when file ownership is explicit and non-overlapping.
3. Integration: sequentially resolve compile failures and cross-module contracts.
4. Independent acceptance: inspect real files, diff, and command output.
5. Reporting: write the requested result report and return workflow metadata.

The main Claude session owns integration and final reporting. Successful agent summaries alone do not prove task completion.

## Resume A Workflow

The Workflow tool can return `scriptPath` and `runId`. After editing a saved workflow script, resume with:

```text
Workflow({
  scriptPath: "<saved script path>",
  resumeFromRunId: "<run id>"
})
```

Completed agents may be reused while changed or failed stages rerun.

If Workflow is unavailable, report `BLOCKED`. Do not silently continue as a direct single-agent task when workflow mode was required.

## Completion Evidence

Prefer `wf_*.json` over terminal transcript polling. Inspect:

- `status`
- `workflowName`
- `agentCount`
- `workflowProgress`
- `totalTokens`
- `totalToolCalls`
- `scriptPath`
- `result`

Begin Codex acceptance when the state reports completion, repository writes have stabilized, and the requested result report exists. Close an unused Claude window only after the run has genuinely finished.
