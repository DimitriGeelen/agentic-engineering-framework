# Hook Failure Cascade Analysis — T-629

**Date:** 2026-03-26
**Scope:** All 11 hooks in `.claude/settings.json`

---

## Hook Inventory

### PreToolUse Hooks (BLOCKING — exit 2 prevents tool execution)

| # | Hook Name | Matcher | Script | Gates |
|---|-----------|---------|--------|-------|
| H1 | block-plan-mode | `EnterPlanMode` | `agents/context/block-plan-mode.sh` | EnterPlanMode |
| H2 | check-active-task | `Write\|Edit` | `agents/context/check-active-task.sh` | Write, Edit |
| H3 | check-tier0 | `Bash` | `agents/context/check-tier0.sh` | Bash |
| H4 | check-project-boundary | `Write\|Edit\|Bash` | `agents/context/check-project-boundary.sh` | Write, Edit, Bash |
| H5 | budget-gate | `Write\|Edit\|Bash` | `agents/context/budget-gate.sh` | Write, Edit, Bash |

### PostToolUse Hooks (ADVISORY — exit code ignored, JSON output only)

| # | Hook Name | Matcher | Script | Monitors |
|---|-----------|---------|--------|----------|
| H6 | checkpoint | `""` (all tools) | `agents/context/checkpoint.sh` | All tools |
| H7 | error-watchdog | `Bash` | `agents/context/error-watchdog.sh` | Bash |
| H8 | check-dispatch | `Task\|TaskOutput` | `agents/context/check-dispatch.sh` | Task, TaskOutput |
| H9 | check-fabric-new-file | `Write` | `agents/context/check-fabric-new-file.sh` | Write |
| H10 | commit-cadence | `Write\|Edit` | `agents/context/commit-cadence.sh` | Write, Edit |

### Session Lifecycle Hooks

| # | Hook Name | Matcher | Script | When |
|---|-----------|---------|--------|------|
| H11 | pre-compact | `""` (PreCompact) | `agents/context/pre-compact.sh` | Before /compact |
| H12 | post-compact-resume | `compact` (SessionStart) | `agents/context/post-compact-resume.sh` | After compact |
| H13 | post-compact-resume | `resume` (SessionStart) | `agents/context/post-compact-resume.sh` | After `claude -c` |

---

## Dependency Graph

All hooks share a critical dependency chain:

```
.claude/settings.json
  └─ "fw hook <name>"
       └─ PATH resolution: bare `fw` → /root/.local/bin/fw → /root/.agentic-framework/bin/fw
            └─ fw hook routing: $AGENTS_DIR/context/<name>.sh
                 └─ AGENTS_DIR = $FRAMEWORK_ROOT/agents
                      └─ FRAMEWORK_ROOT = /root/.agentic-framework (GLOBAL, NOT vendored!)
```

### Per-Script Dependencies

| Script | Sources | Reads at Runtime | External Tools |
|--------|---------|------------------|----------------|
| check-active-task.sh | `lib/paths.sh` → `lib/compat.sh`, `lib/errors.sh`, `lib/tasks.sh`, `lib/yaml.sh` | `focus.yaml`, task files in `.tasks/active/`, `.fabric/components/*.yaml` | `python3` (JSON+YAML parse), `git` (via paths.sh), `find`, `grep`, `sed`, `head` |
| budget-gate.sh | `lib/paths.sh` | `.budget-status`, `.budget-gate-counter`, JSONL transcript | `python3` (JSON parse + token counting), `tail`, `find`, `xargs`, `ls`, `awk` |
| check-tier0.sh | `lib/paths.sh` | `.tier0-approval`, `.tier0-approval.pending` | `python3` (regex matching), `grep`, `sha256sum`, `awk` |
| check-project-boundary.sh | `lib/paths.sh` | stdin JSON only | `python3` (path analysis), `realpath` |
| block-plan-mode.sh | none | none | none (just echoes and exits) |
| checkpoint.sh | `lib/paths.sh` | `.tool-counter`, `.prev-token-reading`, JSONL transcript, `focus.yaml`, task files | `python3`, `git`, `find`, `xargs`, `stat`, `wc` |
| error-watchdog.sh | none | stdin JSON only | `python3` |
| check-dispatch.sh | none | stdin JSON only | `python3` |
| check-fabric-new-file.sh | none | `focus.yaml`, `.new-file-counter`, `.fabric/components/*.yaml`, `.fabric/watch-patterns.yaml` | `python3` (with `yaml` module) |
| commit-cadence.sh | none | `.edit-counter` | `python3` |
| pre-compact.sh | `lib/paths.sh` | git log | `git`, `handover.sh` (calls full agent) |
| post-compact-resume.sh | `lib/paths.sh` | `LATEST.md`, `focus.yaml`, task files, `subsystems.yaml`, `LATEST.yaml` (discoveries) | `python3`, `git`, `sed`, `grep`, `fabric.sh` |

---

## Failure Mode Analysis Per Hook

### H1: block-plan-mode.sh

- **Missing script:** `fw hook` exits 2 → "ERROR: Hook script not found" → **blocks EnterPlanMode** (correct behavior, fail-closed)
- **Bug in script:** Unlikely (8 lines, no dependencies). If echo fails: exit 2 still fires → still blocks
- **Missing dependencies:** None
- **Blast radius:** EnterPlanMode only (harmless — this is the intended behavior)
- **Risk:** NONE

### H2: check-active-task.sh (CRITICAL)

- **Missing script:** `fw hook` exits 2 → **blocks ALL Write/Edit** → agent cannot write ANY file
- **Bug in script (Python crash):**
  - JSON parse failure: `FILE_PATH=""` → falls through to focus check
  - YAML parse failure: `CURRENT_TASK=""` → **blocks with "No active task"** even if task exists
  - `find_task_file` failure (from tasks.sh): `ACTIVE_FILE=""` → **blocks with "task not active"** even if it is
- **Missing focus.yaml:**
  - If `.framework.yaml` exists → **blocks with "session not active"**
  - If no `.framework.yaml` → allows with warning (bootstrap mode)
- **Missing .context/working/:** Allows (bootstrap detection)
- **Missing lib/paths.sh:** `source` fails → `set -uo pipefail` kills script → exit non-zero → **Claude Code treats non-0/non-2 as... undocumented** (likely blocks)
- **Missing python3:** All Python calls return empty → FILE_PATH="" → passes exempt check → CURRENT_TASK="" → **blocks with "No active task"**
- **Stale focus.yaml (points to completed task):** Task file won't be in `active/` → **blocks**
- **Blast radius:** ALL Write/Edit operations. **This is the single most dangerous hook to break.**
- **Risk:** HIGH — python3 or YAML library issues completely lock out file editing

### H3: check-tier0.sh

- **Missing script:** `fw hook` exits 2 → **blocks ALL Bash** → agent cannot run any command
- **Bug in Python regex:** Returns empty → treated as SAFE → **fails open** (allows destructive commands)
- **Missing python3:** `COMMAND=""` → early exit 0 → **fails open** (allows destructive commands)
- **Grep pre-filter miss:** Destructive command doesn't match keywords → exits 0 → **fails open**
- **Missing .tier0-approval:** No approval check → blocks correctly
- **Missing sha256sum:** Approval hash can't be computed → approval can't be consumed → blocks permanently until approval file manually removed
- **Blast radius:** All Bash operations
- **Risk:** MEDIUM — fails open on Python failure (dangerous), but blocks all Bash if script missing

### H4: check-project-boundary.sh

- **Missing script:** `fw hook` exits 2 → **blocks ALL Write/Edit/Bash** → total lockout
- **Missing python3:** Tool name extraction fails → `TOOL_NAME=""` → falls through all checks → exit 0 → **fails open**
- **Missing realpath:** File path not resolved → comparison may fail → **could false-positive or false-negative**
- **Blast radius:** Write, Edit, AND Bash (widest PreToolUse coverage)
- **Risk:** HIGH — if script missing, total tool lockout. If Python missing, fails open (no boundary enforcement)

### H5: budget-gate.sh (CRITICAL)

- **Missing script:** `fw hook` exits 2 → **blocks ALL Write/Edit/Bash** → total lockout
- **Stale .budget-status (critical level, age > 90s):** Falls to slow path → re-reads transcript → correct behavior
- **Stale .budget-status (critical level, age < 90s):** Uses cached value → **blocks tools even if compaction just happened** → must wait 90s or delete `.budget-status`
- **Missing JSONL transcript:** Slow path returns empty → level defaults to `ok` → **fails open**
- **Missing python3:** All parsing fails → defaults to `ok` → **fails open** (no budget enforcement)
- **Corrupt .budget-status JSON:** Python parse fails → level=`unknown`, age=`999` → falls to slow path → correct behavior
- **Missing .budget-gate-counter:** Created by `mkdir -p` → works
- **Blast radius:** Write, Edit, AND Bash
- **Risk:** HIGH — false-critical locks out everything; python3 failure removes all budget protection
- **Known trap (T-271):** Stale critical used to permanently block the agent. Fixed with forced recheck, but 90s window still exists.

### H6: checkpoint.sh (PostToolUse)

- **Missing script:** `fw hook` exits 2 → for PostToolUse, this means... **advisory failure is ignored by Claude Code** (PostToolUse hooks don't block)
- **Actually no:** The `fw hook` routing uses `exit 2` for missing scripts. But PostToolUse hooks — what happens if they exit non-zero? Claude Code ignores the exit code for PostToolUse hooks. So: **silent failure, no budget monitoring**.
- **Missing transcript:** Falls back to tool-call counter → still functional (degraded)
- **Auto-handover failure:** `handover.sh` fails → logged but continues → no handover at critical budget
- **Blast radius:** Advisory only, but loss of budget warnings is serious
- **Risk:** MEDIUM — silent failure means no budget awareness

### H7: error-watchdog.sh (PostToolUse)

- **Missing script:** Silent failure (PostToolUse)
- **Missing python3:** Silent failure → no error detection
- **Blast radius:** Advisory only
- **Risk:** LOW

### H8: check-dispatch.sh (PostToolUse)

- **Missing script:** Silent failure
- **Python failure:** `|| true` at the end → always exits 0
- **Blast radius:** Advisory only
- **Risk:** LOW

### H9: check-fabric-new-file.sh (PostToolUse)

- **Missing python3 yaml module:** Python crash → `|| true` → exits 0 → silent failure
- **Missing focus.yaml:** Counter logic skipped → no scope warning
- **Missing watch-patterns.yaml:** Early exit → no fabric reminder
- **Blast radius:** Advisory only
- **Risk:** LOW

### H10: commit-cadence.sh (PostToolUse)

- **Missing python3:** `|| true` → exits 0 → no cadence warnings
- **Missing .edit-counter:** Python creates it → works
- **Blast radius:** Advisory only
- **Risk:** LOW

### H11: pre-compact.sh

- **Missing script:** `fw hook` exits 2 → **blocks /compact** (PreCompact is blocking)
- **handover.sh failure:** Error output but exit 0 → compact proceeds without handover → **context destroyed without backup**
- **Blast radius:** Manual compaction
- **Risk:** MEDIUM — handover failure before compaction = data loss

### H12/H13: post-compact-resume.sh

- **Missing script:** `fw hook` exits 2 → for SessionStart, this means... **session starts without context injection**
- **Missing LATEST.md:** No handover content → sparse context injection → agent starts blind
- **fabric.sh failure:** Caught in subshell → skips fabric overview → degraded but functional
- **Blast radius:** Session recovery quality
- **Risk:** MEDIUM

---

## Critical Finding: `fw` Resolution Chain

### The Problem

All hooks call bare `fw hook <name>`. The PATH resolves to:

```
/root/.local/bin/fw → /root/.agentic-framework/bin/fw (GLOBAL INSTALL)
```

The global `fw`'s `resolve_framework()` function works by checking if the binary itself is inside a framework repo. Since it IS inside `/root/.agentic-framework/`, it returns that as FRAMEWORK_ROOT — **ignoring the vendored copy at `/opt/999-Agentic-Engineering-Framework/.agentic-framework/`**.

This means:
1. **Hook scripts execute from `/root/.agentic-framework/agents/context/`** (global)
2. **Not from `/opt/999-Agentic-Engineering-Framework/.agentic-framework/agents/context/`** (vendored)
3. If the global install has an older/different version of a hook script, **the vendored version is silently ignored**
4. PROJECT_ROOT is correctly resolved (via `find_project_root()` in paths.sh), so data files are read from the right place
5. But FRAMEWORK_ROOT and all library code comes from the global install

### Impact

- **Version skew:** Global `fw` v1.3.0 vs vendored scripts could diverge
- **Testing gap:** Editing vendored hooks has no effect on actual hook execution until global is synced
- **Silent:** No warning when global≠vendored. `fw doctor` checks hook paths but not code divergence.

---

## Cascade Diagrams

### Cascade 1: Python3 Unavailable

```
python3 missing/broken
  ├─ H2 (check-active-task): CURRENT_TASK="" → BLOCKS Write/Edit (false positive)
  ├─ H3 (check-tier0): COMMAND="" → allows (fails OPEN — destructive commands pass)
  ├─ H4 (check-project-boundary): TOOL_NAME="" → allows (fails OPEN — boundary unenforced)
  ├─ H5 (budget-gate): defaults to ok → allows (fails OPEN — budget unenforced)
  ├─ H6 (checkpoint): no token reading → fallback to call counter (degraded)
  └─ H7-H10 (PostToolUse): silent failures (advisory gone)

  NET EFFECT: Agent can run destructive Bash commands across project boundaries
              with no budget limits, but CANNOT write/edit files.
              = Agent is locked into Bash-only mode with no safety rails.
```

### Cascade 2: paths.sh Missing/Broken

```
lib/paths.sh fails to source
  ├─ H2: set -uo pipefail → FRAMEWORK_ROOT undefined → script dies → exit 1
  │   └─ Claude Code receives non-0, non-2 → BLOCKS Write/Edit
  ├─ H3: same → BLOCKS Bash
  ├─ H4: same → BLOCKS Write/Edit/Bash
  ├─ H5: same → BLOCKS Write/Edit/Bash
  │
  └─ ALL PreToolUse hooks die → TOTAL LOCKOUT
     Agent cannot Write, Edit, OR run Bash.
     Only Read, Glob, Grep, Agent tools work.

     RECOVERY: Human must fix paths.sh externally.
     Agent CANNOT fix it (Write blocked, Bash blocked).

     = DEADLOCK
```

### Cascade 3: focus.yaml Corrupted/Missing

```
focus.yaml deleted or corrupt YAML
  ├─ H2 (check-active-task):
  │   ├─ Missing: if .framework.yaml exists → BLOCKS Write/Edit
  │   └─ Corrupt YAML: python3 returns "" → BLOCKS Write/Edit
  │
  ├─ Agent tries Bash to recreate focus.yaml:
  │   ├─ H3 (check-tier0): passes (not destructive)
  │   ├─ H4 (check-project-boundary): passes (within project)
  │   ├─ H5 (budget-gate): passes (if not critical)
  │   └─ Bash ALLOWED → `fw context focus T-XXX` can fix it
  │
  └─ RECOVERABLE via Bash (no deadlock)
```

### Cascade 4: .budget-status Stuck at Critical

```
.budget-status says "critical" + age < 90s (fresh cache)
  ├─ H5 (budget-gate): cached critical → BLOCKS Write/Edit/Bash (non-allowed)
  │
  ├─ Agent can only: Read files, run allowed commands (git commit, fw handover)
  │
  ├─ Wait 90 seconds → cache goes stale → slow path re-reads transcript
  │   ├─ If transcript confirms critical → still blocked (correct)
  │   └─ If transcript shows lower → unblocked (correct, T-271 fix)
  │
  └─ RECOVERABLE (wait 90s) or human deletes .budget-status
```

### Cascade 5: DEADLOCK — fw Binary Missing from PATH

```
`fw` not on PATH (or broken symlink)
  ├─ ALL hooks call "fw hook <name>"
  ├─ Shell: "fw: command not found" → exit 127
  │
  ├─ PreToolUse hooks: Claude Code treats exit 127 as...
  │   (undocumented, but likely blocks since it's non-0)
  │   → BLOCKS Write, Edit, Bash, EnterPlanMode
  │
  └─ TOTAL DEADLOCK — no tools work
     Agent cannot even use Bash to fix PATH
     because Bash is gated by check-tier0, boundary, and budget-gate

     RECOVERY: Human must restore `fw` on PATH or fix symlink
```

### Cascade 6: Hook Execution Order Interaction

For a Write tool call, PreToolUse hooks fire in settings.json order:
```
1. check-active-task (Write|Edit) → if blocks: Write denied, done
2. check-project-boundary (Write|Edit|Bash) → if blocks: Write denied, done
3. budget-gate (Write|Edit|Bash) → if blocks: Write denied, done

If ALL pass → Write executes → PostToolUse hooks fire:
4. checkpoint (all tools) → advisory
5. check-fabric-new-file (Write) → advisory
6. commit-cadence (Write|Edit) → advisory
```

For a Bash tool call:
```
1. check-tier0 (Bash) → if blocks: Bash denied
2. check-project-boundary (Write|Edit|Bash) → if blocks: Bash denied
3. budget-gate (Write|Edit|Bash) → if blocks: Bash denied

If ALL pass → Bash executes → PostToolUse hooks fire:
4. checkpoint (all tools) → advisory
5. error-watchdog (Bash) → advisory
```

**No circular dependencies between PreToolUse hooks** — they are independent gates that don't call each other.

---

## fw Calls Inside Hooks

**Do any hooks call `fw` internally?** Checked all 13 scripts:

| Script | Calls `fw`? | Details |
|--------|-------------|---------|
| pre-compact.sh | YES (indirectly) | Calls `$FRAMEWORK_ROOT/agents/handover/handover.sh` which calls `fw git commit` |
| post-compact-resume.sh | YES (indirectly) | Calls `$PROJECT_ROOT/agents/fabric/fabric.sh overview` |
| All other hooks | NO | Use `lib/paths.sh` directly, don't invoke `fw` |

The `pre-compact.sh` → `handover.sh` → `fw git commit` chain is the only case where a hook calls `fw`. Since `handover.sh` uses `$FRAMEWORK_ROOT/agents/git/git.sh` directly (not bare `fw`), there's no PATH resolution risk here.

---

## Summary of Findings

### CRITICAL Issues

1. **DEADLOCK on paths.sh failure:** If `lib/paths.sh` is broken, ALL PreToolUse hooks die with non-zero exit. Agent is locked out of Write, Edit, AND Bash. Cannot self-heal. (No current mitigation.)

2. **DEADLOCK on `fw` missing from PATH:** All hooks fail with "command not found". Total tool lockout. Cannot self-heal.

3. **Global vs Vendored fw divergence:** Hooks execute scripts from `/root/.agentic-framework/` (global), not from the vendored copy in the project. Silent version skew.

### HIGH Issues

4. **Python3 failure inverts safety:** check-active-task blocks (false positive), but check-tier0, check-project-boundary, and budget-gate all fail OPEN. Agent can run destructive commands without boundaries or budget limits, but cannot write files. Worst-case combination.

5. **90-second stale-critical window (budget-gate):** After compaction, `.budget-status` may still say "critical" for up to 90 seconds. Agent is locked out of all tools during this window.

### MEDIUM Issues

6. **pre-compact handover failure → data loss:** If handover.sh fails during pre-compact, compaction proceeds and destroys context with no backup. Exit 0 regardless.

7. **PostToolUse silent failures:** All PostToolUse hooks fail silently. Loss of budget monitoring, error detection, dispatch guards, and cadence warnings.

### Structural Observations

8. **No hook self-test:** No mechanism exists to verify all hooks are functional at session start. `fw doctor` checks paths exist but doesn't test execution.

9. **All hooks depend on python3:** 10 of 13 hooks use python3 for JSON/YAML parsing. If python3 is broken, the entire enforcement layer is compromised.

10. **Exit code semantics undocumented for non-0/non-2:** Claude Code documents exit 0 (allow) and exit 2 (block) for PreToolUse. What happens with exit 1, 127, 139? Likely blocks, but undefined behavior.

---

## Recommendations

1. **Add `set +e` guard around `source lib/paths.sh`** in all hooks, with fallback to manual PROJECT_ROOT detection. Prevents deadlock on paths.sh failure.

2. **Add hook smoke test to `fw doctor`** or `fw context init`: run each hook with synthetic stdin, verify exit 0 for normal case.

3. **Fix `fw hook` resolution:** When run from a project with vendored framework, `fw hook` should prefer vendored scripts over global ones. The `resolve_framework()` priority is wrong for this case.

4. **Standardize python3 failure behavior:** All PreToolUse hooks should fail in the SAME direction (open or closed) when python3 is unavailable. Currently: H2 fails closed, H3/H4/H5 fail open.

5. **Add TTL to .budget-status with automatic cleanup:** Instead of 90s stale window, delete the file on compaction or session start.
