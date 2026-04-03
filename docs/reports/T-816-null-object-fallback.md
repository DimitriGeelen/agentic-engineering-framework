# T-816: Null Object Fallback Pattern for Framework Hooks — Analysis

**Question:** Should the Agentic Engineering Framework adopt a null-object/fail-open fallback for PreToolUse hooks, inspired by traceAI's INVALID_SPAN pattern?

**Prior art:** T-581 (NO-GO, 2026-03-25) concluded hooks are "already correct" — PreToolUse fails closed, PostToolUse fails open. This analysis revisits the question from a different angle: not "should advisory hooks fail open?" (answered: they already do) but "when a critical hook *crashes*, should we distinguish that from a deliberate block?"

---

## Strawman (Arguments Against)

### 1. Governance Frameworks Are Not Observability Libraries

traceAI's INVALID_SPAN pattern exists because **dropping a span is always preferable to crashing the application**. The cost asymmetry is extreme: a missing trace is invisible; a crashed API server is a P0 incident. The entire design assumes the host application's work is more important than instrumentation.

For a governance framework, this asymmetry is **inverted**. The hooks exist to *prevent unauthorized actions*. A task gate that silently passes when it crashes is equivalent to a door lock that opens when the power goes out — technically convenient, fundamentally broken. The whole value proposition of structural enforcement (CLAUDE.md: "enforced structurally by the framework, not by agent discipline") collapses if the enforcement layer itself can silently degrade.

### 2. Security Surface: Fail-Open Is Exploitable

If hooks fail open on crash, an adversary (or a confused agent) has a trivial bypass path: cause the hook to crash.

**Concrete scenarios:**

- **Corrupted focus.yaml**: If `check-active-task.sh` crashes parsing a malformed YAML file, fail-open would allow all Write/Edit operations without a task. Currently, the crash blocks — which is correct, because the inability to read task state *is itself a problem worth blocking for*.
- **Missing python3**: All hooks depend on `python3` for JSON/YAML parsing. If the Python binary is missing or PATH is broken, every hook crashes. Fail-open means *all enforcement disappears simultaneously*. Fail-closed means the agent stops and the human investigates.
- **Disk full**: If `.context/working/` is unwritable, budget-gate.sh can't cache status. Fail-open would allow unlimited context consumption. Fail-closed forces investigation.
- **Stdin pipe failure**: Hooks read JSON from stdin. If Claude Code changes the stdin format or sends empty input, Python parsing fails. Fail-open with no JSON means no file path extraction, no command extraction — the hook passes with zero information about what it's gating.

### 3. Existing Safeguards Would Be Undermined

The framework has layered defenses that assume hooks fail closed:

| Safeguard | Undermined by fail-open? |
|-----------|-------------------------|
| Task gate (P-002) | Yes — no-task edits become possible on crash |
| Tier 0 destructive command blocking | Yes — force push/rm -rf on crash |
| Budget enforcement (P-009) | Yes — unbounded context consumption on crash |
| Project boundary enforcement | Yes — cross-repo edits on crash |
| Enforcement config protection (B-005) | Yes — settings.json editable on crash |
| Inception commit gate | Yes — build commits during inception on crash |

### 4. "The Framework's Own Immune System"

The framework's antifragility directive (D-001) says the system should *strengthen under stress*. A crashing hook is stress. The correct response to stress is not to suppress the signal — it's to surface it loudly. Fail-closed on crash is the immune response: the body stops the operation, surfaces the error, and forces investigation.

Fail-open on crash is immunosuppression: the body ignores the infection and keeps going. This may look healthy in the short term. It is not.

### 5. The FW_SAFE_MODE Escape Hatch Already Exists

T-630/T-650 introduced `FW_SAFE_MODE=1` as an explicit, human-authorized escape hatch. When the task gate itself is broken and blocks legitimate work, the human can set this env var to bypass it. This is:
- **Intentional** (not accidental)
- **Logged** (SAFE MODE message in stderr)
- **Scoped** (task gate only, Tier 0 stays active)
- **Reversible** (unset the env var)

A null-object fallback would be FW_SAFE_MODE-by-default-on-crash, without the logging, scoping, or intentionality.

---

## Steelman (Arguments For)

### 1. The Agent Cannot Distinguish "Gate Says No" from "Gate Is Broken"

This is the strongest argument. Currently, when a PreToolUse hook returns non-zero:
- Exit 2: The hook *decided* to block (task missing, destructive command, budget exceeded)
- Exit 1: The hook *crashed* (Python import error, missing file, unset variable)
- Both look identical to the agent: "BLOCKED"

The agent's response to both is the same: retry, escalate to user, or work around. But the *correct human response* is different:
- Deliberate block: follow the instructions in stderr (create task, get approval, etc.)
- Crash: investigate and fix the hook

Without distinguishing these, the agent wastes cycles trying to "fix" a non-existent task problem when the real issue is a broken hook script.

### 2. Real Failure Modes from Framework History

Evidence of hooks causing problems:

- **T-613**: Consumer projects had hook errors because vendored framework was outdated. The hooks themselves were correct but the *environment* was wrong (stale vendored copy). Fail-closed blocked all work until the human manually updated.
- **T-271**: Stale `.budget-status` file with critical level permanently blocked the agent. The budget-gate had a bug where it trusted stale critical status without re-validating from the transcript. This is a case where a **correct hook with stale state** behaved like a crash — blocking everything without recourse.
- **T-650**: Expanding the task gate to Bash required an `FW_SAFE_MODE` escape hatch because the expanded gate could deadlock (the fix for the fixer: you can't edit the broken hook if the hook blocks editing).
- **G-011**: PostToolUse hooks being advisory-only was logged as a concern — but never triggered. The advisory hooks *already fail open* and this has been fine.

### 3. How to Implement Fail-Open WITHOUT Compromising Security

The key insight: fail-open is not binary. You can fail open **with full audit logging and degraded-mode signaling**:

1. **Distinguish exit codes**: Exit 2 = intentional block. Exit 1 + stderr output = crash. Exit 0 = allow.
2. **On crash**: Log the crash to a file (`.context/working/.hook-crashes.log`), emit a warning to stderr, and allow the operation.
3. **Rate-limit fail-open**: If the same hook crashes 3+ times in a row, escalate to fail-closed (the hook is systematically broken, not transiently failing).
4. **Alert channel**: Push notification via `fw notify` on first hook crash — the human should know enforcement degraded.

This is the "circuit breaker" pattern, not the raw fail-open pattern.

### 4. Which Hooks Could Reasonably Fail Open?

Not all hooks carry equal risk:

| Hook | Fail-open risk | Recommendation |
|------|---------------|----------------|
| `check-active-task.sh` | Medium — work without task context | **FAIL-CLOSED** (core governance) |
| `check-tier0.sh` | **HIGH** — destructive commands unblocked | **FAIL-CLOSED** (safety-critical) |
| `budget-gate.sh` | Medium — context overconsumption | Could fail-open (auto-handover is backup) |
| `check-project-boundary.sh` | Medium — cross-repo edits | **FAIL-CLOSED** (blast radius) |
| `block-plan-mode.sh` | Cannot crash (3 lines) | N/A |
| `check-agent-dispatch.sh` | Low — too many agents | Could fail-open (advisory intent) |

Only 2 of 6 PreToolUse hooks could reasonably fail open, and one of those (`check-agent-dispatch.sh`) is already advisory in intent.

### 5. The Antifragility Argument Cuts Both Ways

D-001 says the system should strengthen under stress. But a system that *stops working entirely* when a single hook has a bug is **fragile**, not antifragile. The fragile response: everything stops. The antifragile response: degrade gracefully, log the degradation, and self-heal.

traceAI's INVALID_SPAN is antifragile — the system keeps working but records that it degraded. The framework's current all-or-nothing response to hook crashes is the *opposite* of antifragile.

---

## Implementation Sketch

### Exit Code Protocol

```bash
# In Claude Code's hook runner (conceptual — actual implementation is in Claude Code):
#
# Exit 0 = ALLOW
# Exit 2 = INTENTIONAL BLOCK (gate decided to block)
# Exit 1 = CRASH (gate itself failed)
#
# Current behavior: exit 1 and exit 2 both block.
# Proposed: exit 1 triggers crash handler.
```

### Crash-Detection Wrapper

A wrapper script that `fw hook` uses to invoke each hook, distinguishing crashes from blocks:

```bash
#!/bin/bash
# hook-runner.sh — wraps hook execution with crash detection
# Usage: hook-runner.sh <hook-script> <fail-mode> [args...]
# fail-mode: "closed" or "open"

HOOK_SCRIPT="$1"
FAIL_MODE="${2:-closed}"
shift 2

# Capture stdin for replay
INPUT=$(cat)

# Run the hook, capturing stderr and exit code
STDERR_FILE=$(mktemp)
echo "$INPUT" | "$HOOK_SCRIPT" "$@" 2>"$STDERR_FILE"
EXIT_CODE=$?

case $EXIT_CODE in
    0)
        # Hook allowed — pass through
        cat "$STDERR_FILE" >&2
        rm -f "$STDERR_FILE"
        exit 0
        ;;
    2)
        # Hook intentionally blocked — pass through
        cat "$STDERR_FILE" >&2
        rm -f "$STDERR_FILE"
        exit 2
        ;;
    *)
        # Hook crashed (exit 1, 126, 127, 128+signal, etc.)
        CRASH_LOG="$PROJECT_ROOT/.context/working/.hook-crashes.log"
        HOOK_NAME=$(basename "$HOOK_SCRIPT" .sh)
        TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        STDERR_CONTENT=$(head -c 500 "$STDERR_FILE")

        # Log the crash
        echo "[$TIMESTAMP] CRASH: $HOOK_NAME exit=$EXIT_CODE stderr='$STDERR_CONTENT'" \
            >> "$CRASH_LOG" 2>/dev/null

        # Emit warning to agent
        echo "" >&2
        echo "WARNING: Hook '$HOOK_NAME' crashed (exit $EXIT_CODE)." >&2
        echo "  This is a hook malfunction, not a governance decision." >&2
        head -3 "$STDERR_FILE" >&2
        echo "" >&2

        rm -f "$STDERR_FILE"

        if [ "$FAIL_MODE" = "open" ]; then
            # Advisory/recoverable hook — allow with degradation warning
            echo "  Mode: fail-open (operation allowed, enforcement degraded)" >&2
            echo "  Action: Report this to the human." >&2

            # Rate-limit: if 3+ crashes from same hook, escalate to closed
            CRASH_COUNT=$(grep -c "CRASH: $HOOK_NAME" "$CRASH_LOG" 2>/dev/null || echo 0)
            if [ "$CRASH_COUNT" -ge 3 ]; then
                echo "  ESCALATED: $HOOK_NAME crashed $CRASH_COUNT times — failing CLOSED." >&2
                exit 2
            fi

            exit 0
        else
            # Safety-critical hook — fail closed
            echo "  Mode: fail-closed (operation blocked, investigate hook)" >&2
            echo "  Escape: FW_SAFE_MODE=1 to bypass task gate" >&2
            exit 2
        fi
        ;;
esac
```

### Hook Classification in `fw hook` Router

```bash
# In bin/fw, the hook) case would classify each hook:
case "$_hook_name" in
    check-tier0|check-active-task|check-project-boundary|block-plan-mode)
        _fail_mode="closed"   # Safety-critical — crash = block
        ;;
    budget-gate)
        _fail_mode="closed"   # Budget — crash = block (checkpoint.sh is backup)
        ;;
    check-agent-dispatch|commit-cadence|check-fabric-new-file|loop-detect|checkpoint|error-watchdog)
        _fail_mode="open"     # Advisory — crash = warn + allow
        ;;
    *)
        _fail_mode="closed"   # Unknown hooks default to closed
        ;;
esac
```

### What Gets Logged

Every hook crash produces a line in `.context/working/.hook-crashes.log`:
```
[2026-04-03T10:15:00Z] CRASH: budget-gate exit=1 stderr='python3: command not found'
[2026-04-03T10:15:01Z] CRASH: check-active-task exit=1 stderr='python3: command not found'
```

This file is:
- Picked up by `fw doctor` (new health check)
- Included in handover generation (degradation awareness)
- Cleared on `fw context init` (fresh session)

---

## Recommendation

**NO-GO (with a carve-out)**

### Primary Rationale

T-581's conclusion still holds for the core governance hooks: **PreToolUse fail-closed is the correct default for safety-critical gates.** The null-object pattern from traceAI solves a problem the framework doesn't have at the same severity — traceAI instruments applications where the instrumentation must never crash the host; the framework *is* the host.

The framework already has the escape hatch for the "broken hook deadlocks the agent" scenario: `FW_SAFE_MODE=1`. This is strictly better than automatic fail-open because it requires human intent.

### The Carve-Out: Crash vs Block Distinguishability

The one genuine improvement from this analysis: **the agent should be able to distinguish "gate says no" from "gate crashed."** This doesn't require fail-open behavior — it requires better error messages.

**Recommended action (small, bounded):**

1. Add a 5-line stderr header to each hook's crash path so the agent sees "HOOK CRASHED" vs "BLOCKED BY POLICY"
2. Add `trap` handlers in hooks to catch unexpected exits and emit a crash marker
3. Log crashes to `.context/working/.hook-crashes.log` for `fw doctor` to pick up

This gives the agent the information to tell the human "the task gate crashed, run `fw doctor`" instead of "I need a task but I already have one" — without introducing fail-open risk.

### Why Not Full Fail-Open

1. **4 of 6 PreToolUse hooks are safety-critical** — fail-open would undermine them
2. **The 2 candidates for fail-open** (budget-gate, check-agent-dispatch) already have backup enforcement (checkpoint.sh PostToolUse, TermLink dispatch limit)
3. **The FW_SAFE_MODE escape hatch** already covers the "hook is broken and blocking work" scenario
4. **No incident evidence** — T-581 found zero incidents of hooks crashing and blocking work. T-271 (stale budget status) was a logic bug, not a crash. T-613 was an environment issue (stale vendored copy), not a hook crash.
5. **Complexity cost** — a crash-detection wrapper adds a new failure surface (what if the wrapper crashes?)

### Decision Matrix

| Option | Benefit | Risk | Verdict |
|--------|---------|------|---------|
| Full fail-open for all hooks | Agent never stuck on crash | All enforcement bypassable | **REJECT** |
| Selective fail-open (advisory hooks only) | Marginal — advisory hooks already fail open (PostToolUse) | Complexity for no gain | **REJECT** |
| Crash vs block distinguishability | Agent can report accurately | None (stderr only) | **ACCEPT** |
| Crash logging + `fw doctor` check | Visibility into hook health | Minimal | **ACCEPT** |
| Status quo (no change) | Zero risk | Agent confusion on crashes | **Acceptable** |

### If Evidence Changes

This is a NO-GO *with watched triggers*. Revisit if:
- 3+ incidents of hooks crashing and blocking legitimate work in production
- Consumer project adoption reveals environment diversity that causes frequent hook crashes
- Claude Code changes hook semantics (e.g., exit 1 becomes "error" distinct from exit 2 "block")

---

## Appendix: Hook Error Handling Audit (Current State)

All PreToolUse hooks use `set -uo pipefail` (strict mode). Points of fragility:

| Hook | `-u` risk (unset var) | `pipefail` risk | Python crash risk | Mitigation |
|------|----------------------|-----------------|-------------------|------------|
| check-active-task | `CURRENT_TASK` could be empty | `read` piped from Python | 5 Python blocks | `2>/dev/null` on all Python, empty-string defaults |
| check-tier0 | `COMMAND` could be empty | Command piped through grep+Python | 2 Python blocks | Early `exit 0` if empty command |
| budget-gate | Status vars could be empty | Transcript piped through tail+Python | 2 Python blocks | Defaults on all vars, `exit 0` on transcript not found |
| check-project-boundary | `FILE_PATH` could be empty | Similar to check-active-task | 2 Python blocks | Same pattern |
| check-agent-dispatch | Counter could be empty | Counter read from file | 1 Python block | Defaults to 0 |

The `-u` flag (nounset) is the most likely crash vector: if any variable is referenced without a default and happens to be unset, the shell exits immediately with code 1. All hooks mitigate this with `${VAR:-default}` patterns, but a new code path could miss this.
