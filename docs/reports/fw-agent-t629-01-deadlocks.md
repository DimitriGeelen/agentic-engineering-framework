# Deadlock Analysis: Agentic Engineering Framework Hook System

**Task:** T-629 | **Date:** 2026-03-26 | **Scope:** Every path to total tool blockage

---

## Hook Architecture Summary

### PreToolUse Hooks (gate tool execution — exit 0=allow, exit 2=block)

| Hook | Matcher | Blocks | Purpose |
|------|---------|--------|---------|
| `block-plan-mode` | EnterPlanMode | EnterPlanMode | Prevent plan mode bypass |
| `check-active-task` | Write\|Edit | Write, Edit | Task-first enforcement |
| `check-tier0` | Bash | Bash | Destructive command gate |
| `check-project-boundary` | Write\|Edit\|Bash | Write, Edit, Bash | Cross-project prevention |
| `budget-gate` | Write\|Edit\|Bash | Write, Edit, Bash | Context budget enforcement |

### Execution Order Per Tool

**Write/Edit** → check-active-task → check-project-boundary → budget-gate (3 gates)
**Bash** → check-tier0 → check-project-boundary → budget-gate (3 gates)
**Read/Glob/Grep/Agent** → NO hooks (always available)

### PostToolUse Hooks (advisory only — cannot block)

| Hook | Matcher | Purpose |
|------|---------|---------|
| `checkpoint` | * (all) | Budget warnings, auto-handover |
| `error-watchdog` | Bash | Error pattern detection |
| `check-dispatch` | Task\|TaskOutput | Sub-agent result management |
| `check-fabric-new-file` | Write | Component registration reminder |
| `commit-cadence` | Write\|Edit | Commit frequency reminder |

---

## Hook Failure Modes

### What happens when a hook script is missing?

The routing mechanism (`fw hook <name>`) in `bin/fw` lines 2641-2660:
1. Resolves to `$AGENTS_DIR/context/${name}.sh`
2. Checks if script is executable (`[ ! -x "$_hook_script" ]`)
3. **If missing/not executable: exits with code 2 → BLOCKS the tool**

This is the single most dangerous failure mode in the framework.

### What happens when `fw` itself is broken/missing?

If `fw` is not in PATH, the shell returns **exit code 127** (command not found).

**Claude Code PreToolUse exit code semantics:**
- Exit 0 = allow
- Exit 2 = block (stderr shown to agent)
- Exit 1/127/other = **UNDOCUMENTED** — behavior depends on Claude Code implementation

**If non-2 exit = block:** ALL tools gated by ANY hook become blocked. TOTAL DEADLOCK.
**If non-2 exit = allow:** ALL governance is bypassed. TOTAL GOVERNANCE FAILURE.

### What happens when python3 is missing?

| Hook | python3 failure behavior | Result |
|------|--------------------------|--------|
| check-active-task | YAML parsing fails → CURRENT_TASK empty → **blocks** | Write/Edit BLOCKED |
| check-tier0 | JSON parsing fails → command empty → allows | Bash ALLOWED |
| check-project-boundary | JSON parsing fails → tool_name empty → allows | All ALLOWED |
| budget-gate | All parsing fails → defaults to "ok" → allows | All ALLOWED |

**Result:** Write/Edit blocked, Bash available. Partial deadlock.

### What happens when lib/tasks.sh is missing?

`paths.sh` sources it with `|| true`, but `find_task_file()` becomes undefined.
`check-active-task.sh` calls `find_task_file` on lines 126 and 155.
With `set -uo pipefail`, undefined function causes crash (exit 127).
**Result:** Same as "fw broken" — depends on Claude Code's handling of exit 127.

---

## Complete Deadlock Matrix

### D-01: Budget Critical Level (>=190K tokens, ~95%)

| Tool | Status | Reason |
|------|--------|--------|
| Write to source files | **BLOCKED** | budget-gate exit 2 |
| Edit source files | **BLOCKED** | budget-gate exit 2 |
| Bash (general) | **BLOCKED** | budget-gate exit 2 |
| Write to .context/.tasks/.claude | ALLOWED | budget-gate exempt path |
| Bash (git commit/add) | ALLOWED | budget-gate allowed cmd |
| Bash (fw handover/task/resume) | ALLOWED | budget-gate allowed cmd |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

**Recovery:** `fw handover --commit` via Bash → session end → fresh session.
**Human Required?** No — agent can self-recover with wrap-up commands.
**Circular?** No — wrap-up paths are explicitly whitelisted.

### D-02: No Active Task (focus.yaml empty or missing)

| Tool | Status | Reason |
|------|--------|--------|
| Write/Edit (source files) | **BLOCKED** | check-active-task exit 2 |
| Write/Edit (.context/.tasks/.claude) | ALLOWED | check-active-task exempt |
| Bash | ALLOWED | check-active-task only gates Write\|Edit |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

**Recovery:** `fw task create --name "..." --type build --start` via Bash.
**Human Required?** No.
**Circular?** No — Bash is not gated by check-active-task.

### D-03: Stale Focus (previous session stamp)

| Tool | Status | Reason |
|------|--------|--------|
| Write/Edit (source files) | **BLOCKED** | check-active-task exit 2 (T-560) |
| Write/Edit (.context/.tasks/.claude) | ALLOWED | check-active-task exempt |
| Bash | ALLOWED | Not gated |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

**Recovery:** `fw work-on T-XXX` via Bash (re-stamps focus to current session).
**Human Required?** No.
**Circular?** No.

### D-04: Placeholder ACs on Build Task (G-020)

| Tool | Status | Reason |
|------|--------|--------|
| Write/Edit (source files) | **BLOCKED** | check-active-task G-020 gate exit 2 |
| Write/Edit (.tasks/active/T-XXX.md) | ALLOWED | check-active-task exempt path |
| Bash | ALLOWED | Not gated |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

**Recovery:** Edit task file directly (exempt path) to replace placeholder ACs.
**Human Required?** No.
**Circular?** No — task files are exempt from the task gate.

### D-05: Onboarding Tasks Incomplete (T-535)

| Tool | Status | Reason |
|------|--------|--------|
| Write/Edit (non-onboarding work) | **BLOCKED** | check-active-task onboarding gate exit 2 |
| Write/Edit (onboarding task files) | ALLOWED | Exempt path |
| Bash | ALLOWED | Not gated |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

**Recovery:** `fw work-on T-001` (onboarding task) via Bash, or `fw onboarding skip`.
**Human Required?** No.
**Circular?** No.

### D-06: Task Status Not Workable (captured/work-completed)

| Tool | Status | Reason |
|------|--------|--------|
| Write/Edit (source files) | **BLOCKED** | check-active-task status gate exit 2 |
| Write/Edit (.context/.tasks) | ALLOWED | Exempt path |
| Bash | ALLOWED | Not gated |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

**Recovery:** `fw work-on T-XXX` (sets to started-work) or `fw work-on "new task"`.
**Human Required?** No.
**Circular?** No.

### D-07: Tier 0 — Destructive Command Detected

| Tool | Status | Reason |
|------|--------|--------|
| Write/Edit | ALLOWED | check-tier0 only gates Bash |
| Bash (destructive cmd) | **BLOCKED** | check-tier0 exit 2 |
| Bash (non-destructive) | ALLOWED | check-tier0 allows |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

**Recovery:** `fw tier0 approve` via Bash (approval token, 5-min TTL).
**Human Required?** YES — by design. Human must approve destructive operations.
**Circular?** No — `fw tier0 approve` is itself a non-destructive command.

### D-08: Project Boundary — File Outside PROJECT_ROOT

| Tool | Status | Reason |
|------|--------|--------|
| Write/Edit (outside project) | **BLOCKED** | check-project-boundary exit 2 |
| Write/Edit (inside project) | ALLOWED | In allowed zone |
| Write/Edit (/tmp/*) | ALLOWED | Explicit exception |
| Write/Edit (/root/.claude/*) | ALLOWED | Explicit exception |
| Bash (cd outside project + write) | **BLOCKED** | check-project-boundary exit 2 |
| Bash (in-project commands) | ALLOWED | Not detected |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

**Recovery:** Work within project root. Cross-project work requires human.
**Human Required?** Yes, for cross-project operations.
**Circular?** No.

---

## CRITICAL DEADLOCK SCENARIOS (Total Tool Blockage)

### **C-01: `fw` Binary Broken/Missing from PATH**

**Trigger:** `fw` not in PATH, `bin/fw` corrupted, or framework directory moved.

| Tool | Status | Reason |
|------|--------|--------|
| Write | **DEPENDS** | check-active-task → `fw hook` → exit 127 |
| Edit | **DEPENDS** | check-active-task → `fw hook` → exit 127 |
| Bash | **DEPENDS** | check-tier0 → `fw hook` → exit 127 |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

**If Claude Code treats exit 127 as BLOCK:** **TOTAL DEADLOCK**
- Agent cannot Write, Edit, or run Bash
- Agent cannot fix `fw` because all modification tools are blocked
- Only Read/Glob/Grep/Agent tools available — completely read-only
- **Human must fix manually** (re-add fw to PATH, fix binary)

**If Claude Code treats exit 127 as ALLOW:** Total governance bypass
- All hooks silently fail, all tools execute without checks

**Verdict: UNKNOWN** — depends on undocumented Claude Code behavior for non-0/non-2 exit codes.
**This is the #1 systemic risk in the framework.**

### **C-02: python3 Missing/Broken**

**Trigger:** python3 not installed, broken, or not in PATH.

| Tool | Status | Reason |
|------|--------|--------|
| Write/Edit (source files) | **BLOCKED** | check-active-task can't parse YAML → assumes no task |
| Write/Edit (.context/.tasks) | **BLOCKED** | check-active-task can't parse file_path → exemption logic fails |
| Bash | ALLOWED | check-tier0/boundary/budget all fail open |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

Wait — let me re-examine the exempt path logic in check-active-task.sh when python3 is missing:

```bash
FILE_PATH=$(echo "$INPUT" | python3 -c "..." 2>/dev/null)
```

If python3 fails, FILE_PATH is empty string. Then:
```bash
case "$FILE_PATH" in
    "$PROJECT_ROOT"/.context/*|...) exit 0 ;;
esac
```
Empty string doesn't match any pattern → falls through to YAML parsing.
YAML parsing also uses python3 → fails → CURRENT_TASK empty → **BLOCKS**.

**So even exempt paths (.context/, .tasks/) are BLOCKED when python3 is missing.**

This is worse than D-02 because the Bash recovery path (`fw task create`) itself depends on python3 internally.

**Recovery:**
1. Agent uses Bash to install python3 (`apt install python3`) — if package manager works
2. Agent uses Bash to manually write focus.yaml without python3 (`echo "current_task: T-XXX" > .context/working/focus.yaml`)

**Human Required?** Possibly not — Bash IS available, and manual file creation might work. But fragile.

### **C-03: Multiple Hook Scripts Missing**

**Trigger:** Framework agents/context/ directory deleted, corrupted, or out of sync.

If `check-active-task.sh`, `check-tier0.sh`, `check-project-boundary.sh`, or `budget-gate.sh` are missing:
`fw hook <name>` does `[ ! -x "$_hook_script" ]` → exit 2 → **BLOCKS**.

| Missing Script | Blocked Tools |
|----------------|---------------|
| check-active-task.sh | Write, Edit |
| check-tier0.sh | Bash |
| check-project-boundary.sh | Write, Edit, Bash |
| budget-gate.sh | Write, Edit, Bash |

**If check-project-boundary.sh OR budget-gate.sh is missing:** ALL three tools (Write/Edit/Bash) blocked.
**If ALL four are missing:** TOTAL DEADLOCK — same as C-01.

**Recovery:** Human must restore the files (git checkout, etc.)
**Human Required?** YES — agent cannot Write, Edit, or Bash.

### **C-04: Budget Critical + Stale Focus (Compound)**

**Trigger:** Session starts with stale focus from previous session AND context is already at 95%.

| Tool | Status | Reason |
|------|--------|--------|
| Write/Edit (source) | **BLOCKED** | check-active-task (stale focus, exit 2) |
| Write/Edit (.context) | ALLOWED | check-active-task exempt, budget-gate exempt |
| Bash (`fw work-on`) | **MAYBE BLOCKED** | budget-gate may block if not in allowed pattern |

**Critical question:** Does `fw work-on T-XXX` match the budget-gate allowed command pattern?
```python
re.search(r'fw\s+(handover|git|context\s+init|resume|task)', command)
```
`fw work-on` does NOT match `fw task` — `work-on` is a separate fw subcommand!

**Result:** At budget critical, `fw work-on` is BLOCKED by budget-gate.
But `fw task update T-XXX --status started-work` would match `fw task` → ALLOWED.
And manual focus: `echo "current_task: T-XXX" > .context/working/focus.yaml` → BLOCKED (not in allowed Bash patterns).

However: Write to `.context/working/focus.yaml` is ALLOWED (exempt path + budget-gate wrapup-write).
Agent CAN manually edit focus.yaml via Write tool to fix the stale focus, then proceed with wrap-up.

**Recovery:** Write directly to `.context/working/focus.yaml` (exempt Write path).
**Human Required?** No — but agent must know the workaround (not documented).

### **C-05: Budget Critical + No Active Task (Compound)**

**Trigger:** Session starts at 95%+ context with no task set.

| Tool | Status | Reason |
|------|--------|--------|
| Write/Edit (source) | **BLOCKED** | check-active-task (no task, exit 2) |
| Write/Edit (.context/.tasks) | ALLOWED | Exempt from check-active-task, exempt from budget-gate |
| Bash (`fw task create`) | ALLOWED | Matches `fw task` in budget-gate |
| Read/Glob/Grep/Agent | ALLOWED | No hooks |

**Recovery:** `fw task create --name "wrap-up" --type build --start` via Bash → wrap up → handover.
**Human Required?** No.
**Circular?** No — `fw task` is explicitly in the budget-gate allowlist.

### **C-06: .context/working Directory Deleted**

**Trigger:** `.context/working/` removed (accident, git clean, etc.)

check-active-task.sh line 67-69:
```bash
if [ ! -d "$PROJECT_ROOT/.context/working" ]; then
    exit 0
fi
```

**Result:** check-active-task ALLOWS everything (bootstrap mode).
This is a **governance bypass**, not a deadlock.
If `.context/working/` is gone, no task enforcement occurs.

### **C-07: Circular — focus.yaml Corrupt YAML**

**Trigger:** focus.yaml exists but contains invalid YAML.

python3 YAML parsing (check-active-task.sh line 84-98) has `try/except`:
```python
except:
    print(' ')
```
On parse failure, prints empty → CURRENT_TASK empty → **BLOCKS Write/Edit**.

**Recovery:** Agent uses Bash to overwrite focus.yaml: `echo "current_task: T-XXX" > .context/working/focus.yaml`
But wait — this Bash command writes to .context/ which IS in budget-gate allowed patterns? Let's check:
`echo\s+0\s*>` — no, this only matches `echo 0 >`. General echo+redirect is NOT in the allowed list.

At non-critical budget: Bash is not blocked by budget-gate → echo works.
At critical budget: Bash IS blocked → agent must use Write tool to .context/ (exempt path).

**Recovery:** Write tool to `.context/working/focus.yaml` (exempt from check-active-task, exempt from budget-gate wrapup).
**Human Required?** No.

---

## Deadlock Recovery Matrix

| ID | Failure | Write | Edit | Bash | Recovery Path | Human? |
|----|---------|-------|------|------|---------------|--------|
| D-01 | Budget critical | **X** | **X** | **X*** | fw handover via allowed Bash | No |
| D-02 | No active task | **X** | **X** | OK | fw task create via Bash | No |
| D-03 | Stale focus | **X** | **X** | OK | fw work-on via Bash | No |
| D-04 | Placeholder ACs | **X** | **X** | OK | Edit task file (exempt) | No |
| D-05 | Onboarding incomplete | **X** | **X** | OK | fw onboarding skip via Bash | No |
| D-06 | Task not workable | **X** | **X** | OK | fw work-on via Bash | No |
| D-07 | Tier 0 destructive | OK | OK | **X*** | fw tier0 approve | **YES** |
| D-08 | Outside project root | **X** | **X** | **X*** | Stay in project | **YES** |
| **C-01** | **fw binary broken** | **X?** | **X?** | **X?** | **None** | **YES** |
| **C-02** | **python3 missing** | **X** | **X** | OK | apt install python3 | Probably no |
| **C-03** | **Hook scripts missing** | **X** | **X** | **X** | **None** | **YES** |
| **C-04** | Budget critical + stale focus | **X** | **X** | **X*** | Write to focus.yaml (exempt) | No |
| **C-05** | Budget critical + no task | **X** | **X** | **X*** | fw task create (allowed) | No |
| **C-07** | Corrupt focus.yaml | **X** | **X** | OK | Write to focus.yaml (exempt) | No |

Legend: **X** = blocked, **X*** = partially blocked (some commands allowed), OK = available

---

## Circular Deadlock Chains

### Chain 1: Hook Config → Settings Protection → Human-Only
```
Agent wants to fix broken hook → needs to edit .claude/settings.json
→ check-active-task blocks .claude/settings.json (B-005)
→ B-005 is UNCONDITIONAL — no task, no approval, no bypass
→ PERMANENTLY BLOCKED for agent
→ Human must edit settings.json manually
```
**This is by design (B-005), not a bug.**

### Chain 2: Missing Hook Script → fw hook exit 2 → Tool Blocked → Can't Restore Script
```
budget-gate.sh missing → fw hook budget-gate → exit 2 → ALL tools blocked
→ To restore: need Write (blocked) or Bash git checkout (blocked)
→ TOTAL DEADLOCK
```
**This is a real vulnerability. Single file deletion = total lockout.**

### Chain 3: fw Binary Broken → All Hooks Fail → Unknown Behavior
```
fw not in PATH → all hooks return exit 127
→ Claude Code behavior for exit 127 is UNDOCUMENTED
→ Either TOTAL DEADLOCK or TOTAL GOVERNANCE BYPASS
→ Both outcomes are catastrophic
```
**This is the highest-risk unknown in the system.**

---

## Undocumented Behavior: Exit Code 1 from Hooks

Several paths produce exit code 1 (not 0 or 2):
- `set -uo pipefail` + undefined variable/function → exit 1 or 127
- `fw hook` with no arguments → exit 1
- Source file missing → bash exit 1

Claude Code's behavior for exit 1 in PreToolUse hooks is **not specified** in any documentation reviewed.
The framework assumes only exit 0 (allow) and exit 2 (block) exist.
**This gap affects every hook in the system.**

---

## Recommendations

### P0 — Existential Risks
1. **Test Claude Code exit code behavior**: What does Claude Code do with PreToolUse hook exit 1, 127, 126? This determines whether C-01 is a deadlock or a bypass.
2. **Add `|| exit 0` guard to `fw hook` routing**: If the script is missing, fail OPEN (allow) rather than CLOSED (exit 2). The agent can at least continue working even if governance is degraded.
3. **Add health check for hook scripts**: `fw doctor` should verify all hook scripts exist and are executable.

### P1 — Compound Deadlocks
4. **Add `fw work-on` to budget-gate allowlist**: Currently only `fw task` matches. `fw work-on` is a common recovery command that should be allowed at budget critical.
5. **Add generic `echo ... > .context/` to budget-gate Bash allowlist**: Allows manual focus.yaml repair at critical budget.

### P2 — Resilience
6. **Add `set +e` wrapper around python3 calls in check-active-task.sh**: If python3 fails, fall back to grep-based YAML parsing instead of blocking.
7. **Document the exit code contract**: Explicitly state what Claude Code does with non-0/non-2 hook exit codes.

---

## Appendix: Hook Script Dependencies

| Script | Dependencies | Failure if missing |
|--------|-------------|-------------------|
| check-active-task.sh | python3, lib/paths.sh, lib/tasks.sh | BLOCKS (false "no task") |
| check-tier0.sh | python3, lib/paths.sh | ALLOWS (fails open) |
| check-project-boundary.sh | python3, lib/paths.sh | ALLOWS (fails open) |
| budget-gate.sh | python3, lib/paths.sh | ALLOWS (fails open) |
| block-plan-mode.sh | (not analyzed — only gates EnterPlanMode) | N/A |

**Note:** check-active-task is the ONLY hook that fails CLOSED on dependency errors. All others fail OPEN. This asymmetry means python3 failure blocks Write/Edit but allows everything through Bash — a partial deadlock with inconsistent governance.
