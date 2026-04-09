# check-project-boundary

> PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559).

**Type:** script | **Subsystem:** hook-enforcement | **Location:** `agents/context/check-project-boundary.sh`

**Tags:** `hook`, `enforcement`, `tier0`, `boundary`

## What It Does

Project Boundary Enforcement Hook — PreToolUse gate for Write/Edit/Bash
Blocks file modifications and commands targeting paths outside PROJECT_ROOT.
Exit codes (Claude Code PreToolUse semantics):
0 — Allow tool execution
2 — Block tool execution (stderr shown to agent)
For Write/Edit: extracts file_path, blocks if outside PROJECT_ROOT.
For Bash: detects cd+write patterns targeting other projects.
Allowed exceptions:
/tmp/**                — Agent dispatch working files
/root/.claude/**       — Claude Code memory/settings

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `agents/context/check-tier0.sh` | related |
| `agents/context/check-active-task.sh` | related |
| `lib/paths.sh` | calls |
| `lib/config.sh` | calls |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `.claude/settings.json` | triggers |

## Related

### Tasks
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block

---
*Auto-generated from Component Fabric. Card: `agents-context-check-project-boundary.yaml`*
*Last verified: 2026-03-28*
