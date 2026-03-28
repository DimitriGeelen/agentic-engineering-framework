# T-678: vnx-orchestration Deep-Dive

## Status: In Progress

## Repo
https://github.com/Vinix24/vnx-orchestration
Cloned to: /opt/051-Vinix24

## Findings So Far

### E2E Init Test (2026-03-28)
- `fw init` silently skipped writing framework hooks because project had pre-existing `.claude/settings.json`
- Bug filed as T-677, fixed: init now backs up and replaces with framework hooks
- Original project hooks preserved in `.claude/settings.json.pre-fw` for investigation

### Project Hooks (pre-existing)
The project has its own Claude Code hook system:
- SessionStart: terminal-specific routing (T0/T1/T2/T3/T-MANAGER)
- UserPromptSubmit: intelligence injection (per-terminal)
- PreToolUse: T0 readonly enforcer, venv activation
- PostToolUse: handover detection, worker prompt summary
- Stop: context monitor

These hooks reference `/Users/vincentvandeth/Development/vnx-system-wt-upgrade/` — Mac-specific paths.

### Open Question: Hook Strategy for Ingestion
TermLink agent dispatched to reflect on whether deep-dive ingestion should:
1. Apply framework hooks (governance) alongside project hooks (investigation)
2. Keep project hooks only (read-only analysis from framework project)
3. Replace with framework hooks only

## Next Steps
- Spike 1: Codebase survey
- Spike 2: Component fabric build
- Spike 3: Architecture mapping
