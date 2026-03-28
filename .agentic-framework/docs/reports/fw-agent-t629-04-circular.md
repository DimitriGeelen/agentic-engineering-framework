# Circular Dependency Analysis — Framework Governance

**Task:** T-629 | **Date:** 2026-03-26 | **Scope:** All PreToolUse/PostToolUse hooks, CLI dependency chains, bootstrap paths

---

## Executive Summary

The framework has **6 confirmed circular dependencies** and **2 near-circular patterns**. Most are mitigated by existing escape hatches (exempt paths, fail-open Python, bootstrap mode), but **3 have no clean break** and rely on human intervention or process restart. The biggest structural gap: **no safe mode exists** — all recovery paths require at least one working gate script.

---

## Confirmed Circular Dependencies

### CD-1: Hook Script Fix Requires the Hook It's Fixing (CRITICAL)

```
check-active-task.sh is broken → need Write/Edit to fix it
  → Write/Edit gated by check-active-task.sh → BLOCKED
```

**Severity:** Critical — total Write/Edit lockout if hook crashes with exit 2
**Current mitigations:**
- Python `except: sys.exit(0)` fail-open (line 31-36) — catches parse errors but NOT logic bugs
- Exempt paths: `.context/`, `.tasks/`, `.claude/` bypass the gate — but the hook script itself is at `agents/context/check-active-task.sh` which is NOT exempt
- Bootstrap: if `.context/working/` is deleted, the gate opens — but this is destructive

**Break path:** None clean. Must either:
1. Edit via Bash (`sed`/`echo >`) — but Bash is gated by check-project-boundary.sh and budget-gate.sh
2. Delete `.context/working/` to trigger bootstrap mode — destroys session state
3. Human edits the file outside Claude Code

**Same pattern applies to:** `budget-gate.sh`, `check-tier0.sh`, `check-project-boundary.sh`, `check-dispatch-pre.sh`, `block-plan-mode.sh`

---

### CD-2: Settings Protection vs Settings Repair (CRITICAL)

```
.claude/settings.json has bad hook config → need Edit to fix it
  → Edit blocked by B-005 in check-active-task.sh → ALWAYS BLOCKED
  → No approval mechanism, no --force, no exempt path
```

**Severity:** Critical — B-005 is an unconditional block (lines 42-56). Even `--force` doesn't help because this check runs before the task gate.
**Current mitigations:** None within Claude Code. Human must edit the file manually.
**Break path:** Human-only. The agent literally cannot modify this file under any circumstances.

**Assessment:** This is intentional (settings.json controls enforcement), but if a hook path becomes invalid (e.g., script moved/renamed), the broken hook fires on every tool call and there's no self-repair path.

---

### CD-3: Budget Critical Lock → Can't Fix Budget Gate (HIGH)

```
budget-gate.sh reports critical (false positive) → blocks Write/Edit/Bash
  → fixing budget-gate.sh requires Write/Edit → BLOCKED
  → resetting .budget-status requires Bash → BLOCKED
```

**Severity:** High — false critical creates total lockout
**Current mitigations:**
- Cache TTL: `.budget-status` expires after 90 seconds — but budget-gate re-reads transcript and re-confirms critical
- Stale critical re-read (T-271): forces immediate transcript re-read — works for temporary spikes, not persistent bugs
- Pre-compact hook resets budget state — but requires `/compact` which needs human interaction
- Write to `.context/` is exempt at critical — but `agents/context/budget-gate.sh` is NOT in `.context/`

**Break path:** Wait for session to end and start fresh. Or human edits the file.

---

### CD-4: Task Creation Requires Bash → Bash Gated by Budget (MEDIUM)

```
No active task → Write/Edit blocked by check-active-task.sh
  → creating task requires: fw task create (Bash)
  → Bash gated by budget-gate.sh at critical level
  → Can't create task, can't write code
```

**Severity:** Medium — only triggers at critical budget level
**Current mitigations:**
- Budget gate allows `fw task` commands at critical level (explicit allowlist in budget-gate.sh)
- This specific chain IS broken by the allowlist

**Assessment:** **Resolved by design.** The budget gate explicitly allows `fw task`, `fw handover`, `fw context` at critical level. This is the RIGHT way to break circular deps.

---

### CD-5: Focus Setting After Compaction (MEDIUM)

```
After compaction → working memory lost → focus.yaml may have stale session stamp
  → Write/Edit blocked ("stale focus from previous session" — T-560)
  → need fw work-on T-XXX (Bash) to re-focus
  → Bash gated by budget-gate at critical
  → but compaction resets budget → budget is OK after compact
```

**Severity:** Medium — theoretical but mitigated
**Current mitigations:**
- Pre-compact hook resets budget state (clears `.budget-status`, resets counter)
- Budget gate allows `fw context focus` and `fw work-on` at critical
- Post-compact-resume hook reinjects context including focus state

**Assessment:** **Resolved by design.** Pre-compact reset + budget allowlist breaks the chain.

---

### CD-6: Inception Gate → Decision Requires Human Terminal (MEDIUM)

```
Inception task hits 2 exploration commits → commit-msg hook blocks further commits
  → recording decision requires: fw inception decide T-XXX go
  → fw inception decide is Tier 0 (human authority required)
  → human must run: cd /project && bin/fw tier0 approve
  → then: cd /project && bin/fw inception decide T-XXX go
  → if human is unavailable → all commits blocked indefinitely
```

**Severity:** Medium — by design (inception decisions ARE human authority), but creates total commit lockout
**Current mitigations:** `--force` on commit bypasses inception gate (with bypass log)
**Break path:** Human runs the approval command. This is intentional — but the agent can't even commit wrap-up work.

---

## Near-Circular Patterns (Mitigated)

### NCD-1: Git Hook Fix Requires Committing → Commit Triggers Broken Hook

```
.git/hooks/commit-msg is broken → fixing it requires Write/Edit
  → Write is allowed (.git/* is exempt path)
  → but testing the fix requires git commit
  → git commit triggers the broken hook → fails
  → use --no-verify → blocked by Tier 0 (check-tier0.sh)
```

**Break path:** `fw tier0 approve` then `git commit --no-verify`. Logged in bypass-log.yaml. Works but requires human.

### NCD-2: Project Boundary Hook Blocks Fix of Global fw

```
Global fw at /root/.agentic-framework/bin/fw is stale
  → fixing it requires Write to /root/.agentic-framework/
  → blocked by check-project-boundary.sh (outside PROJECT_ROOT)
  → no approval mechanism for boundary violations
```

**Break path:** Human edits the file, or agent uses a separate Claude Code session rooted in that directory.

---

## Ungated Tools (Always Available)

These tools have **ZERO hook matchers** — they can never be blocked:

| Tool | Gated? | Can Diagnose? | Can Fix? |
|------|--------|---------------|----------|
| **Read** | Never | YES — read any file | No |
| **Glob** | Never | YES — find any file | No |
| **Grep** | Never | YES — search any content | No |
| **Agent/Task** | Preamble only | YES — dispatch research | Partially (sub-agent Write is gated) |
| **WebFetch** | Never | YES — external docs | No |
| **WebSearch** | Never | YES — search web | No |

**Key finding:** The agent can ALWAYS diagnose problems (Read/Glob/Grep are ungated) but may not be able to FIX them if Write/Edit/Bash are all blocked.

---

## Does a "Safe Mode" Exist?

**No.** There is no single command, env var, or flag that disables all gates simultaneously.

**Closest equivalents:**
1. **Bootstrap mode:** Delete `.context/working/` → task gate opens. But budget gate and tier0 still active.
2. **Fail-open Python:** Hook scripts catch Python exceptions with `exit 0`. But shell-level bugs still block.
3. **Exempt paths:** `.context/`, `.tasks/`, `.claude/` (except settings.json) bypass task gate. But source files are never exempt.
4. **Budget allowlist:** `fw task/handover/context` commands pass at critical. But Write/Edit to source don't.

**No combination of existing mechanisms provides full self-repair capability.**

---

## Proposed Escape Hatch: Minimum Viable Safe Mode

### Option A: `fw safe-mode` (Recommended)

A single command that temporarily disables non-destructive gates:

```bash
fw safe-mode --duration 5m --reason "Fix broken hook script"
```

**What it would do:**
1. Write a signed token to `.context/working/.safe-mode` (timestamp + duration + reason)
2. All PreToolUse hooks check for this token first — if valid, exit 0 (except Tier 0)
3. Token is time-limited (max 10 minutes)
4. All operations during safe mode logged to `.context/bypass-log.yaml`
5. Tier 0 (destructive commands) STILL blocked — safe mode is for self-repair, not for rm -rf

**Gates bypassed:** check-active-task, budget-gate, check-project-boundary, check-dispatch-pre
**Gates preserved:** check-tier0 (destructive), block-plan-mode (governance)

**Implementation:** ~15 lines added to each gate script (check for `.safe-mode` file, validate TTL).

### Option B: Exempt Framework Scripts from Task Gate

Add `agents/context/*.sh` to the exempt path list in check-active-task.sh:

```bash
case "$FILE_PATH" in
    "$PROJECT_ROOT"/.context/*|"$PROJECT_ROOT"/.tasks/*|...|"$PROJECT_ROOT"/agents/context/*.sh)
        exit 0
        ;;
esac
```

**Problem:** This only breaks CD-1. Budget gate and boundary gate remain circular.

### Option C: `--self-repair` Flag on fw CLI

```bash
fw --self-repair edit agents/context/check-active-task.sh
```

Wraps Write/Edit with a pre-authenticated bypass token. Logged, time-limited, scoped to framework files only.

---

## Dependency Matrix: "What Breaks If X Breaks?"

| Broken Component | Write/Edit? | Bash? | Commit? | Task Create? | Handover? | Diagnose? |
|------------------|-------------|-------|---------|--------------|-----------|-----------|
| check-active-task.sh (exit 2 bug) | BLOCKED | OK | OK | OK | OK | OK (Read) |
| budget-gate.sh (false critical) | BLOCKED | BLOCKED | Allowed | Allowed | Allowed | OK (Read) |
| check-tier0.sh (false positive) | OK | BLOCKED | BLOCKED | BLOCKED | BLOCKED | OK (Read) |
| check-project-boundary.sh (bug) | BLOCKED | BLOCKED | OK | OK | OK | OK (Read) |
| .claude/settings.json (bad config) | Varies | Varies | Varies | Varies | Varies | OK (Read) |
| lib/paths.sh (broken) | ALL hooks fail-open | ALL hooks fail-open | May work | May fail | May fail | OK (Read) |
| Python3 missing | ALL hooks fail-open | ALL hooks fail-open | OK | OK | OK | OK (Read) |

**Worst case:** check-tier0.sh false positive → total Bash lockout → can't create tasks, commit, handover, or self-repair. Only Read/Glob/Grep work. Agent can diagnose but not act.

---

## Recommendations (Priority Order)

1. **Add `.safe-mode` token** (Option A) — breaks CD-1, CD-2, CD-3 simultaneously. ~2 hours implementation.

2. **Add `agents/` to exempt paths** in check-active-task.sh — breaks CD-1 for task gate only. ~5 minutes.

3. **Add `--self-repair` allowlist** to budget-gate.sh — allow Write/Edit to `agents/context/*.sh` even at critical. Breaks CD-3.

4. **Add B-005 approval path** — allow `.claude/settings.json` edits with Tier 0 approval (same mechanism as destructive commands). Breaks CD-2.

5. **Document the "human must edit" paths** — for CD-2 and CD-6, human intervention is intentional. Document these as "Human Escape Hatches" in CLAUDE.md so the agent knows to ask immediately instead of trying workarounds.

---

## Summary Stats

| Category | Count |
|----------|-------|
| Confirmed circular dependencies | 6 |
| Critical (no clean break) | 3 (CD-1, CD-2, CD-3) |
| Mitigated by design | 2 (CD-4, CD-5) |
| Intentional (human authority) | 1 (CD-6) |
| Near-circular (mitigated) | 2 (NCD-1, NCD-2) |
| Ungated diagnostic tools | 6 (Read, Glob, Grep, Agent, WebFetch, WebSearch) |
| Safe mode exists? | NO |
| Self-repair possible? | Only via fail-open or human intervention |
