---
id: T-1491
name: "RCA — do_inception_decide records Decision but status transition silently fails
  (T-1388 Class B limbo)"
description: >
  RCA on the bug that caused T-1346, T-1388, and the T-1423 sweep's 49 historical
  stuck inceptions: the AC gate (P-010) blocks update-task.sh from transitioning
  to work-completed, but do_inception_decide does not check the exit code, so
  the user sees "Inception decision recorded" in green and never learns the
  task is stuck.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [rca, inception, governance, silent-failure, g-019]
components: [lib/inception.sh]
related_tasks: [T-1346, T-1388, T-1466, T-1472, T-1490, T-1423]
created: 2026-04-26T09:48:00Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T09:56:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 3
      D3: 1
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=3 
      (body:component-silent-failure); D3=1 (body:error-msg-improved); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1491: RCA — do_inception_decide records Decision but status transition silently fails

## Context

T-1490 (D13 audit check) added detection for two limbo classes. Class B (status=started-work
+ Decision recorded + all ACs ticked) is the symptom of a real bug. This task does the RCA.

## Findings

**Symptom (reproduced this session):**
- T-1346 + T-1388 had Decision GO recorded by `inception-workflow` (Updates entries timestamped
  2026-04-20T09:40 and 2026-04-22T22:04 respectively), all Agent + Human ACs `[x]` checked,
  yet status stayed `started-work` with the file in `.tasks/active/`.
- Running `update-task.sh T-1388 --status work-completed --skip-sovereignty` *now* succeeds
  cleanly (3/3 Agent ACs, 1/1 Human AC, no AC gate failure, no verification failure). The bug
  is therefore historical, not current.

**Root cause (git archaeology):**

T-1466 (commit `3969a09`, 2026-04-25) is explicit:
> T-1455's GO click 500'd twice in the prior session because AC4 wording
> `[Inception decision recorded] go/no-go/defer with chosen option (A/B/C)`
> was not matched by AGENT_PATTERNS at lib/inception.sh:201-205 → **AC stayed
> unchecked → P-010 blocked work-completed** → /inception/T-XXX returned 500.

T-1472 (commit `b6d18dfb`, 2026-04-25) followed up with the Level D fix: replace the
text-pattern `AGENT_PATTERNS` regex with `<!-- @auto-tick-on-decide -->` HTML-comment markers.

So the *immediate* wording-matching issue is closed for new tasks. T-1346 (decided 2026-04-20)
and T-1388 (decided 2026-04-22) both predate T-1466/T-1472 and got caught by the older regex.

**Deeper bug (still present):**

`lib/inception.sh:454`:
```bash
"$AGENTS_DIR/task-create/update-task.sh" "$task_id" --status work-completed \
    --skip-sovereignty --reason "Inception decision: $decision_upper" 2>&1
```

The exit code is **never checked**. If the AC gate (P-010) or verification gate (P-011) refuses
the transition, do_inception_decide proceeds to line 461 and prints:
```
Inception decision recorded
Task: T-XXX
Decision: GO
```
in green. The user has no way to know the status didn't transition.

This is the antifragility-violation pattern (G-019): symptom-fixing without addressing why the
framework couldn't detect failure. T-1466/T-1472 fixed *this particular wording dependency*. The
next AC pattern that slips through, or the next verification command that fails, will produce
the same silent limbo — and operators will only discover it when they notice the task is still
in `active/`. T-1423 had to *retroactively sweep 49 stuck inceptions* — that's the historical
cost of this silent failure.

## Acceptance Criteria

### Agent

- [x] Reproduce confirmed: T-1388 transitions cleanly *now* under `update-task.sh --status work-completed --skip-sovereignty` (rolled back to keep the limbo state for review)
- [x] Root cause localized: pre-T-1466 `AGENT_PATTERNS` did not match the Human AC text on T-1346/T-1388, leaving the AC unchecked, blocking P-010
- [x] Deeper bug localized: `lib/inception.sh:454` does not check update-task.sh's exit code; line 461 unconditionally prints success
- [x] Evidence cited from git log + T-1466's own commit message (which describes this exact failure mode for T-1455)
- [x] Recommendation written (next section) with proposed patch and test scaffold

### Human

- [x] [REVIEW] Approve the recommended Level D fix: capture update-task.sh's exit code in do_inception_decide and surface failure with actionable error
  **Steps:**
  1. Read the Recommendation section below
  2. Decide: GO (apply the patch + test) / NO-GO (accept silent failure) / DEFER (open inception for broader gate-error-propagation review)
  3. If GO: reply "GO" — agent will spawn a follow-on build task (~15 min, ~10 lines + 1 bats test, no architecture change)
  4. If DEFER: reply "DEFER" — agent will open an inception covering all silent-gate-failure paths in fw (not just inception decide)
  **Expected:** A direction so this RCA can close cleanly
  **If not:** Leave in review queue — silent failures continue, audit's D13 catches them retroactively

## Verification

bash -n lib/inception.sh
# Reproduces are in Findings section — no shell verification needed for an RCA.

## Recommendation

**Recommendation:** GO — apply the Level D fix.

**Proposed change** (≈12 lines in `lib/inception.sh`, replacing line 454):

```bash
local _ut_rc=0
"$AGENTS_DIR/task-create/update-task.sh" "$task_id" --status work-completed \
    --skip-sovereignty --reason "Inception decision: $decision_upper" 2>&1 || _ut_rc=$?
if [ "$_ut_rc" -ne 0 ]; then
    echo "" >&2
    echo -e "${RED}ERROR: Status transition to work-completed FAILED (rc=$_ut_rc)${NC}" >&2
    echo "Decision was recorded in the task file, but status remains stuck." >&2
    echo "Likely cause: AC gate (P-010) — an unchecked AC blocks completion." >&2
    echo "  Run: $(_emit_user_command "task verify $task_id")   to see what's unchecked." >&2
    echo "  Or:  $(_emit_user_command "task update $task_id --status work-completed --skip-sovereignty")   to retry." >&2
    exit "$_ut_rc"
fi
```

**Bats test** (`tests/unit/inception_decide_propagates_failure.bats`):
- Synthesize an inception task with an unchecked Agent AC the tick logic won't recognize
- Synthesize a `## Recommendation` block + review marker so prior gates pass
- Run `do_inception_decide T-XXX go --rationale 'test' --i-am-human`
- Assert: exit code != 0, stderr contains "Status transition to work-completed FAILED"
- Assert: task file has Decision section recorded (decision IS persisted) but status is still `started-work`

**Rationale:**
1. **Antifragility:** failures become visible. The current code teaches operators that the green "Inception decision recorded" message is unreliable — they must independently verify the task moved to completed/. With this fix, a failure halts the flow with a clear next step.
2. **Bounded scope:** ~12 lines + 1 bats test. No architecture change, no new dependencies, additive only (success path unchanged).
3. **Evidence-based:** the bug demonstrably caused at least 2 named limbo cases (T-1346, T-1388) + 49 historical sweep targets. Failure visibility would have made these caught at decision-time, not days/weeks later.
4. **Avoids a fifth chase.** T-1466 and T-1472 already chased the immediate wording symptoms; T-1490 added detection. Fixing the silent-failure layer means future variants of this class are noisy at the source instead of waiting for D13 to surface them.

**Evidence:**
- `lib/inception.sh:454` — current code, no exit check
- `lib/inception.sh:461` — unconditional green success message regardless of transition outcome
- T-1466 commit message confirms this exact failure mode caused a 500 on /inception/T-1455 prior session
- T-1346 + T-1388 in `.tasks/active/` with Decision recorded + status:started-work — live evidence
- T-1423 (`fw inception sweep`) exists *because* of historical sweeps over 49 such tasks

**Alternative considered (DEFER):** open an inception for broader audit of all `fw` codepaths that silently swallow gate failures (update-task.sh callers exist in handover.sh, healing.sh, others). Larger scope, more design surface. Worth doing but `do_inception_decide` is the highest-traffic offender — fix the worst leak first, then survey.

**Alternative considered (NO-GO):** rely on D13 (T-1490) to catch limbo states retroactively. Rejected because retroactive detection means operators only learn about the failure when they next run audit — they've already moved on. Failure should surface at decision-time.

## Decisions

### 2026-04-26 — fix-level chosen
- **Chose:** Level D structural fix — propagate update-task.sh exit code in do_inception_decide
- **Why:** Bug is governance-layer (silent failure) not just text-matching. T-1466/T-1472 closed wording symptoms but the silent layer remains. Per G-019 ("Why did the framework allow this?"), the framework allowed it by not checking gate outcomes.
- **Rejected:** symptom-only fix (continue extending tick patterns reactively) — guaranteed to recur next time wording diverges
- **Rejected:** rely on D13 retroactive detection — too late, operator already moved on
- **Rejected:** rely on `fw inception sweep` running in cron — band-aid; doesn't fix the cause

## Updates

### 2026-04-26T09:48:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1491-rca--doinceptiondecide-records-decision-.md
- **Context:** Initial task creation

### 2026-04-26 — RCA executed
- **Action:** Reproduced T-1388 transition manually (rolled back); git archaeology localized root cause to pre-T-1466 wording dependency + persisting silent-failure layer at lib/inception.sh:454
- **Output:** Findings + Recommendation sections of this task

## Reviewer Verdict (v1.5)

- **Scan ID:** R-51c05cb7
- **Timestamp:** 2026-06-02T14:57:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T09:56:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
