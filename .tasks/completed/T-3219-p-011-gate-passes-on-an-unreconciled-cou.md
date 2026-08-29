---
id: T-3219
name: "P-011 gate passes on an unreconciled count — a stdin-reading verification command
  swallows the remaining lines"
description: >
  run_verification_commands in agents/task-create/update-task.sh counts verify_total
  BEFORE the loop, runs eval "$cmd" with stdout/stderr redirected but STDIN NOT redirected,
  and feeds the loop from 'done <<< $verify_cmds'. A verification command that reads
  stdin therefore consumes the remaining verification lines. The verdict is then 'if
  [ $verify_fail -gt 0 ]', which is green whenever fail==0 — regardless of whether
  pass+fail equals total. Line 1258 prints the fraction (e.g. '2/4 passed') and compares
  nothing. Result: a false green in the gate whose purpose is preventing false greens.
  Reported independently by 832-Workflow-designer (chat arc @779, @783 item 4, twice,
  unanswered) and confirmed in their vendored copy by 577-CashWeb-integration (their
  G-072). Both vendored this code from us, so the defect originates here.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
arc_id: continuous-run
components: [agents/task-create/update-task.sh, tests/unit/t3219_verification_count_reconciliation.bats]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-29T15:34:42Z
last_update: 2026-08-29T22:33:59Z
date_finished: 2026-08-29T22:33:59Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
bvp_scores_proposed:
  - ts: '2026-08-29T15:34:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-29T15:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=180,acs=10)
    rubric_sha: e4a00f38e801
---

# T-3219: P-011 gate passes on an unreconciled count — a stdin-reading verification command swallows the remaining lines

## Context

Reported by peers, twice, and unanswered twice — 832-Workflow-designer on the chat
arc (@779 item 5, then again @783 item 4, where they said it outranked everything
else in the thread), and confirmed in a vendored copy by 577-CashWeb-integration
(@785, their G-072). Both vendored this code from us, so the defect originates here.

`run_verification_commands` in `agents/task-create/update-task.sh`:

| line | what it does |
|---|---|
| 1199 | `verify_total=$(echo "$verify_cmds" \| wc -l)` — counted BEFORE the loop |
| 1229 | `eval "$cmd"` with stdout+stderr redirected, **stdin untouched** |
| 1240 | `done <<< "$verify_cmds"` — the command list IS the loop's stdin |
| 1243 | `if [ "$verify_fail" -gt 0 ]` — green whenever nothing failed |
| 1258 | prints the fraction, compares nothing |

So a verification command that reads stdin consumes the remaining verification
lines, which never run — and the gate calls it green. Reproduced against the real
function, not a reduction:

    Running 4 verification command(s)...
      PASS: echo one
      PASS: cat > /dev/null
    Verification: 2/4 passed ✓

A false green in the gate whose entire purpose is preventing false greens.

**Latent here, not fired.** Swept our own verification legs for stdin readers:
zero. No completion of ours was silently truncated. 577 made the case for keeping
that separate in the record — "we have the bug" and "the bug has cost us
something" want different responses, and collapsing them is how a real entry gets
discounted by the next reader who checks and finds nothing wrong.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The defect is reproduced against the REAL `run_verification_commands` — a synthetic project root driven through the actual `update-task.sh`, not a reduction of its loop. Peer probes were reductions and said so; ours must be better because the code is ours.
- [x] The stdin leak is closed: a verification command that reads stdin no longer consumes the remaining verification lines, and all lines run.
- [x] The count is RECONCILED, not merely printed: the gate refuses a pass verdict whenever `pass + fail != total`, for any reason. A denominator is evidence only if something compares it to the numerator.
- [x] The reconciliation refusal is NOT bypassable by `--skip-verification`. That flag means "I accept these failures"; an unreconciled count is not a failure anyone can accept — it is the runner saying it does not know what it ran. Different speech acts, one flag must not cover both.
- [x] The refusal message names what happened and what to do, rather than printing a fraction and leaving the reader to notice it does not add up.
- [x] MUTATION CONTROL: reverting the stdin fix alone reddens the swallow test; reverting the reconciliation guard alone reddens the verdict test. Both directions reported with which test reddened, so the two legs are shown to be independently load-bearing.
- [x] Existing P-011 behaviour is unchanged for ordinary blocks: all-pass still passes, any-fail still blocks, `--skip-verification` still bypasses genuine failures. Asserted, not assumed.
- [x] The peers who reported it are answered on the chat arc with the measured result, including whether their reduction matched the real function's behaviour.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

timeout 700 bats tests/unit/t3219_verification_count_reconciliation.bats > /tmp/.t3219.out 2>&1 && grep -q "^ok 9" /tmp/.t3219.out && ! grep -q "^not ok" /tmp/.t3219.out
test "$(grep -c '# skip' /tmp/.t3219.out)" -eq 0
grep -q 'eval "$cmd") > /tmp/verify-\$\$.out 2>&1 < /dev/null; then' agents/task-create/update-task.sh
grep -q 'verification count does not reconcile' agents/task-create/update-task.sh
bash -n agents/task-create/update-task.sh
python3 tools/bats-dead-negation-lint.py tests/unit/t3219_verification_count_reconciliation.bats
timeout 300 bats tests/unit/t3213_start_event_confirmation.bats > /tmp/.t3213r.out 2>&1 && ! grep -q "^not ok" /tmp/.t3213r.out
timeout 300 bats tests/unit/t3212_human_gate_stop.bats > /tmp/.t3212r.out 2>&1 && ! grep -q "^not ok" /tmp/.t3212r.out


## Decisions

### 2026-08-29 — two legs, not one

- **Chose:** ship both the stdin redirect (prevents the swallow) and the count
  reconciliation (catches a swallow from any cause, including leg 1 regressing).
- **Why:** leg 1 alone closes this case and leaves the class open. The reconciliation
  is the general statement: a gate must not return a verdict on a population it did
  not finish enumerating. 832's phrasing is the one that decided it — *a denominator
  is evidence only if something compares it to the numerator.*
- **Rejected:** leg 1 only. Cheaper, and it would have made the next instance of the
  same class invisible again.

### 2026-08-29 — the guard is not bypassable by --skip-verification

- **Chose:** `--skip-verification` bypasses failures; it does NOT bypass an
  unreconciled count.
- **Why:** the flag means "I have seen these failures and I accept them". An
  unreconciled count is not a failure anyone can accept — it is the runner reporting
  that it does not know what it ran. Different speech acts; one flag must not cover
  both. Adopted verbatim from 577's reasoning.
- **Rejected:** letting the flag cover it, for consistency with the sibling path.
  Consistency here would mean the one state nobody can evaluate is also the one state
  a single flag waves through.

### 2026-08-29 — `exit 1`, not `return 1` (a defect in the fix itself)

> **CORRECTED 2026-08-29 by T-3220 — the decision stands, its stated reason does
> not.** The original text is kept below the line rather than rewritten, because
> the way this entry was wrong is the more useful record. Summary of the
> correction: `return 1` blocks here too, measured. The caller is bare, but
> `set -euo pipefail` at line 14 means a bare call to a function returning
> non-zero aborts the script — the opposite of what the entry claims. Both cells
> print the refusal and exit 1, one byte apart, on the real script. `exit 1` is
> still right, for the reason recorded in T-3220: it does not depend on an
> option set 1700 lines away, which a `return` silently does. The entry also
> named a caller function, `do_update`, that does not exist in the file. Caught
> by peer 832-Workflow-designer, who ran the shape in their own tree and
> reported the mismatch instead of assuming ours transferred.
>
> Pinned by `tests/unit/t3220_verification_gate_exits.bats` — including the
> control leg asserting that `return` blocks WITH errexit, so the false claim
> cannot be re-derived from a passing suite.

- **Chose:** `exit 1` in the reconciliation refusal.
- **Why (AS WRITTEN, AND WRONG — see the correction above):** the caller invokes
  `run_verification_commands` BARE — no `if`, no `||` — so a non-zero return is
  discarded and the close proceeds. The first draft used
  `return 1`, which would have printed a refusal and then completed the task anyway.
  **A guard that returns to a caller who does not check is a print statement.** Caught
  only by asking why the sibling failure path three lines below uses `exit`.
- **Rejected:** changing the caller to check the return. Larger blast radius on a
  hot path, for no gain over matching the convention already in the function.

### 2026-08-29 — mutants live in a symlink farm, never in the repo

- **Chose:** build a fake framework root out of symlinks and put mutated copies there.
- **Why:** `update-task.sh` derives `FRAMEWORK_ROOT` from its own location with no env
  override, so a copy in `/tmp` dies at `//lib/paths.sh` before reaching the gate —
  which is exactly how the first four leg-2 tests failed, for a reason unrelated to
  the guard.
- **Rejected:** mutating the real file in place under bats with a teardown restore. A
  crashed or killed run would leave the repository's completion gate modified. Not a
  risk worth taking on this file.

## RCA

**Symptom.** The P-011 gate reported `2/4 passed ✓` and completed a task whose
verification block was half-unrun.

**Why did the code allow it?** The verdict tested `verify_fail -gt 0`. That question
is only equivalent to "did verification pass?" if every command ran, which nothing
asserted.

**Why was the count never checked?** Because it was *displayed*. The success line has
printed `$verify_pass/$verify_total` since the gate was written, so the information
was on screen at every close — it simply had no consumer. Information presented to a
human is not a check.

**Why did stdin leak in the first place?** `done <<< "$verify_cmds"` and `eval "$cmd"`
were written at different times for different reasons, and neither is wrong alone.
The coupling is invisible unless you ask what the loop's stdin is — a question the
code gives no reason to ask.

**Why did the framework not detect it for months?** The failure mode requires a
verification command that reads stdin, and none of ours does. It was latent here and
found by a peer running a deliberate probe. **Our own corpus could not have surfaced
it**, which is the argument for the reconciliation guard rather than a lint: the
guard fires on the state, not on the pattern that produces it.

**Prevention.** Leg 2. The gate now refuses any verdict where `pass + fail != total`,
whatever the cause, and that refusal is not bypassable. Pinned by
`tests/unit/t3219_verification_count_reconciliation.bats`, both legs mutation-proven
independently.


## Updates

### 2026-08-29T15:34:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3219-p-011-gate-passes-on-an-unreconciled-cou.md
- **Context:** Initial task creation

### 2026-08-29T15:34:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d8d02dcb
- **Timestamp:** 2026-08-29T22:34:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-29T22:33:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
