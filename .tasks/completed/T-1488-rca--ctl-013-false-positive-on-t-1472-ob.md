---
id: T-1488
name: "RCA — CTL-013 false positive on T-1472 (OBS-022 follow-on with T-1475 diagnostics)"
description: >
  RCA — CTL-013 false positive on T-1472 (OBS-022 follow-on with T-1475 diagnostics)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [audit, ctl-013, rca, heisenbug, obs-022]
components: [agents/audit/audit.sh]
related_tasks: [T-1472, T-1475, T-1395, T-1484]
created: 2026-04-26T09:01:00Z
last_update: 2026-04-26T10:59:47Z
date_finished: 2026-04-26T09:11:48Z
---

# T-1488: RCA — CTL-013 false positive on T-1472 (OBS-022 follow-on with T-1475 diagnostics)

## Context

OBS-022 captured: `fw audit` reports T-1472's verification (`bats <3 files>`) failing with rc=1 and zero output, but isolated runs (incl. multiple shim variants) all return rc=0. T-1475 added the
`FW_AUDIT_VERIFY_DEBUG=1` / `FW_AUDIT_VERIFY_TRACE=1` infrastructure so the next investigator could see what bats produced — but did not localize the root cause.

This task uses that infrastructure and confirms:
- **Heisenbug confirmed.** `FW_AUDIT_VERIFY_DEBUG=1` (DEBUG-only, brace-grouped redirect) → T-1472 FAILS rc=1, captured output **empty**. Adding `FW_AUDIT_VERIFY_TRACE=1` (which adds env-dump + `set -x` before eval inside the same brace block) → T-1472 PASSES rc=0. Adding the diagnostic preamble alone collapses the bug.
- **bats-specific.** T-1473 (`test -f`) and T-1474 (single bats file) PASS reliably. Only the three-bats-file invocation (`bats lib_inception.bats inception_tick_decision_recorded.bats inception_tick_marker.bats`) fails.
- **Audit-runtime-specific.** A standalone shim that mimics audit's FD setup (lock on FD 200 + `exec 3>&1 1>/dev/null`) does NOT reproduce. The bug requires the full audit script's accumulated state at the time CTL-013 fires (~line 1962 of agents/audit/audit.sh).
- **FD inheritance is not the cause.** Tested closing FD 200, FD 3, both, and adding `</dev/null` — all variants pass in the shim. T-1475's prior trial of `200>&-` also did not fix it.

**Why a structural fix is now available:** T-1484 landed Reviewer Pass B (`fw reviewer audit --pass-b`) which re-executes `## Verification` blocks in **worktree isolation** at each task's completion SHA — exactly what CTL-013 attempts inline, but with clean shell state and a classifier that skips network-dependent lines. Pass B does not exhibit this Heisenbug because each task runs in its own subprocess with a fresh worktree.

**Recommendation:** make CTL-013 defer bats invocations to Pass B. CTL-013 keeps its value for cheap non-bats checks (`test -f`, curl/grep, YAML parse); bats commands get a one-line "see Pass B" pointer instead of an inline re-execution that's known to false-positive. This is the minimal Level B/C fix; the deeper Level D question (deprecate CTL-013 verify-rerun entirely now that Pass B exists) belongs in a follow-on inception.

## Acceptance Criteria

### Agent

- [x] Reproduce confirmed: `touch .tasks/completed/T-1472-*.md && FW_AUDIT_VERIFY_DEBUG=1 bin/fw audit` shows `DEBUG (T-1472) FAIL (rc=1)` with empty captured output
- [x] TRACE collapses bug confirmed: same command with `FW_AUDIT_VERIFY_TRACE=1` shows `[PASS] CTL-013: T-1472 verification re-run: 1/1 pass`
- [x] Shim reproduction attempted (FD 200, FD 3, both closed; brace, subshell, bare; stdin redirect) — none reproduce; Heisenbug requires full audit context
- [x] T-1472 mtime restored (`touch -d 2026-04-25T19:40:42Z`) so audit's `ls -t | head -3` doesn't keep flagging it during the residual aging window
- [x] Findings + recommendation written to this task's Context + Recommendation sections

### Human
- [x] [REVIEW] Approve the recommended Level B fix: skip bats invocations in CTL-013 verify-rerun and emit a one-line "see fw reviewer audit --pass-b T-XXX" hint instead
  **Steps:**
  1. Read the Recommendation section below
  2. Decide: GO (implement the bats-skip + hint) / NO-GO (keep current behavior, accept the false positive) / DEFER (open inception for full CTL-013 deprecation in favor of Pass B)
  3. If GO: reply "GO" — agent will spawn a follow-on build task and implement (~15 min, no architecture risk)
  4. If DEFER: reply "DEFER" — agent will create an inception for CTL-013 vs Pass B overlap
  **Expected:** A direction so this RCA can close cleanly
  **If not:** Leave in review queue — the false positive stays advisory (CTL-013 emits WARN, not FAIL; pre-push is not blocked)

## Verification

# This task is RCA only. Verification = the diagnostics already added by T-1475 still work.
bash -n agents/audit/audit.sh

## Recommendation

**Recommendation:** GO — apply the targeted Level B fix.

**Proposed change** (≈10 lines in `agents/audit/audit.sh` around line 1924, the `for cmd in "${verify_cmds[@]}"` loop):

```bash
for cmd in "${verify_cmds[@]}"; do
    # T-1488: bats invocations false-positive in audit's runtime context
    # (Heisenbug; collapses under instrumentation). Pass B re-executes
    # in worktree isolation and is the canonical source of truth.
    if [[ "$cmd" =~ (^|[[:space:];&|])bats[[:space:]] ]]; then
        cmd_pass=$((cmd_pass + 1))   # treat as deferred-pass
        # Emit advisory hint so the operator knows where the real signal is
        echo "INFO (CTL-013) skipped bats line for $task_id — see: fw reviewer audit --pass-b" >&2
        continue
    fi
    # ... existing eval logic unchanged ...
done
```

**Rationale:**
1. **Solves the user-visible problem.** OBS-022's recurring CTL-013 WARN noise disappears for bats-based tasks.
2. **No loss of signal.** Pass B (T-1484) re-executes the same `## Verification` blocks under proper worktree isolation, with the same exit-code semantics, and surfaces results via `/reviewer/audit` (T-1486). The signal moves; it doesn't vanish.
3. **Bounded scope.** ≈10 lines + 1 unit test in `tests/unit/audit_verify_skips_bats.bats` (synthesize task with bats verify line, run audit section, assert PASS + INFO hint). No CTL-013 deletion, no architecture change. Reversible by reverting the conditional.
4. **Avoids chasing a Heisenbug.** Three sessions (T-1395, T-1475, T-1488) have now investigated the underlying timing/state issue without localizing it. The structural answer (Pass B exists; defer to it) costs less than a fourth attempt.

**Evidence:**
- `FW_AUDIT_VERIFY_DEBUG=1 bin/fw audit` reproduces the false positive on demand (this session, after `touch` to bump mtime)
- `FW_AUDIT_VERIFY_TRACE=1 bin/fw audit` confirms instrumentation collapses the bug → not a real verification failure, an audit-runtime artifact
- Shim with audit-mimicking FD setup does not reproduce → bug requires accumulated audit-script state, not just FD topology
- Pass B (T-1484) is live: `bin/fw reviewer audit --pass-b --limit 5 --quiet` runs cleanly with worktree isolation

**Alternative considered (DEFER):** open an inception for full CTL-013 verify-rerun deprecation in favor of Pass B. Larger scope (touches audit + downstream consumers of CTL-013 PASS/WARN). Worth doing eventually, not today.

**Alternative considered (NO-GO):** accept the false positive. Costs continued WARN noise + rebuilds the "ignore CTL-013 on bats" reflex; rejected because it teaches the agent to dismiss audit signal.

## Decisions

### 2026-04-26 — fix-level chosen
- **Chose:** Level B targeted fix — skip bats invocations in CTL-013 verify-rerun, emit hint pointing at Pass B
- **Why:** Pass B (T-1484) just landed and supersedes inline re-execution for the bats case; minimal code change preserves CTL-013's value for non-bats checks; reversible
- **Rejected:** Level D full deprecation (out of scope for an RCA task; deserves its own inception with stakeholder review)
- **Rejected:** Continue chasing the Heisenbug (3 sessions of investigation already; diminishing returns; structural fix is now available)

## Updates

### 2026-04-26T09:01:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1488-rca--ctl-013-false-positive-on-t-1472-ob.md
- **Context:** Initial task creation

### 2026-04-26 — RCA executed
- **Action:** Used T-1475's DEBUG/TRACE diagnostics to reproduce; ran shim variants for FD inheritance hypothesis; concluded Heisenbug + structural fix available via Pass B
- **Output:** Findings + Recommendation sections of this task

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0df4ab4e
- **Timestamp:** 2026-06-02T14:57:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T09:11:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
