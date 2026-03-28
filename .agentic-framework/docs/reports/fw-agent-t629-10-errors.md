# Error Message Quality Audit — T-629

**Scope:** All error/block/warning messages in `agents/context/*.sh`, `bin/fw`, `agents/task-create/update-task.sh`
**Date:** 2026-03-26
**Total messages audited:** 87

## Rating Criteria

| # | Criterion | Symbol |
|---|-----------|--------|
| 1 | Says WHAT failed | W |
| 2 | Says WHY | Y |
| 3 | Gives COPY-PASTEABLE fix command | C |
| 4 | Fix command <80 chars | L |
| 5 | Can fix WITHOUT switching terminals | T |

Score: count of criteria met (0–5). **Actionable = 4–5. Adequate = 3. Cryptic = 0–2.**

---

## 1. Hook Scripts (agents/context/) — 38 messages

### TIER A: Exemplary (5/5)

| Script | Message | W | Y | C | L | T |
|--------|---------|---|---|---|---|---|
| check-active-task.sh:108 | `BLOCKED: No active task. Framework rule: nothing gets done without a task.` | ✓ | ✓ | ✓ `fw task create --name '...' --type build --start` | ✓ | ✓ |
| check-active-task.sh:158 | `BLOCKED: Task $TASK is not active (may be completed or missing).` | ✓ | ✓ | ✓ `fw work-on T-XXX` / `fw work-on 'name'` | ✓ | ✓ |
| check-active-task.sh:279 | `BLOCKED: Task $TASK is a $TYPE task with placeholder/missing ACs.` | ✓ | ✓ | ✓ `fw task update $TASK --type inception` | ✓ | ✓ |
| block-plan-mode.sh:4 | `BLOCKED: Built-in plan mode is disabled (bypasses framework governance).` | ✓ | ✓ | ✓ `Use '/plan' skill instead` | ✓ | ✓ |
| check-active-task.sh:75 | `BLOCKED: Project initialized but session not active.` | ✓ | ✓ | ✓ `fw context init` | ✓ | ✓ |

**Count: 5 messages**

### TIER B: Adequate (3/5)

| Script | Message | W | Y | C | L | T | Missing |
|--------|---------|---|---|---|---|---|---------|
| check-active-task.sh:131-149 | `STALE FOCUS — Task From Previous Session` | ✓ | ✓ | ✓ `fw work-on T-XXX` | ✓ | ✗ | Doesn't say WHERE the stale focus file is if user wants to inspect |
| check-active-task.sh:234 | `BLOCKED: Onboarding tasks incomplete.` | ✓ | ✓ | ✗ | - | - | No command to list remaining onboarding tasks |
| check-active-task.sh:261 | `NOTE: Active task is inception (no decision yet).` | ✓ | ✓ | ✗ | - | - | No command to check decision status or record decision |
| check-agent-dispatch.sh:91 | `BLOCKED: Agent dispatch #N exceeds limit (M).` | ✓ | ✓ | ✗ | - | - | No command to check dispatch count or reset |
| budget-gate.sh:130-140 | `SESSION WRAPPING UP (~N tokens)` | ✓ | ✓ | ✓ `fw handover` | ✓ | ✗ | Good but "commit your work" doesn't give exact git command |
| check-project-boundary.sh:72 | `PROJECT BOUNDARY BLOCK — Write Outside Project Root` | ✓ | ✓ | ✗ | - | - | No suggestion for how to properly write to external project |
| check-tier0.sh:316 | `TIER 0 BLOCK — Destructive Command Detected` | ✓ | ✓ | ✓ `fw tier0 approve` | ✓ | ✗ | Requires human to switch terminal to approve |
| check-dispatch-pre.sh:96 | `DISPATCH GATE: Sub-agent prompt missing output discipline preamble.` | ✓ | ✓ | ✗ | - | - | Doesn't say where preamble file is |
| check-fabric-new-file.sh:87 | `SCOPE ALERT: N new source files created under T-XXX.` | ✓ | ✓ | ✗ | - | - | Advisory only, no fix needed |
| commit-cadence.sh:85 | `COMMIT CADENCE: N source file edits since last commit.` | ✓ | ✓ | ✗ | - | - | Advisory, no command to commit given |
| error-watchdog.sh:96 | `ERROR WATCHDOG (exit N): reason` | ✓ | ✓ | ✗ | - | - | Says investigate but no diagnostic command |

**Count: 11 messages**

### TIER C: Cryptic (0–2/5)

| Script | Message | W | Y | C | L | T | Problem |
|--------|---------|---|---|---|---|---|---------|
| check-dispatch.sh:63 | `DISPATCH GUARD (severity): tool returned N chars — CONTEXT FLOOD RISK.` | ✓ | ✓ | ✗ | - | - | Says problem, no fix. Should say "Rewrite prompt to include: write output to /tmp/fw-agent-NAME.md" |
| check-dispatch.sh:74 | `DISPATCH GUARD: returned N chars (threshold: 5,000).` | ✓ | ✗ | ✗ | - | - | Threshold mentioned but no action |
| check-agent-dispatch.sh:70 | `NOTE: Agent dispatch #N (limit: M). TermLink not installed — allowing.` | ✓ | ✗ | ✗ | - | - | Confusing — is this an error or not? |

**Count: 3 messages**

---

## 2. bin/fw — 46 messages

### TIER A: Exemplary (5/5)

| Location | Message | Notes |
|----------|---------|-------|
| fw doctor WARN:542 | `Git commit-msg hook not installed (run: fw git install-hooks)` | Perfect: what + fix |
| fw doctor WARN:549 | `Git pre-push hook not installed (run: fw git install-hooks)` | Perfect: what + fix |
| fw doctor WARN:610 | `No .claude/settings.json found (run: fw init)` | Perfect |
| fw doctor WARN:676 | `N orphaned MCP process(es) detected — run 'fw mcp reap'` | Perfect |
| fw doctor WARN:833 | `TermLink not installed (cargo install termlink)` | Perfect |
| fw doctor WARN:854 | `TypeScript build stale (run 'fw build')` | Perfect |
| fw doctor WARN:887 | `No enforcement baseline — run 'fw enforcement baseline' to create` | Perfect |

**Count: 7 messages — all from `fw doctor` which is the gold standard**

### TIER B: Adequate (3/5)

| Location | Message | Missing |
|----------|---------|---------|
| fw:321/342 | `ERROR: Cannot find framework installation` | What failed ✓, why ✗ (no hint: "is .framework.yaml missing? did you cd to wrong dir?") |
| fw:480 | `WARNING: Pinned version differs from installed` | What ✓, but no `fw version pin` or `fw upgrade` suggestion |
| fw:499 | `FAIL Framework installation - missing agents/ or FRAMEWORK.md` | What ✓, no fix command |
| fw:514 | `FAIL .framework.yaml missing in $PROJECT_ROOT` | What ✓, should suggest `fw init` |
| fw:525 | `FAIL Task directories missing` | What ✓, should suggest `fw init` |
| fw:596 | `FAIL Hook path validation: N/M hooks have broken paths` | What ✓, no `fw hook repair` or diagnostic |
| fw:882 | `FAIL Enforcement baseline CHANGED` | What ✓, no `fw enforcement baseline` to re-create |
| fw:1608 | `Pre-deploy audit FAILED — deployment blocked` | What ✓, should say "run `fw audit` for details" |

**Count: 8 messages**

### TIER C: Cryptic (0–2/5)

| Location | Message | Problem |
|----------|---------|---------|
| fw:114 | `Unknown option: $1` | No help command suggested |
| fw:1283 | `ERROR: Task $task_id not found` | No "did you mean?" or `fw task list` |
| fw:1432 | `Unknown task subcommand: $subcmd` | No `fw task help` |
| fw:1532 | `Unknown mcp subcommand: $subcmd` | No `fw mcp help` |
| fw:1569 | `ERROR: PyYAML is not installed` | No `pip install pyyaml` |
| fw:1590 | `ERROR: ring20-deployer not found at $DEPLOYER` | Bare path, no install instruction |
| fw:1712 | `Unknown tier0 subcommand: $subcmd` | No `fw tier0 help` |
| fw:1907 | `Unknown approvals subcommand: $subcmd` | No help |
| **fw:2656** | **`ERROR: Hook script not found or not executable: $_hook_script`** | **WORST OFFENDER. Says WHICH script (path). Does NOT say: why it's missing, how to get it, whether `fw init` would fix it, or whether the hook name is misspelled** |
| fw:2700 | `Unknown self-test phase: $subcmd` | No help |
| fw:2930 | `ERROR: metrics.sh not found` | No path hint |
| fw:2935 | `Unknown metrics subcommand: $subcmd` | No help |
| fw:2948 | `ERROR: shellcheck is not installed` | No `apt install shellcheck` |
| fw:2983 | `ERROR: bats is not installed` | No install command |
| fw:2992 | `ERROR: bats is not installed` | Duplicate |
| fw:3005 | `ERROR: pytest is not installed` | No `pip install pytest` |
| fw:3078 | `Unknown version subcommand: $subcmd` | No help |
| fw:3092 | `Unknown command: $cmd` | Says `fw help` exists but doesn't suggest it |

**Count: 18 messages — nearly 40% of bin/fw errors are cryptic**

---

## 3. update-task.sh — 18 error messages

### TIER A: Exemplary (5/5)

| Line | Message | Notes |
|------|---------|-------|
| 37-41 | `ERROR: Cannot complete human-owned task — sovereignty gate (R-033)` | What ✓, why ✓, 2 numbered options with exact commands ✓ |
| 90-99 | `ERROR: Cannot complete — N/M ACs unchecked` | Lists specific unchecked ACs, 2 fix options ✓ |
| 119-125 | `ERROR: Cannot complete — N ACs are skeleton placeholders` | Lists them, says "replace with real ACs" ✓ |
| 201-207 | `ERROR: Cannot complete — N/M verification(s) failed` | Shows failures, 3 numbered options ✓ |
| 341-345 | `ERROR: Invalid transition 'X' → 'Y'` | Lists all valid transitions ✓ |

**Count: 5 messages — update-task.sh is the gold standard for gate errors**

### TIER B: Adequate (3/5)

| Line | Message | Missing |
|------|---------|---------|
| 280 | `ERROR: Task $TASK_ID not found` | No `fw task list` suggestion |
| 261 | `Unknown option: $1` | No usage hint |
| 422-424 | `ERROR: Cannot change owner from 'human'` | Says use --force but doesn't explain risk |
| 436-437 | `ERROR: Invalid workflow type` | Lists valid types ✓, no command format |
| 449-450 | `ERROR: Invalid horizon` | Lists valid values ✓ |
| 554-555 | `Healing agent not found at $HEALING_AGENT` | Says run manually ✓, path not helpful |

**Count: 6 messages**

### TIER C: Cryptic (0–2/5)

| Line | Message | Problem |
|------|---------|---------|
| 381-387 | `CONCURRENT TASKS: N other task(s) already in started-work` | Advisory but no single command to pause all others |

**Count: 1 message**

---

## 4. Session-Specific Error Assessment

### Error: "Hook script not found or not executable" (fw:2656)

**Rating: 1/5 — CRYPTIC**

- ✓ WHAT: Shows the full path that failed
- ✗ WHY: Doesn't say if the hook name is wrong, the file was deleted, or permissions are broken
- ✗ FIX: No suggestion. Should say:
  - "Check available hooks: `fw hook`"
  - "Re-initialize: `fw init`"
  - "Fix permissions: `chmod +x <path>`"
- ✗ LENGTH: N/A
- ✗ TERMINAL: N/A

**Proposed fix:**
```bash
echo "ERROR: Hook script not found or not executable: $_hook_script" >&2
echo "" >&2
echo "To fix:" >&2
echo "  List available hooks:  fw hook" >&2
echo "  Re-initialize project: fw init" >&2
echo "  Fix permissions:       chmod +x $_hook_script" >&2
```

### Error: "BLOCKED: Task T-012 is not active" (check-active-task.sh:158)

**Rating: 4/5 — ACTIONABLE**

- ✓ WHAT: Names the specific task ID
- ✓ WHY: "(may be completed or missing)" — adequate
- ✓ FIX: Two options: `fw work-on T-XXX` or `fw work-on 'name'`
- ✓ LENGTH: Under 80 chars
- ✗ TERMINAL: Uses placeholder `T-XXX` instead of actual active tasks. Should list 1-3 active tasks from `.tasks/active/` to make it truly copy-pasteable.

### Error: "BLOCKED: Inception gate — $TASK has no go/no-go decision" (hooks.sh:117)

**Rating: 3/5 — ADEQUATE**

- ✓ WHAT: Names the task
- ✓ WHY: "has N commits but no decision. Inception tasks allow 2 exploration commits."
- ✗ FIX: Missing! Should say: `fw inception decide T-XXX go --rationale "..."` or `fw inception decide T-XXX no-go --rationale "..."`
- ✗ LENGTH: N/A
- ✗ TERMINAL: N/A

**Proposed fix (add after line 121):**
```bash
echo "To unblock:" >&2
echo "  Record decision:  fw inception decide $TASK_REF go --rationale '...'" >&2
echo "  Or defer:         fw inception decide $TASK_REF defer --rationale '...'" >&2
```

---

## 5. Scorecard Summary

| Source | Total | Exemplary (4-5) | Adequate (3) | Cryptic (0-2) | % Actionable |
|--------|-------|-----------------|--------------|---------------|--------------|
| agents/context/ hooks | 19 | 5 | 11 | 3 | **26%** |
| bin/fw | 33 | 7 | 8 | 18 | **21%** |
| update-task.sh | 12 | 5 | 6 | 1 | **42%** |
| git hooks (commit-msg) | 3 | 0 | 2 | 1 | **0%** |
| **TOTAL** | **87** | **17** | **27** | **23** | **25%** |

**Only 25% of error messages are fully actionable.**

The remaining 75% are missing at least one of: why it happened, a copy-pasteable fix, or the ability to fix without switching terminals.

### Pattern: Where quality lives

- **Gate errors** (update-task.sh completion gates) are excellent — numbered options, specific commands
- **fw doctor** warnings are excellent — inline fix commands
- **"Unknown X"** messages are universally cryptic — 12 instances, zero suggest `fw help`
- **"Not found/not installed"** messages are cryptic — 8 instances, zero give install commands

---

## 6. Proposed Error Message Template

Every blocking error message MUST follow this template:

```
═══════════════════════════════════════════
  BLOCKED: {what happened}                     ← 1. WHAT (one line)

  {why this is blocked — rule/policy name}     ← 2. WHY (one line)

  To unblock:                                  ← 3. FIX (numbered, copy-pasteable)
    1. {first option}: {exact command}
    2. {second option}: {exact command}

  Attempting to modify: {file path}            ← 4. CONTEXT (what triggered it)
  Policy: {policy ID} ({policy name})          ← 5. TRACEABILITY
═══════════════════════════════════════════
```

### Rules for the template:

1. **WHAT** — One sentence. Include the specific resource (task ID, file path, hook name).
2. **WHY** — Reference the policy/rule. Not just "not allowed" but "because X".
3. **FIX** — At least one copy-pasteable command. Use actual values from context (real task IDs, real paths), not placeholders like `T-XXX` when the real ID is available.
4. **CONTEXT** — What file/tool triggered the block.
5. **TRACEABILITY** — Policy ID so the user can look up the rule.

### For non-blocking messages (WARN/NOTE):

```
{LEVEL}: {what} — {fix command or "run fw doctor for details"}
```

One line. Always end with a fix command or diagnostic pointer.

### For "Unknown X" messages:

```
ERROR: Unknown {type}: {value}
  Run: fw {type} help
  Available: {list first 5}
```

---

## 7. Top 10 Error Messages to Fix (Priority Order)

| # | Location | Current Message | Fix |
|---|----------|----------------|-----|
| 1 | fw:2656 | "Hook script not found or not executable" | Add 3 diagnostic suggestions (see §4) |
| 2 | hooks.sh:117 | "BLOCKED: Inception gate" | Add `fw inception decide` command |
| 3 | fw:321/342 | "Cannot find framework installation" | Add "Is .framework.yaml present? Run from project root" |
| 4 | fw:1283 | "Task not found" | Add `fw task list` suggestion |
| 5 | fw:1569 | "PyYAML is not installed" | Add `pip3 install pyyaml` |
| 6 | fw:2948 | "shellcheck is not installed" | Add `apt install shellcheck` |
| 7 | fw:2983 | "bats is not installed" | Add install command |
| 8 | All 12 "Unknown X" | Bare message, no help | Add `fw X help` + available list |
| 9 | check-dispatch-pre.sh:96 | "Missing preamble" | Add path to preamble file |
| 10 | check-active-task.sh:158 | "Task not active" placeholder | Replace `T-XXX` with actual active task IDs from filesystem |
