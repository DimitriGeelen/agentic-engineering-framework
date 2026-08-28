---
id: T-3206
name: "continuous-run loop cannot report that it is armed - start event plus fw doctor
  surface"
description: >
  continuous-run loop cannot report that it is armed - start event plus fw doctor
  surface

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/claude-fw, bin/fw]
related_tasks: []
arc_id: continuous-run
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
created: 2026-08-28T13:57:13Z
last_update: 2026-08-28T14:15:10Z
date_finished: 2026-08-28T14:15:10Z
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
  - ts: '2026-08-28T14:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=226,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-28T14:00:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3206: continuous-run loop cannot report that it is armed - start event plus fw doctor surface

## Context

T-3182 set out to kill a specific false green: *"the loop stopped" and "the loop was
never armed" are the same observable state.* It shipped `_record_loop_event` in
`bin/claude-fw` with seven call sites — six `exit` reasons and one `iterate`.

Measured today, while this very session runs under `bin/claude-fw` (wrapper PID 1851680,
child `claude -c` PID 1851701): `.context/working/continuous-run.jsonl` **does not
exist.** An armed, live supervisor and no supervisor at all produce byte-identical
evidence on disk.

So the defect survived its own fix, in the state that matters most. T-3182's comment
even names the reason — *"a log that only records endings cannot tell them apart"* —
and then records only endings and iterations. There is no `start` event, so the log
cannot come into existence until the loop is already over.

Second half: T-3182 deliberately deferred surfacing the log through `fw doctor` because
`bin/fw` was held uncommitted by T-3127. **That block has cleared** — T-3127 is
work-completed and `bin/fw` is clean — so the deferred surface is landable now rather
than carried further.

Both halves answer one operator question: *is the loop armed, and if not, why did it
stop?* Today that question costs PID forensics and only works while the processes
happen to still exist.

## Acceptance Criteria

### Agent
- [x] `bin/claude-fw` records a `start` event at arm time, before the first `command claude`, so an armed loop is distinguishable from an absent one **without** waiting for it to end
- [x] The `start` record carries enough to identify the run: wrapper pid, restart-mode (`--no-restart` vs armed), and `MAX_RESTARTS`
- [x] `fw doctor` reads `.context/working/continuous-run.jsonl` and reports the loop's last known state — armed / stopped-with-reason / never-recorded — as three distinguishable outputs, not two
- [x] `fw doctor` degrades to an explicit "never recorded" line when the log is absent, rather than staying silent (silence is the failure mode being fixed)
- [x] The recorder stays non-fatal: a broken/unwritable log never changes the wrapper's exit code and never blocks a restart
- [x] Every new test is mutation-tested; the report names which mutation reddened which test, and any mutation that reddened nothing is investigated rather than waved through

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

## RCA

**Symptom.** T-3182 shipped a loop-event recorder to end a named false green
(*"the loop stopped" and "the loop was never armed" are the same observable
state*). Measured six days later on a live wrapper — this session's own, PID
1851680 — the ledger did not exist. The false green was intact.

**Root cause.** All seven call sites are on terminal paths: six `exit`, one
`iterate`. The ledger therefore cannot come into existence until the loop has
already ended or restarted at least once. For the entire first run of any
wrapper — the state an operator is most likely to be asking about — a healthy
armed supervisor writes nothing, which is byte-identical to no supervisor.

**Why it was not caught.** T-3182's own ACs asserted that `_record_loop_event`
is *defined* and *called*, both true. Nothing asserted that the ledger exists
while the loop is *running*, because the fix's mental model was "record why it
stopped" and the defect it was chasing was one level wider than that: record
enough to distinguish the states. The task comment states the wider goal
correctly — *"a log that only records endings cannot tell them apart"* — and
then the implementation records only endings. Prose and code diverged inside
one commit, with the prose right.

**Prevention.** `tests/unit/t3206_continuous_run_ledger.bats` test 12 asserts
the property directly rather than the mechanism: armed / stopped /
never-recorded must produce three *different* outputs. Any two collapsing
reddens it, whatever the implementation. Test 1 pins the ordering that makes
`start` meaningful (before the loop, not inside it) — mutation M2b confirms it.

## Verification

bash -n bin/claude-fw
bash -n bin/fw
out=$(timeout 300 bats tests/unit/t3206_continuous_run_ledger.bats 2>&1); echo "$out" | grep -q "^ok 12" && ! echo "$out" | grep -q "^not ok"
sl=$(grep -n '_record_loop_event start armed' bin/claude-fw | head -1 | cut -d: -f1); ll=$(grep -n '^while true; do' bin/claude-fw | head -1 | cut -d: -f1); test -n "$sl" && test -n "$ll" && test "$sl" -lt "$ll"
blk=$(sed -n '/# Check: continuous-run loop ledger (T-3206/,/# Check: on-PATH claude-fw drift/p' bin/fw); test "$(printf '%s' "$blk" | wc -l)" -gt 5
grep -q 'Continuous-run loop never recorded' bin/fw
grep -q 'Continuous-run loop STOPPED' bin/fw
grep -q 'GONE with no exit record' bin/fw

## Decisions

### 2026-08-28 — tests execute the shipped source instead of describing it

- **Chose:** each test slices the real block out of `bin/fw` / `bin/claude-fw`
  with `sed` and executes those literal lines, guarded by `assert_extracted`.
- **Why:** 832 sent the rule at arc offset 689 — *a guard that reimplements the
  code it guards cannot detect that code being fixed; the tell is a check whose
  assertion would still hold if the source file were deleted.* 577 sharpened it
  at 690: *prefer a guard that INVOKES its subject over one that RESTATES it.*
  Mutation M7 deletes the entire doctor block and reddens 8 tests, so the design
  demonstrably detects its own subject vanishing.
- **Rejected:** invoking `bin/fw doctor` end-to-end per state — measured at
  **267s** per run, so four states would cost ~18 minutes. Rejected on cost, not
  on principle; extraction keeps the invoke-don't-restate property at ~2s.
- **Rejected:** a hand-written mock of the ledger parser. That is precisely the
  restating guard the rule warns about — it would have kept passing through
  every one of M3-M6.

### 2026-08-28 — vendored copies deliberately NOT synced — ***RETRACTED, see T-3207***

> **This decision was wrong, and wrong on a false measurement.** It is left
> standing rather than deleted so the record shows what was decided and why.
> There was **no** pre-existing vendor drift: `bin/fw` and `bin/claude-fw` were
> byte-identical to their `.agentic-framework/` copies at `b4304ab0a`, the commit
> before this one. The difference I measured was my own edit, because the
> `/tmp/*.bak` "baselines" were taken *after* the edit rather than before. The
> only drift was the one this task introduced, so syncing was never absorbing
> anyone else's work — it was finishing this change. The self-vendor push gate
> (T-2240) refused the push and was correct to. Corrected in T-3207.


- **Chose:** leave `.agentic-framework/bin/fw` and `.agentic-framework/bin/claude-fw`
  untouched.
- **Why:** both were **already** drifted from repo source before this task made
  any edit (verified by diffing the pre-edit backups). Syncing them here would
  carry unrelated, unfinished work into this commit under this task's ID — the
  same reasoning T-3182 used when it deferred the `fw doctor` surface rather than
  editing a `bin/fw` that T-3127 was holding.
- **Rejected:** running `fw vendor self` as a tidy-up. Pre-existing drift is a
  separate finding, surfaced to the operator rather than absorbed silently.

## Evolution

### 2026-08-28 — the task doubled in scope, and that was the right call

- **What changed:** filed as "add a start event". While measuring the defect I
  found T-3182 had *also* deferred the `fw doctor` surface, and had named its
  reason: `bin/fw` was held uncommitted by T-3127. That block had since cleared.
  So the second half was not new scope, it was scope already decided and merely
  parked — and the two halves answer one question, not two.
- **Plan impact:** a start event alone would have written a ledger nothing reads.
  Landing the recorder without the reader would have reproduced T-3182's own
  shape one level out: a mechanism that exists and a question still unanswered.
- **Triggered:** nothing filed. The one thing that could have been — pre-existing
  drift between `bin/{fw,claude-fw}` and their `.agentic-framework/` copies — is
  surfaced to the operator instead, because it predates this task and syncing it
  here would carry unrelated unfinished work under this commit.

### 2026-08-28 — a mutation that reddened nothing, and why it was not the test's fault

- **What changed:** M2 (move the start call inside the loop) reddened nothing. The
  standing rule says that is itself a finding with two possible causes, needing
  different remedies. Diagnosis: `while true; do` occurs three times in
  `bin/claude-fw`, and `str.replace(..., 1)` hit the indented one inside
  `_terminator_watch` at line 136 — still *above* the main loop at 276. The call
  never moved into the loop, so the ordering assertion correctly still held.
- **Plan impact:** the mutation was re-run anchored to the top-level `\nwhile
  true; do\n` (M2b) and reddened test 1. Had M2 been recorded as "test is inert"
  the ordering guard would have been rewritten to chase a defect it did not have.
- **Triggered:** nothing. This is the second session running in which "the mutation
  was not a mutation" was the answer rather than an inert test — T-3204's M3 was
  the same shape. Worth watching as a pattern, not yet worth a rail.

### 2026-08-28 — 267 seconds forced the test design

- **What changed:** the honest test is to invoke `fw doctor` per ledger state.
  Measured: 267s per run, so four states cost ~18 minutes.
- **Plan impact:** rejected end-to-end invocation on cost and switched to slicing
  the shipped block out of `bin/fw` and executing those literal lines — which
  keeps 577's invoke-don't-restate property at ~2s. `assert_extracted` makes the
  design's own failure mode explicit, and M7 proves it (deleting the block reddens
  8 tests).
- **Triggered:** nothing filed. `fw doctor` taking 267s is a real observation about
  the arc's feedback loop and is reported to the operator rather than absorbed.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-28T13:57:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3206-continuous-run-loop-cannot-report-that-i.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6bcbecdf
- **Timestamp:** 2026-08-28T14:15:15Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `fw doctor` reads `.context/working/continuous-run.jsonl` and reports the loop's last known state — armed / stopped-with-reason / never-recorded — as three distinguishable outputs, not two
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/working/continuous-run.jsonl in: `fw doctor` reads `.context/working/continuous-run.jsonl` and reports the loop's last known state — armed / stopped-with-reason / never-recorded — as `

### 2026-08-28T14:15:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
