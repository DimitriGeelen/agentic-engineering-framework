# T-495: Path Isolation — Inception Research

## Problem Statement

`fw init` bakes machine-specific absolute paths into 3 committed files:
1. `.claude/settings.json` — 12 hook commands with hardcoded `FRAMEWORK_ROOT` and `PROJECT_ROOT`
2. `.framework.yaml` — `framework_path:` field
3. `CLAUDE.md` — `__FRAMEWORK_ROOT__` template substitution

When a project is cloned to a different machine, moved, or the framework is reinstalled to a different path, ALL hooks silently fail. Claude Code does not error on missing hook commands — it skips them.

**Impact:** Every enforcement gate (task gate, tier 0, budget gate, plan mode block, error watchdog, dispatch guard, pre-compact handover, post-compact resume) is silently disabled on any non-original environment. The framework's entire value proposition — structural enforcement — becomes a facade.

## Discovery

Found during T-434 (upgrade inception) follow-up. Termlink project's `.claude/settings.json` contained `/Users/dimidev32/.agentic-framework` and `/Users/dimidev32/001-projects/010-termlink` — hardcoded from the Mac where `fw init` was run. On any other machine, all hooks silently fail.

## Prior Art (within framework)

- **G-007** (2026-02-18): Same bug class. `budget-gate.sh`, `pre-compact.sh`, `post-compact-resume.sh` used `FRAMEWORK_ROOT` instead of `PROJECT_ROOT` for project-specific paths in shared-tooling mode. Fixed for those 3 scripts. Root cause (init.sh path baking) was never addressed.

## Contamination Points

| File | Line | What gets baked |
|------|------|-----------------|
| `lib/init.sh:499-608` | `<< SJSON` heredoc (unquoted) | `$FRAMEWORK_ROOT` in 12 hook commands, `$dir` (PROJECT_ROOT) in 8 hooks |
| `lib/init.sh:179` | `.framework.yaml` generation | `framework_path: $FRAMEWORK_ROOT` |
| `lib/init.sh:440` | CLAUDE.md template | `s\|__FRAMEWORK_ROOT__\|$FRAMEWORK_ROOT\|g` |

## Detection Gaps

| Tool | What it checks | What it misses |
|------|---------------|----------------|
| `fw doctor` | Hook script executability | Hook paths point to existing files |
| `fw upgrade` step [5/8] | Hook count (10/10) | Hook paths are valid |
| `fw self-test` | Runs hooks on same machine | Cross-machine path resolution |
| `fw audit` | Task/context compliance | Machine-specific paths in committed files |

## Exploration Plan

1. **Spike 1** (30 min): `fw hook` subcommand — runtime path resolution. Hooks call `fw hook check-active-task` instead of absolute paths. `fw` resolves both `FRAMEWORK_ROOT` (from its symlink) and `PROJECT_ROOT` (from cwd/git). Settings.json becomes machine-portable.

2. **Spike 2** (30 min): `.framework.yaml` path discovery — replace absolute `framework_path` with relative or discoverable path. Options: `which fw`, symlink resolution, relative to project root.

3. **Spike 3** (30 min): `fw doctor` hook path validation — scan `.claude/settings.json`, verify every command resolves to an existing executable. Fail loudly if not.

4. **Spike 4** (30 min): `fw upgrade` path repair — step [5/8] checks paths, not just count. If paths are stale, regenerate with runtime-resolved paths.

5. **Spike 5** (30 min): Cross-machine self-test — simulate different `FRAMEWORK_ROOT` to verify hooks still resolve.

6. **Spike 6** (20 min): CLAUDE.md template — eliminate `__FRAMEWORK_ROOT__` substitution or make it runtime-discoverable.

## Scope Fence

**IN scope:** All committed files that contain machine-specific absolute paths. Runtime path resolution for hooks. Detection in doctor/upgrade/audit. Cross-machine regression test.

**OUT of scope:** PATH environment variable management. Shell profile configuration. IDE-specific settings.

## Go/No-Go Criteria

**GO if:**
- `fw hook` can resolve paths at runtime (no hardcoded paths needed)
- Fix can be applied incrementally (doesn't require all-at-once migration)
- Existing projects can be repaired via `fw upgrade`

**NO-GO if:**
- Claude Code hook execution model doesn't support `fw hook` pattern (e.g., PATH not available in hook context)
- Runtime resolution adds >100ms per hook call (hooks fire on every tool use)
