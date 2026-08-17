---
id: T-3063
name: "a killed push and a blocked push are the same branch, and the unpushed count
  has no memory"
description: >
  T-3062 leg 2. handover.sh bounds the push with timeout and routes BOTH the timeout
  and a real gate refusal into one WARNING branch, so 'the gate refused you' and 'the
  gate never finished' are indistinguishable to the caller — the same verdict-vs-absence-of-verdict
  distinction T-2930 already drew for audit exit 75, applied inside the audit but
  not at the caller that bounds it. Second half: the unpushed-commit counter (T-3025,
  handover.sh:384) is stateless, so it reads identically at 1 commit mid-session and
  at 7 commits across 4 failed sessions. The signal fired correctly every time and
  was correctly ignored six times.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/handover/handover.sh, bin/fw]
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
created: 2026-08-17T07:57:51Z
last_update: 2026-08-17T08:30:18Z
date_finished: 2026-08-17T08:30:18Z
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
  - ts: '2026-08-17T08:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-17T08:00:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3063: a killed push and a blocked push are the same branch, and the unpushed count has no memory

## Context

T-3062 leg 2. T-3062 fixed why the push failed (a 347s gate inside a 60s
window). This fixes why nobody noticed for four sessions.

Two defects, one shape — **a state that has no history reads the same at "not
yet" and at "stuck".**

1. **The caller cannot tell a killed gate from a refusing one.**
   `handover.sh:_push_to_remotes` runs `timeout N git push`, and a timeout
   (exit 124) and a genuine gate refusal (exit 1) both land in the same
   `_push_failed=true` branch. A refusal is a *verdict*; a timeout is the
   *absence* of one. T-2930/OBS-221 already drew exactly this distinction for
   audit exit 75 — inside the audit, and never at the caller that bounds it.

2. **The unpushed count is stateless.** T-3025's counter (`handover.sh:384`)
   fired correctly in all four sessions, printing `⚠ N commit(s) NOT pushed`.
   That line reads identically at one commit five minutes old and at seven
   commits across four consecutive failed pushes. The signal was right every
   time and was correctly ignored six times, because nothing in it said *this
   has happened before*.

The fix is memory: persist push outcomes, and let the count say how long it has
been stuck and how many sessions it has survived.

## Acceptance Criteria

### Agent
- [x] A1. A push outcome is persisted across sessions — a failure records what
      kind (killed / refused / other), when it first started failing, and how
      many consecutive sessions it has failed.
- [x] A2. A successful push clears that state, and so does a manual push made
      outside the handover: state that disagrees with `rev-list origin/<b>..HEAD`
      self-heals rather than reporting a stuck push that is no longer stuck.
      (Otherwise the escalation itself becomes the next thing people learn to
      ignore.)
- [x] A3. The handover's unpushed line escalates on repeat — a second and later
      consecutive failure reads visibly differently from a first, names the
      elapsed time, and says what to run. One failure stays quiet: crying wolf
      on the normal case is how the existing signal got tuned out.
- [x] A4. A killed push and a refused push produce different operator-facing
      text, and the killed case names the gate cost as the thing to look at.
- [x] A5. `fw doctor` surfaces a stuck push, so the state is reachable
      deliberately and not only at session end.
- [x] A6. Tests simulate the real failure — a recorded failure streak with
      commits genuinely absent from the remote ref — and assert the escalation
      fires. Including the negative: one failure does NOT escalate, and a
      cleared state produces nothing.
- [x] A7. Every load-bearing assertion is mutation-tested: the mutant turns it
      red, the unmutated suite is green (L-616).

**Verified live, not only in fixtures.** The mechanism demonstrated itself
mid-task on a real failure: `fw handover` auto-committed and its push was
refused on self-vendor drift, which extended a planted streak from 2 to 3 and
flipped `kind` from `killed` to `refused` — and the advice correctly stopped
telling me to go measure the gate, because in that case a gate *had* answered.
`fw doctor` then rendered `WARN Push STUCK: failed 3 consecutive session(s)`,
the handover rendered the 🛑 block, and a successful push cleared the state file
with nothing having told push-state that the push succeeded.

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
# A1-A7 — the streak, the quiet cases, the self-heal, killed-vs-refused wording,
# and both consumer wirings. Guarded form (T-2738): a partial failure must not
# pass on the presence of an "ok" line alone.
out=$(bats tests/unit/t3063_push_state.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The escalation must stay behind a repeat threshold. Asserting the constant
# directly, because a rail that fires on the first failure is the same
# tuned-out signal this task replaces:
grep -q 'if n < 2:' lib/push-state.sh
# Both consumers still read the state (the lib is worthless unwired):
grep -q 'fw_push_state_read "$PROJECT_ROOT"' agents/handover/handover.sh
grep -q 'fw_push_state_read "$PROJECT_ROOT"' bin/fw

## RCA

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

**Symptom.** Seven commits sat unpushed across four sessions with a correct
warning printed in every one of them.

**Root cause.** Two states that differ only in history were represented by
values that carry none.

- `timeout N git push || WARNING` collapses exit 124 (the gate never finished —
  *no verdict*) and exit 1 (a gate finished and refused — *a verdict*) into one
  branch. The operator-facing consequence: "push failed" four times running, with
  nothing indicating that the gate had never actually evaluated anything.
- `rev-list origin/<b>..HEAD` is a count. Counts have no past. `⚠ 7 commit(s) NOT
  pushed` is the correct answer both five minutes into normal work and four
  sessions into a stuck push, and the reader has no way to tell which.

**Why it was structurally allowed.** The framework had already reasoned its way
to exactly this distinction and applied it one level too deep. T-2930/OBS-221
established that audit exit 75 (lock contention) must BLOCK rather than pass,
because *no verdict was produced* — and put that reasoning inside the audit. The
caller that wraps the audit in a 60-second `timeout`, manufacturing the same
verdict-less outcome on every invocation, was never revisited. The precedent
existed; nothing propagated it outward to the callers that can produce the
condition.

The second half is a measurement problem masquerading as a display problem. A
snapshot cannot escalate, and no amount of rewording the count fixes that — the
information needed to distinguish the two states was never being retained
anywhere, so no consumer could have surfaced it.

**Prevention** (distinct from the fix):
- `tests/unit/t3063_push_state.bats` — 14 tests, and the load-bearing ones are
  the *quiet* cases: one failure must not escalate, a success must clear, a
  manual push from anywhere must self-heal, a branch switch must not inherit a
  streak. An escalation rail that fires on the ordinary case decays into the
  same ignored signal it replaced, so those bounds are the deliverable as much
  as the escalation is.
- Five mutations, each shown to turn a specific assertion red — including one
  that exposed a tautological assertion of my own (`first < last || first ==
  last`, always true, which let an overwritten `first_failure_ts` pass). The
  timestamps land in the same second without a deliberate `sleep 1`, so the
  test could not fail; the mutant is what found it, not review.
- `fw doctor` carries the state, so "is the push stuck" is answerable on demand
  instead of only at session end, which is the moment nobody is reading.

**Not a defect, worth recording:** `fw doctor` takes >200s on this repo. Noticed
while verifying A5 and out of scope here — the T-3062 class (a surface nobody
measures growing past the window its callers assume) applied to a different
surface. Not filed as a task; it is one measurement away from being one.

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

### 2026-08-17T07:57:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3063-a-killed-push-and-a-blocked-push-are-the.md
- **Context:** Initial task creation

### 2026-08-17T08:10:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7c615e30
- **Timestamp:** 2026-08-17T08:30:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-17T08:30:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
