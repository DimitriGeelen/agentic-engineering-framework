---
id: T-3077
name: "governance test suite leaves live Tier 0 approval requests in the operator
  queue"
description: >
  tests/governance/test_pretooluse_gates.bats runs the real check-tier0 hook against
  the real FRAMEWORK_ROOT. _tier0_isolate backs up .tier0-approval (the GRANTED file)
  but check-tier0.sh:463 writes .tier0-approval.pending plus .context/approvals/pending-<hash>.yaml,
  which the helper never touches. Result: rm -rf / and git push --force origin master
  appear as live PENDING entries on Watchtower /approvals. Operator saw them and asked.
  If approved, a genuine rm -rf / becomes pre-authorised.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
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
created: 2026-08-18T18:33:41Z
last_update: 2026-08-18T18:48:25Z
date_finished:
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
  - ts: '2026-08-18T18:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=282,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-18T18:45:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3077: governance test suite leaves live Tier 0 approval requests in the operator queue

## Context

**Nothing destructive ran, and nothing was ever approved.** Both statements are
measured below, not assumed. What leaked is a *request for permission*, which is a
different object from the command it names — but it is a dangerous one to leave
sitting in a queue with an Approve button next to it.

### What the operator saw

Watchtower `/approvals`, 2026-08-18T18:30:49Z, two live PENDING entries:

    RECURSIVE DELETE: Targets root filesystem (/)      rm -rf /
    FORCE PUSH: Can overwrite remote commit history    git push --force origin master

### Mechanism

`tests/governance/test_pretooluse_gates.bats:112-129` proves the Tier 0 gate blocks
these two commands. It does so correctly: the command is passed as a **JSON string
on stdin** to the hook — `echo "$INPUT" | "$HOOK_BIN" hook check-tier0` — and the
hook is asserted to exit 2. No shell ever receives the text. That part works.

The leak is the hook's side effect. `agents/context/check-tier0.sh:463-470` writes
**two** records when it blocks, so the operator can grant the request:

    .context/working/.tier0-approval.pending          (hash + epoch + PENDING)
    .context/approvals/pending-<hash12>.yaml          (the Watchtower card, T-611)

The suite's isolation helper backs up neither:

    _tier0_isolate()  → mv .context/working/.tier0-approval  $BACKUP
    _tier0_restore()  → mv $BACKUP  .context/working/.tier0-approval

`.tier0-approval` is the **granted** file. The two files the hook actually writes
are untouched, so they land in the live project and stay there.

### Severity — it is the Approve button, not the string

A YAML file containing the text `rm -rf /` is inert. The hazard is that this card is
wired to a real grant: approving it writes the command **hash** into
`.context/working/.tier0-approval`, and `check-tier0.sh` admits any future command
whose normalised text hashes to the same value. So an operator clearing what looks
like queue noise would pre-authorise a genuine `rm -rf /` — and the next one would
pass the gate silently, exactly once, with no further prompt.

Confirmed the stored hash is that command verbatim:

    printf '%s' 'rm -rf /' | sha256sum
    → 5c7923bd67b06c93279d49c466301c57023822eec29c49e269063e47aecd973c
    stored in .tier0-approval.pending: identical

### How long, and whether it ever mattered

Not a one-off. `git log --diff-filter=A -- '.context/approvals/pending-*'` shows 38
such cards added over time, with the `rm -rf /` card added and **committed** on:

    2026-04-30  3682caafb  T-077
    2026-08-05  30f3752e0  T-2805
    2026-08-17  f507c6ec2  T-3050
    2026-08-18             (today, T-3076 worker — cleared)

Nearly four months, four occurrences. **Never granted:** zero occurrences of that
hash in `.tier0-approval` across all history, and zero `approved-*` files ever
written. The gate never opened. That is the measured reassurance, and it is also
the reason the defect survived — it has been harmless every time so far.

### The fix was written down on 2026-04-24 and never applied

This is the part that matters more than the bug. **L-256** (T-1428, 2026-04-24):

> bats tests that invoke hooks writing to `.context/` (check-tier0.sh, observe,
> handover) MUST export `PROJECT_ROOT=TEST_TEMP_DIR` in `setup()` — otherwise they
> pollute the real project state. Same class as L-227 (observe.bats) and L-009
> (handover.bats). **Discovered when T-1427's test leaked 3 real pending Tier 0
> approvals into `.context/approvals/`.**
>
> `application: TBD`

Same surface. Same artefact. Same count. Four months ago. The learning names the
exact one-line fix, and `tests/governance/test_pretooluse_gates.bats` has no
`setup()` and never exports `PROJECT_ROOT`. Verified applicable:
`lib/paths.sh:39` guards derivation with `if [[ -z "${PROJECT_ROOT:-}" ]]`, so an
env override is honoured — the prescription works as written.

L-227 and L-009 make it three prior recordings of the class before this one.

**And the file asserts the opposite of the truth.** Its header comment reads:

    # State-dependent tests use save/restore for isolation. No mutating side effects.

That sentence is why nobody re-checked. A reader looking for leak risk finds an
explicit denial in the first twenty lines, written by someone who believed it.

**The second-order finding, which is bigger than this task.** L-021 (T-1075) and
L-256 (T-1428) are the same shape: a learning that names its own fix, marked
`application: TBD`, left standing for months while the defect it describes stays
live. Both surfaced in one session, by accident, because `fw work-on` printed them
as "related knowledge" *after* the bug had already been rediscovered independently.
A learning with a prescriptive fix and no application is a latent unfixed bug, and
nothing in the framework distinguishes it from an observation. Not in scope here —
recorded so it can be filed on its own evidence.

### Today's trigger

The T-3076 dispatch prompt instructed the worker to run
`tests/governance/test_pretooluse_gates.bats` among the regression suites. Any run
of that suite by anyone reproduces this.

### Why the framework allowed it (G-019)

Two structural omissions, and the second is the one that matters:

1. **The test's isolation names the wrong file.** A helper called `_tier0_isolate`
   reads as covering Tier 0 state; it covers one third of it. Nothing asserts that
   the suite leaves the approvals surface as it found it.
2. **Nothing detects a stale pending approval.** `fw doctor` and `fw audit` both
   run daily and neither reports a Tier 0 request sitting unanswered in the queue.
   Three of these were committed to git and none was noticed until an operator
   happened to open `/approvals` and ask. A pending approval is a governance object
   with an expiry expectation and no expiry check.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **A1 — the suite leaves the live approvals surface byte-identical.** A guard
      test snapshots `.context/approvals/` and `.context/working/.tier0-approval*`
      before a full run of `tests/governance/test_pretooluse_gates.bats`, runs it,
      and asserts the snapshot is unchanged. Asserted on content, not on a count —
      a card that is created and deleted still passes a count check and still
      appears on `/approvals` for the duration of the run.
- [x] **A2 — isolation by construction, not cleanup afterwards.** The hook under
      test writes to a temporary root, so an interrupted or crashed run cannot
      leave a card behind. A `teardown()` that deletes the card is NOT sufficient
      and does not satisfy this AC: bats teardown does not run when the process is
      killed, and the current helper already demonstrates that a cleanup naming
      the wrong file looks identical to one that works.
- [x] **A3 — positive control, both directions (L-616).** The test asserts a
      pending card IS written inside the sandbox (proving the hook still fired,
      still blocked, and still filed its request) and is NOT written to the live
      tree. Without the first half, A1 is satisfied by a test that has stopped
      exercising the hook at all — two empty sets are equal.
- [ ] **A4 — the sibling suites are surveyed and the result recorded.** L-256
      (T-1428) names this class as covering more than one hook that writes into
      `.context/` from tests. Enumerate which test files invoke such hooks against
      the live tree, and record the finding in this task: fixed here if it is the
      same helper, filed as its own task if not. Survey and record only — do not
      fix unrelated suites here (one bug, one task).
- [x] **A5 — mutation-tested.** Reverting the isolation to the current
      `_tier0_isolate`/`_tier0_restore` pair turns A1's guard test red; restoring
      it turns it green. The flipped test names are recorded in `## Evolution`.
- [x] **A6 — L-256 is closed out or explicitly scoped, not duplicated.** If this
      task closes the class L-256 describes, update it in place with `closed_by`.
      If it closes only part, say which part and leave the rest open with what
      remains. Do not file a second learning describing the same class — that is
      the failure mode this task exists to break (L-021/T-1075 was the same shape
      and cost four months).

**Deliberately out of scope, filed separately** so this stays one deliverable:

| Concern | Task |
|---|---|
| Cards assert "Agent blocked — requires your decision" for requests no agent made; no provenance on the card | T-3078 |
| Nothing detects a Tier 0 request left sitting unanswered — three reached git unnoticed | T-3079 |
| Watchtower grants a 1h TTL where the CLI grants 5m; the easier path to click is 12× more permissive | T-3080 |

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

# T-3077 guard: the gates suite must not touch the live Tier 0 approvals surface.
out=$(bats tests/governance/test_t3077_approvals_surface_isolation.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The Tier 0 gate tests still fire, block and file their request (in the sandbox).
bats tests/governance/test_pretooluse_gates.bats > .context/working/.t3077-gates.out 2>&1 || true
grep -q "^ok 7 check-tier0: blocks" .context/working/.t3077-gates.out
grep -q "^ok 8 check-tier0: blocks" .context/working/.t3077-gates.out
grep -q "^ok 9 check-tier0: ALLOWS benign" .context/working/.t3077-gates.out
# The live surface is clean after the run.
bin/fw tier0 status 2>&1 | grep -q "No pending blocks or approvals"
# The GRANTED file is never created by a test run.
test ! -e .context/working/.tier0-approval

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

## RCA

**Symptom:** Watchtower `/approvals` showed live PENDING Tier 0 cards for `rm -rf /`
and `git push --force origin master`, each with an Approve button, generated by
`tests/governance/test_pretooluse_gates.bats`. Nothing ran; nothing was granted.

**Root cause:** the suite invoked the real `check-tier0` hook with no `PROJECT_ROOT`
override, so `APPROVAL_FILE` (check-tier0.sh:63) and `APPROVAL_DIR` (check-tier0.sh:466)
resolved to the live project. Its `_tier0_isolate`/`_tier0_restore` helper moved
`.context/working/.tier0-approval` — the GRANTED file — aside, and touched neither of
the two files the hook actually writes when it blocks
(`.tier0-approval.pending`, `.context/approvals/pending-<hash12>.yaml`).

**Why structurally allowed:** three compounding reasons. (1) A helper named
`_tier0_isolate` reads as covering Tier 0 state; it covered one third of it, and a
helper naming the wrong file is indistinguishable from one that works. (2) The file
header asserted "No mutating side effects" — a reader looking for leak risk found an
explicit denial in the first twenty lines. (3) The prescribed fix existed as **L-256**
(T-1428, 2026-04-24) with `application: TBD`, so a learning that named its own one-line
fix sat unapplied for four months while the defect stayed live. Nothing distinguishes a
prescriptive-but-unapplied learning from an observation.

**Prevention (distinct from the fix):** `tests/governance/test_t3077_approvals_surface_isolation.bats`
audits the suite from outside, **sampling the live approvals surface throughout the run**
rather than comparing only before/after — so a card that is created and cleaned up before
the suite exits still fails, because it was visible on `/approvals` while it existed. It
also asserts the Tier 0 tests are still present and passing, so an empty-vs-empty pass
cannot be bought by deleting the coverage. The guard is hook-agnostic: it holds the whole
file to the invariant whatever hook a future test reaches for. L-256 updated in place with
`closed_by` + the two sandbox preconditions the original prescription omitted.

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

### 2026-08-18 — sandbox scope, and what the prescription left out

- **What changed:** L-256 prescribes `export PROJECT_ROOT=TEST_TEMP_DIR` in `setup()`.
  Measured here, that is necessary but not sufficient, and it is a silent no-op in the
  failure case. Two preconditions, both verified by direct experiment:
  1. The sandbox root must contain `.tasks/` (or `.framework.yaml`). `bin/fw`'s
     `_project_root_is_stale()` (bin/fw:174-186) treats a markerless directory as stale
     and **re-resolves to the live project** — with a bare `mktemp -d` root the export is
     ignored and the card leaks exactly as before. Reproduced: bare temp dir → card in
     the live tree; temp dir + `.tasks/` → card in the sandbox.
  2. The sandbox must contain `.context/working/`. `check-tier0.sh:463` writes
     `${APPROVAL_FILE}.pending` with a bare redirect and no `mkdir -p`; without the
     directory the write fails with "No such file or directory" (the approvals dir the
     hook creates itself).
- **Plan impact:** the sandbox is applied to the `check-tier0` invocations, **not exported
  file-wide**. Measured: a file-wide export flips `check-active-task` from allow to block
  (test #5, a known pre-existing failure, would turn green for environmental reasons and
  not because it was fixed), and the two `check-project-boundary` tests assert against the
  live root by design. Widening the export would silently rewrite what those tests mean.
  The durability requirement A2 asks for is carried by the external guard file instead,
  which is hook-agnostic and does not depend on future authors using the right helper.
- **Triggered:** A4 survey found a second offender —
  `tests/unit/doctor_hook_exercise.bats` (see A4 record below). Filed as its own task,
  per one-bug-one-task.

### 2026-08-18 — A5 mutation result (test names)

Reverted `tests/governance/test_pretooluse_gates.bats` to the committed
`_tier0_isolate`/`_tier0_restore` version and re-ran the guard:

| Guard test | With old helper | With fix restored |
|---|---|---|
| `T-3077 A1: gates suite leaves the live approvals surface byte-identical` | **not ok** — reported `pending-17d4dd0baaec.yaml`, `pending-5c7923bd67b0.yaml`, `.tier0-approval.pending` observed live | ok |
| `T-3077: the suite never writes the GRANTED approval file` | ok | ok |

Recorded honestly: only **one** of the two guard tests flips. The second is a standing
invariant about the granted file (`.context/working/.tier0-approval`), which neither the
old nor the new suite writes — it guards a different, higher-severity outcome and is
expected to stay green. A1 is the mutation-sensitive assertion.

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

### 2026-08-18T18:33:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3077-governance-test-suite-leaves-live-tier-0.md
- **Context:** Initial task creation

### 2026-08-18T18:45:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
