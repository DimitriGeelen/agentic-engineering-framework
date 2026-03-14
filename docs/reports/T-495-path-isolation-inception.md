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

## Spike Results

### Spike 1: `fw hook` subcommand (VALIDATED)
- `fw` is in PATH (`/usr/local/bin/fw` → symlink to `~/.agentic-framework/bin/fw`)
- `fw` already resolves `FRAMEWORK_ROOT` from its own symlink location (line 27-28, 44-63)
- `fw` already resolves `PROJECT_ROOT` from cwd via `find_project_root()` (line 30-41)
- Claude Code runs hooks with cwd = project root
- Performance: 4ms overhead for path resolution. Total hook time ~127ms. Negligible.
- `fw hook <name>` is ~15 lines: resolve paths, export, exec `$FRAMEWORK_ROOT/agents/context/$1.sh`

### Spike 2: PROJECT_ROOT resolution (VALIDATED)
- Claude Code sets cwd to project root when running hooks
- `fw` finds PROJECT_ROOT by walking up from cwd looking for `.framework.yaml` or `.tasks/`
- No `PROJECT_ROOT=` prefix needed in hook commands — fw resolves it automatically
- `.framework.yaml` still useful as a marker but `framework_path` field is redundant — fw finds itself

### Spike 3: `fw doctor` hook path validation (DESIGNED)
- Current check (line 407): `grep -q "check-tier0.sh"` — checks string exists, not path validity
- Fix: extract all `"command"` values from settings.json, resolve executable path, check existence
- Python one-liner validates all 11 hooks in <50ms
- After migration to `fw hook`: doctor checks `which fw` instead (simpler)

### Spike 4: Portable settings.json (DESIGNED)
- Target: zero absolute paths in settings.json
- Before: `"command": "PROJECT_ROOT=/path /path/check-active-task.sh"` (breaks on clone)
- After: `"command": "fw hook check-active-task"` (works everywhere)
- `fw init` generates the portable version
- `fw upgrade` detects old-style hardcoded paths and regenerates

### Spike 5: Cross-machine self-test (DEFERRED)
- Can simulate by overriding FRAMEWORK_ROOT — but this is a build task detail, not inception

### Spike 6: .framework.yaml and CLAUDE.md (ASSESSED)
- `.framework.yaml` `framework_path:` — kept for backward compat but not relied on for hooks
- `fw` already resolves framework from its own location; `.framework.yaml` is fallback
- CLAUDE.md `__FRAMEWORK_ROOT__` substitution — check if any runtime code reads this

## Go/No-Go Criteria

**GO if:**
- [x] `fw hook` can resolve paths at runtime (VALIDATED — 4ms overhead, fw already has the resolution logic)
- [x] Fix can be applied incrementally (`fw upgrade` regenerates settings.json; old-style still works until migrated)
- [x] Existing projects can be repaired via `fw upgrade` (step [5/8] regenerates)

**NO-GO if:**
- [ ] Claude Code hook execution model doesn't support `fw hook` — NOT TRIGGERED (fw is in PATH, hooks inherit shell env)
- [ ] Runtime resolution adds >100ms per hook call — NOT TRIGGERED (4ms overhead)

## Decision

**GO.** All assumptions validated. Effort estimate: ~2-3 hours.

### Build tasks to create:
1. **`fw hook` subcommand** (~30 min): Add `hook)` case to bin/fw. Resolves paths, execs target script.
2. **Portable settings.json generation** (~30 min): Update `generate_claude_code_config()` in lib/init.sh. Use `fw hook <name>` instead of hardcoded paths.
3. **`fw upgrade` path repair** (~30 min): Step [5/8] detects old-style hardcoded paths, regenerates with portable format.
4. **`fw doctor` hook validation** (~20 min): Check that hook commands resolve to real executables.
5. **E2E test** (~30 min): Add path isolation phase to self-test — verify hooks resolve with simulated different FRAMEWORK_ROOT.
