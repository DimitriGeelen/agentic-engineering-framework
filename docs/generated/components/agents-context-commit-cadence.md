# commit-cadence

> PostToolUse hook: monitor time since last commit — warns when commit cadence exceeds threshold (P-009 budget management).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/commit-cadence.sh`

## What It Does

Commit Cadence Warning — PostToolUse hook for Write/Edit
Counts source file edits since last commit, warns when count is high.
Thresholds:
10 edits → soft warning (consider committing)
20 edits → strong warning (commit now, risk of context exhaustion)
Exempt paths (not counted):
.context/, .tasks/, .claude/, .agentic-framework/
Counter reset: post-commit git hook resets .edit-counter to 0
Exit code: always 0 (PostToolUse hooks are advisory, cannot block)
Output: JSON with additionalContext when warning threshold reached

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `.context/working/.edit-counter` | reads |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/context/checkpoint.sh` | complements |

---
*Auto-generated from Component Fabric. Card: `agents-context-commit-cadence.yaml`*
*Last verified: 2026-03-27*
