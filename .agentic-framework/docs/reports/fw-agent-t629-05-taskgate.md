# Task Gate Friction Audit — `check-active-task.sh`

## What It Checks (7 gates, sequential)

1. **B-005 — Settings protection**: Blocks Write/Edit to `.claude/settings.json` (enforcement config)
2. **Exempt path bypass**: Allows `$PROJECT_ROOT/{.context/,.tasks/,.claude/,.git/}*` without task
3. **Bootstrap detection**: If no `.context/working/` dir → allow (fresh project)
4. **Focus file exists**: If `.framework.yaml` exists but no `focus.yaml` → block ("run `fw context init`")
5. **Active task set**: `current_task` must be non-empty in `focus.yaml`
6. **Session stamp (T-560)**: Focus must be from current session (prevents stale cross-session focus)
7. **Task file exists (G-013)**: Task must have a file in `.tasks/active/`
8. **Status validation (T-354)**: Only `started-work` and `issues` statuses are workable
9. **Onboarding gate (T-535)**: If incomplete onboarding tasks exist, blocks non-onboarding work
10. **Build readiness (G-020)**: Build/refactor/test tasks must have real ACs (not placeholders)
11. **Inception advisory**: Warns (no block) if inception task has no GO decision
12. **Fabric advisory (T-244)**: Warns (no block) if file has downstream dependents

## Exempt Paths (Allowlist)

**Currently exempt** (line 61):
```
$PROJECT_ROOT/.context/*
$PROJECT_ROOT/.tasks/*
$PROJECT_ROOT/.claude/*
$PROJECT_ROOT/.git/*
```

**Anchored to PROJECT_ROOT** (line 59): This means `/root/.claude/projects/...` (Claude Code auto-memory) is **NOT exempt**. The anchoring was intentional — concerns.yaml notes that matching arbitrary `/root/.claude/` was a bypass vector.

## Legitimate Operations That Get Blocked

### 1. Claude Code Auto-Memory Writes (`/root/.claude/projects/.../memory/`)
- **Impact**: HIGH — memory writes happen automatically, not under task context
- **Current behavior**: Blocked unless a task is active
- **Workaround**: Agent must have a task active before saving memory
- **Assessment**: This is friction without governance value. Memory writes are metadata, not deliverables.

### 2. Config Edits (`.claude/settings.json`)
- **Impact**: MEDIUM — B-005 blocks ALL writes to settings.json, even legitimate config changes
- **Current behavior**: Hard block with no bypass path (not even with active task)
- **Workaround**: Human must edit manually
- **Assessment**: Intentional — settings.json controls hooks. This is correct.

### 3. Quick Fixes to Framework Scripts (`.agentic-framework/`)
- **Impact**: MEDIUM — fixing a broken hook requires a task, but the broken hook may BE the task gate
- **Current behavior**: Blocked, must create task first
- **Workaround**: `fw work-on "Fix hook" --type build --start`
- **Assessment**: Low friction in practice — `fw work-on` is fast. Circular dependency rare.

### 4. Emergency Patches
- **Impact**: LOW — `--force` or `--no-verify` available for emergencies
- **Current behavior**: Bypass exists but is logged
- **Assessment**: Correct design — bypass exists for emergencies, audit trail maintained.

### 5. Docs/Reports Outside Exempt Paths
- **Impact**: LOW — writing `docs/reports/T-XXX-*.md` requires active task
- **Assessment**: Correct — docs should be under a task. No friction issue.

## Bypass History

- **91 total bypasses** recorded in `.context/bypass-log.yaml` (657 lines)
- **77 bypasses (85%)** were inception-gate related (commit-msg hook, not task gate)
- **~14 bypasses** were for other reasons (bootstrap, emergency fixes)
- All bypasses were `authorized_by: human`
- No evidence of unauthorized bypasses or agent self-bypass

## Episodic Evidence

- **T-232**: Task gate accepted completed task IDs → fixed with active-file validation (G-013)
- **T-354**: Task gate allowed work on `captured` status → fixed with status validation
- **T-471**: Build tasks with placeholder ACs slipped through → fixed with build readiness gate (G-020)
- **T-535**: Onboarding sequence skipped → fixed with onboarding gate
- **T-560**: Stale focus from previous sessions → fixed with session stamp
- **L-038** (learnings.yaml): "Making compliance easier than non-compliance is the most effective enforcement strategy — fw work-on reduced 3 commands to 1"

## Concerns Registry

- **G-013**: Task gate bypass via completed task ID — **RESOLVED**
- **G-020**: Pickup message governance bypass — **RESOLVED**
- **G-021**: Path isolation failure (writes outside PROJECT_ROOT) — registered as urgent
- **Open**: Bash tool not task-gated (Write|Edit only) — bypass vector, T-619 inception planned

## Recommendations

### 1. Expand Allowlist for Auto-Memory (RECOMMENDED)
Add `/root/.claude/projects/*/memory/*` or equivalent pattern. Memory writes are metadata operations that support governance (learnings, feedback), not deliverables that need task traceability. Currently the anchoring to `$PROJECT_ROOT` blocks these. Options:
- **Option A**: Add a second case block for `*/memory/*.md` paths (any Claude Code memory directory)
- **Option B**: Add `$HOME/.claude/*` as exempt (broader, matches settings too — conflicts with B-005)
- **Preferred**: Option A — narrow, targeted, no B-005 conflict

### 2. Do NOT Add "Quick Fix" Mode
Evidence doesn't support it:
- Only 14/91 bypasses were non-inception (15%)
- `fw work-on` already reduced friction to one command (L-038)
- A "quick fix" mode would be a governance hole disguised as convenience
- The inception gate accounts for 85% of bypasses, and those are handled by the commit-msg hook (separate mechanism)

### 3. Do NOT Expand Allowlist for Framework Scripts
- Circular dependency (broken hook blocks its own fix) is theoretically possible but not evidenced in 91 bypass events
- `fw work-on "Fix hook" --type build --start` is fast enough
- Framework scripts ARE deliverables — they need task traceability

### 4. Consider: Bash Task Gate (T-619)
- Currently only Write/Edit are gated; Bash is ungated
- This is a known bypass vector (concerns.yaml)
- T-619 inception is already planned for this
- Adding Bash gating would need its own allowlist (git, fw commands, read-only operations)

## Summary

The task gate is well-designed with appropriate friction. The only genuine false-positive is **auto-memory writes** (`/root/.claude/projects/.../memory/`), which are metadata that shouldn't require task context. The inception commit gate (85% of bypasses) is a separate mechanism and has been addressed through the commit-msg hook design. The gate has evolved through 5 major hardening iterations (G-013, T-354, G-020, T-535, T-560) and is now robust.
