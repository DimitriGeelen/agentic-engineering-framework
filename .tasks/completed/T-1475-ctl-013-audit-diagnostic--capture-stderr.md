---
id: T-1475
name: "CTL-013 audit diagnostic — capture stderr/stdout on verification failure (debug
  OBS-022)"
description: >
  CTL-013 verification re-run reports T-1472 failing in `fw audit`, but the
  same command run in isolation (or even via eval reproducing audit's logic)
  returns rc=0. The current FW_AUDIT_VERIFY_DEBUG=1 path only echoes the
  command — not its stderr/stdout — so the actual failure mode is invisible.
  Augment the diagnostic so the next CTL-013 false positive surfaces what
  bats / the verification command actually printed.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [audit, diagnostic, ctl-013, observability]
components: [C-004]
related_tasks: [T-1395, T-1472]
created: 2026-04-25T20:25:01Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-04-25T20:59:17Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=4 (body:fw-audit-or-doctor);
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1475: CTL-013 audit diagnostic — capture stderr/stdout on verification failure (debug OBS-022)

## Context

OBS-022 captured a real CTL-013 false positive: `fw audit` reports T-1472's bats
verification fails, but isolated runs (bats directly, with the cd-prefix, with
eval, even reproducing audit's full extraction → eval loop) all return rc=0.

The audit's existing `FW_AUDIT_VERIFY_DEBUG=1` path emits just the failing command
text. With `>/dev/null 2>&1` swallowing all output, there's no way to see what
bats actually said — making root-cause invariant on the audit's own runtime
context.

This task lands a minimal diagnostic enhancement: when DEBUG mode is on, redirect
to a tempfile and dump the first 20 lines on failure. That gives the next
investigator hard evidence of what differed between audit and isolated runs,
without changing the silent-failure default.

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` CTL-013 verification block tees stderr/stdout to a tempfile when `FW_AUDIT_VERIFY_DEBUG=1`
- [x] On verification failure with DEBUG set, first 20 lines of captured output are emitted to stderr alongside the existing FAIL message
- [x] FW_AUDIT_VERIFY_TRACE=1 adds bash xtrace to captured output for deepest visibility
- [x] Default behavior (DEBUG unset) unchanged — `>/dev/null 2>&1` still applies, no perf/output regression
- [x] `bash -n agents/audit/audit.sh` parses
- [x] DEBUG path produces actionable diagnostic output (rc=N, first 20 lines, separator)

## Findings

Investigation produced these data points (insufficient for full root cause; captured for follow-up):

- bats command runs cleanly outside the audit (rc=0 in fresh bash, in current shell, with cd-prefix, via eval-reproducing-audit's loop)
- Inside audit's eval+redirect path, bats produces ZERO captured output and exits rc=1
- Adding env-dump preamble + `set -x` BEFORE the eval inside the same brace block makes the test PASS
- FD 200 (audit lockfile) close (`200>&-`) does NOT fix it
- `bash -c "$cmd"` does NOT fix it
- Removing the trailing pipe (`bin/fw audit > log` vs `bin/fw audit | grep`) does NOT fix it
- Affects only T-1472's three-bats-file verification; T-1473 (`test -f`) and T-1474 (single bats file) PASS

Hypothesis: timing-sensitive race between bats' internal coproc setup and something in audit's runtime. The env-dump+xtrace preamble incidentally widened a window. Root cause not localized in this task.

## Out of Scope (deferred)

- The actual T-1472 false positive itself — diagnostic improved, root cause unconfirmed
- Suggest follow-up: instrument bats invocation with `set -x` permanently when DEBUG is set, attempt to bisect by running each bats file standalone inside audit context

## Verification

bash -n agents/audit/audit.sh

## Updates

### 2026-04-25T20:25:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1475-ctl-013-audit-diagnostic--capture-stderr.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-67ae9de4
- **Timestamp:** 2026-06-02T14:57:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T20:59:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
