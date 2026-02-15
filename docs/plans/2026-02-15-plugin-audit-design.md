# Plugin Task-Awareness Audit — Design

**Task:** T-067
**Date:** 2026-02-15
**Status:** Approved

## Problem

When new Claude Code plugins are enabled, there is no process to check whether their skills are task-aware or whether their workflows conflict with the framework's core principle ("Nothing gets done without a task"). Investigation T-061 confirmed 0/20 loaded skills reference the task system.

## Approach: C — Doctor check + standalone audit

- `fw doctor` Check 7 flags plugin awareness issues during routine health checks
- `fw plugin-audit` provides detailed per-skill classification and recommendations

## `fw plugin-audit` Design

### Scan process

1. Read enabled plugins from `~/.claude/settings.json` (`enabledPlugins` keys)
2. Resolve each plugin to its marketplace directory under `~/.claude/plugins/marketplaces/`
3. Glob `skills/*/SKILL.md` within each plugin directory
4. Scan each skill file for task-system indicators

### Classification

| Category | Criteria | Action |
|----------|----------|--------|
| TASK-AWARE | References: `task`, `fw work-on`, `fw task`, `focus`, `TaskCreate`, `TaskUpdate`, `todo` in task-system context | None |
| TASK-SILENT | No task references, no authority-claiming language | Informational — no action needed |
| TASK-BYPASSING | Contains authority phrases (`MUST.*before any`, `before ANY response`, `DO NOT.*until`, `implement now`) without task gates | Recommend adding task-first gate |

### Output

Terminal report showing per-plugin summary and detailed list of BYPASSING skills with recommendations.

## `fw doctor` Check 7

Lightweight check: count BYPASSING skills across enabled plugins. OK if 0, WARN if >0 with pointer to `fw plugin-audit`.

## Files

- Create: `agents/audit/plugin-audit.sh`
- Modify: `bin/fw` (add route + doctor check)
