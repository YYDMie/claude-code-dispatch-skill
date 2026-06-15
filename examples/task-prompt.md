# Feature A Implementation Task

Work in the repository specified by the dispatcher.

## Goal

Implement Feature A and add focused regression tests.

## Read First

1. `AGENTS.md`
2. `docs/architecture.md`
3. Existing implementation and tests in the target module

## Scope

- Modify only `src/feature-a/` and `tests/feature-a/`.
- Preserve existing public behavior outside Feature A.
- Follow the repository's established patterns.

## Requirements

1. Reproduce the current missing behavior with a test.
2. Implement the smallest complete fix.
3. Add success, failure, and edge-case coverage.
4. Do not commit or push.

## Verification

```powershell
dotnet test .\tests\FeatureA.Tests\FeatureA.Tests.csproj
git diff --check
```

## Result Report

Write `.claude-dispatch/feature-a-result.md` with:

- files changed;
- behavior implemented;
- exact tests run and results;
- unresolved risks;
- final `git status --short`.
