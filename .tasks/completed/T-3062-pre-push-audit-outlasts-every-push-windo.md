---
id: T-3062
name: "pre-push audit outlasts every push window, so pushes die silently instead of
  being blocked"
description: >
  pre-push audit outlasts every push window, so pushes die silently instead of being
  blocked

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, agents/handover/handover.sh]
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
created: 2026-08-17T07:41:15Z
last_update: 2026-08-17T08:01:22Z
date_finished: 2026-08-17T08:01:22Z
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
cost_estimate_proposed:
  - ts: '2026-08-17T07:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-17T07:45:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3062: pre-push audit outlasts every push window, so pushes die silently instead of being blocked

## Context

Seven commits sat unpushed across four sessions. Each session's push was killed
by session teardown partway through the pre-push hook's audit, and *nothing ever
said so* — the handover prints one WARNING line and exits 0 by design (T-1277),
so the next session started with no signal that the previous one had failed to
land its work.

The push was never blocked. It was killed. Those look identical from the outside,
which is why it recurred four times.

Measured: `agents/audit/audit.sh --section structure` — the subset T-862 carved
out *because the full audit was too slow* — now exceeds 300s in this repo. The
handover bounds each push at 60s (`_push_timeout`). The gate cannot finish inside
the window it is given, on any path.

## Acceptance Criteria

Scope note: this task fixes the *cause* — the gate cannot finish. The second
defect the RCA found (the unpushed-commit warning has no memory, so it reads
identically at one commit and at seven-across-four-sessions) is a separate
deliverable, filed as T-3063.

### Agent
- [x] A1. The wall-clock cost of the pre-push structure audit is measured **per
      check**, and the checks responsible for the overrun are named in `## RCA`
      with their individual timings — not the aggregate, which is what hid this.
- [x] A2. The whole-tracked-tree scanners move out of the per-push horizon into
      one that matches what they were built for, and are demonstrably still run
      by the daily full audit rather than quietly dropped.
- [x] A3. The pre-push gate completes inside a stated budget on this repo, and
      the budget is asserted by a test that runs the gate — not described in a
      comment. (T-862's "fast audit subset" comment was true when written and is
      now false; a comment cannot notice it has gone stale.)
- [x] A4. That timing test refuses to pass on an audit that did not actually
      run. A harness that fails to launch finishes in milliseconds and clears
      any budget, so the fastest possible pass would otherwise be the most
      broken one (L-616).
- [x] A5. A static invariant in `tests/lint/` refuses a whole-tree scan inside
      the per-push section, so the regression is caught at audit time rather
      than by the next operator whose commits go missing.
- [x] A6. The push timeout and the gate budget are asserted **against each
      other**. Each was independently plausible; only their relationship was
      wrong.
- [x] A7. Every load-bearing assertion above is mutation-tested — the mutant is
      shown to turn it red, and the unmutated suite is shown to be green.

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
#
# A1/A2/A5/A6 — shape invariants, and the split did not drop the scanners:
out=$(bats tests/lint/prepush-gate-budget.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# A3/A4 — the gate is measured against its budget, and a truncated audit cannot pass:
out=$(bats tests/unit/t3062_prepush_runtime.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The whole invariant suite the audit runs stays green (this file is now in it):
out=$(bats tests/lint/ 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The scanners still run under a full audit — assert on the tree section, not on a 6-minute run:
grep -q 'if should_run_section "tree"; then' agents/audit/audit.sh

## RCA

**Symptom.** Seven commits sat unpushed on `t2539-staging` across four sessions.
Each session ended with one line — `WARNING: Push to origin timed out after 60s
(non-blocking, T-1277)` — and exited 0.

**What did not fail.** Detection. T-3025's unpushed-commit counter
(`handover.sh:384`) fired correctly and printed `⚠ 7 commit(s) NOT pushed` in
every one of those sessions' handovers. This RCA is not about a missing signal.

**Root cause.** The pre-push hook runs `audit.sh --section structure`. The
handover bounds a push at `FW_HANDOVER_PUSH_TIMEOUT` (60s). Measured on this
repo, per check:

| segment | cost |
|---|---:|
| everything through the hook-threshold check (~25 checks) | 51s |
| **secret scan** — `secret-scan.sh scan-tree` (T-1845) | **188s** |
| **large-file gate** — `large-file-scan.sh scan-tree` (T-1845) | **95s** |
| self-vendor drift, invariant suite, designer/map conformance, gitignore | 13s |
| **total** | **347s** |

Two checks were 82% of it. The gate could not finish inside its window on any
path, so every push through the handover was **killed at 60s, not evaluated**.

**Why it was structurally allowed.** Three things, and the third is the one that
matters.

1. `--section structure` is two horizons wearing one name. T-862 carved it out
   as the *pre-push* subset. T-1845 later added the tree scanners to it,
   correctly reasoning that these gates were pre-commit-only and needed to run
   "at the audit horizon" — but the audit horizon it meant is the daily cron,
   and the section it landed in also fires on every push. Neither task was
   wrong; nothing held their two contracts next to each other.
2. Nothing measured the gate. T-862's comment says "fast audit subset" and was
   accurate the day it was written. A comment cannot notice it has gone stale,
   and the section grew one reasonable check at a time.
3. **A killed push and a blocked push are the same branch in `handover.sh`.**
   `timeout 60 git push ... || WARNING` cannot tell "the gate refused you" from
   "the gate never finished". One is a verdict, the other is the absence of one
   — the same distinction T-2930/OBS-221 already drew for audit exit 75, in this
   same gate, and the reason exit 75 blocks instead of passing. That reasoning
   was applied inside the audit and not at the caller that bounds it.

**The 30-minute tax.** `structural-30m` cron runs `--section
structure,compliance,quality,discovery` every 1800s and was paying the same 283s
every time. That is the source of the audit lock contention recorded under
T-1719/OBS-221; a 347s job on a 1800s period contends with every push and every
hourly job. Fixing the push window fixed that as a side effect.

**Prevention** (distinct from the fix):
- `tests/lint/prepush-gate-budget.bats` — refuses a `scan-tree` inside the
  per-push section, refuses a push timeout that does not clear the gate, and
  asserts the scanners are still *invoked* in `tree` (mutation showed that
  matching the variable name alone passes for a renamed, disabled gate).
- `tests/unit/t3062_prepush_runtime.bats` — runs the gate and fails over budget.
  Held to the L-616 rule: it refuses to pass on an audit that did not run to
  completion, because a harness that fails to launch clears any budget in
  milliseconds.
- Not fixed here: defect 3 above. A push that dies mid-gate still reports as a
  plain warning, and the next session's unpushed count reads identically at one
  commit and at seven-across-four-sessions. Filed as **T-3063**.

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-17T07:41:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3062-pre-push-audit-outlasts-every-push-windo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e2e8e324
- **Timestamp:** 2026-08-17T08:02:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-17T08:01:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
