---
id: T-3275
name: "continuous-driver infers delivery from exit code instead of confirming it"
description: >
  continuous-driver infers delivery from exit code instead of confirming it

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/continuous-driver.sh, tests/unit/t3254_driver_refusals.bats]
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
created: 2026-09-04T15:01:50Z
last_update: 2026-09-04T22:03:52Z
date_finished: 2026-09-04T22:03:52Z
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
  - ts: '2026-09-04T15:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=317,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-04T15:15:17Z'
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
---

# T-3275: continuous-driver infers delivery from exit code instead of confirming it

## Context

`agents/context/continuous-driver.sh:234-238` treats a zero exit status from
`termlink inject` as proof that a continuation turn reached the agent, then writes
`_log "injected"` to the ledger. Nothing observes the target between the call and
the ledger write, so "the transport accepted the call" and "the agent received a
turn" are indistinguishable to the driver.

G-097 is the live instance of that being wrong: `termlink inject` returns exit 0
and delivers nothing into a `claude` TUI. This task does not fix G-097 — that is
homed upstream at TermLink. It fixes the reason G-097 could have run undetected
every ten minutes forever while the ledger reported success.

The driver already owns the primitive that settles it. `_pty_snapshot()` (line 209)
is called twice *before* injecting — `SNAP_A` vs `SNAP_B` across the settle window
is how busy-session detection works. It is never called a third time afterward.

Same class as **L-346** ("claude -p exit=0 is NOT a tool-use signal", T-1700): a
clean exit is not evidence the semantic work happened. That learning did not reach
this code path.

Registered as **G-101** before building, per §When discovering structural flaws.
Independent of G-097 in both directions: this lands without the upstream fix, and
the upstream fix does not close this.

## Acceptance Criteria

### Agent
- [x] After a successful inject call, the driver takes a post-inject snapshot via
      the existing `_pty_snapshot()` helper and checks it, rather than proceeding
      straight to the ledger write. (`continuous-driver.sh`, section 5.)
- [x] When delivery cannot be confirmed, the driver `_bail "refused"` with a message
      naming the unconfirmed-delivery condition — it does NOT write
      `_log "injected"`. A tick that delivered nothing must leave a refusal in the
      ledger, not a success. (C1, C3 assert on the ledger, not on stdout prose.)
- [x] **Negative control:** a test proves the confirmation REFUSES against a target
      that accepts the call but does not receive it (the G-097 shape, simulated with
      a stub transport that exits 0 and writes nothing). Without this leg the suite
      cannot distinguish "confirmation works" from "confirmation always passes". (C1.)
- [x] **Positive control:** a test proves the confirmation ALLOWS a delivery whose
      text reaches the pane, so the guard cannot pass C1 by refusing everything. (C2.)
      **Scope correction (build-time):** as filed this AC said "against a shell-backed
      PTY target". The test stubs the transport, so it *models* delivery rather than
      performing it — a real end-to-end leg would need a working `termlink`, which is
      precisely what G-097 says we do not have. C2 + C5 form the mutation control
      instead: same fixture, confirmation on → refused, confirmation off → injected.
      Recorded rather than silently reworded.
- [x] The false-negative case is addressed explicitly: a target whose pane redraws on
      its own (spinner, clock) must not read as delivery. Resolved by keying on the
      directive's own text, not on change-detection — see `## Decisions`. (C3.)
- [x] `tests/unit/t3254_driver_refusals.bats` still passes with zero skips.
      (21/21; its stub required a fix — see `## Decisions`.)
- [x] `bin/fw vendor self --check` is clean before close (`agents/` is a vendored
      path — OBS-250 ordering: sync BEFORE `--status work-completed`).

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
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
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
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

bash -n agents/context/continuous-driver.sh

# The confirmation must exist AFTER the inject call, not merely somewhere in the
# file — `_pty_snapshot` already appears twice above it for busy-detection, so a
# plain occurrence count would pass on the unfixed script (the false green this
# very task is about). Assert on the post-inject region only.
awk '/termlink inject .*--enter/,0' agents/context/continuous-driver.sh > /tmp/.t3275-tail && grep -q '_pty_snapshot' /tmp/.t3275-tail

# The unconfirmed path must refuse, not log a success.
awk '/termlink inject .*--enter/,0' agents/context/continuous-driver.sh > /tmp/.t3275-tail && grep -q '_bail "refused"' /tmp/.t3275-tail

# The guard must key on the directive TEXT, not merely on the pane changing —
# C3 is the test, this is the static pin.
grep -q 'NEEDLE=' agents/context/continuous-driver.sh

# New suite: both control legs must actually run (T-3217 — a skip reports `ok`).
out=$(bats tests/unit/t3275_delivery_confirmation.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok' && ! echo "$out" | grep -q '# skip'

# Pre-existing refusal suite still green, zero skips (T-3254).
out=$(bats tests/unit/t3254_driver_refusals.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok' && ! echo "$out" | grep -q '# skip'

# Vendored path (agents/) — OBS-250: sync BEFORE close, not after.
bin/fw vendor self --check

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

**Symptom:** the continuous-run driver would report a successful injection on every
tick while the target agent received nothing. Not observed in production only because
the driver was never armed against a real session — G-097's live-fire (T-3255) is what
surfaced it, and the cron entry has been paused since.

**Root cause:** `continuous-driver.sh` treated the transport's exit status as evidence
of delivery. `termlink inject … && _log "injected"` conflates *the call was accepted*
with *the agent received a turn*. Those are different events, and G-097 is the proof
that they come apart in exactly the case the driver cares about most.

**Why structurally allowed:** three things had to line up.

1. **The primitive existed but was not applied at the decision point.** `_pty_snapshot`
   was already written, tested, and called twice — for busy detection, immediately
   above. The capability to tell delivery from silence was present and simply never
   used where it mattered. Nothing flags a helper that is used for one judgement and
   not for the adjacent one.
2. **The learning existed and did not reach the code.** L-346 (T-1700) says verbatim
   that `claude -p exit=0 is NOT a tool-use signal`. Same class, recorded, and it
   never propagated to a second consumer of the same reasoning. Learnings are
   retrieved by whoever thinks to search; nothing pushes them at a new code path that
   is about to repeat the mistake.
3. **The test fixture encoded the same assumption as the code.** T-3254's stub served
   a constant pane, so its "an injection is recorded" case was modelling an accepting,
   non-delivering transport and asserting success on it. A suite written by the same
   reasoning as the implementation inherits its blind spot — the fixture agreed with
   the bug, so the bug looked tested.

The third is the one worth carrying forward: the code and its test were not
independent checks, and 21 green tests read as coverage of exactly the thing they
could not see.

**Prevention (distinct from the fix):**

- `tests/unit/t3275_delivery_confirmation.bats` — 6 tests, with C1/C2 as a mutation
  control pair (same fixture; confirmation on → refused, off → injected) so the suite
  cannot pass by always-refusing or always-allowing, and C3 as the discriminator that
  a change-detection implementation would fail.
- T-3254's stub corrected, so the pre-existing suite no longer asserts the bug.
- Static pins in `## Verification` scoped to the **post-inject region** — a whole-file
  grep for `_pty_snapshot` passes on the unfixed script, which is the same false green
  as the defect.
- **G-101** stays open in the register until the guard has run against a real target
  (T-3257); a passing unit suite is not a live-fire.

**Not prevented here:** the driver still cannot reach a session launched outside
TermLink (G-098), and the transport itself is still broken upstream (G-097). This task
makes the driver honest about failure; it does not make it succeed.

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

### 2026-09-04 — confirm on the directive's TEXT, not on "the pane changed"

- **Chose:** delivery is confirmed only when a whitespace-stripped 32-char prefix of
  the directive appears in the post-inject pane capture. Fail closed: if it never
  appears, refuse.
- **Why:** change-detection is the cheaper check and was the obvious first instinct,
  but it cannot separate delivery from a pane redrawing itself. A spinner, clock or
  progress line changes the capture without any input having landed, so a
  change-based guard reports success on an undelivered tick — reintroducing the
  exact false green G-101 exists to remove. The asymmetry decides it: a wrong
  refusal costs ONE tick and announces itself in the ledger; a wrong success costs
  every tick after it and announces nothing. C3 is the regression test — it passes
  a change-based guard and fails a text-based one, which is why it exists.
- **Rejected:** (a) change-detection alone, for the reason above. (b) Requiring the
  *whole* directive to appear — a TUI wraps long input and the capture is tailed to
  4000 bytes, so a long directive would produce false refusals. (c) Accepting either
  signal (text OR change) — that is change-detection with extra steps, since the
  weaker condition always decides.

### 2026-09-04 — strip ALL whitespace from both sides of the comparison

- **Chose:** `tr -d '[:space:]'` on both needle and haystack before matching.
- **Why:** a TUI wrapping input can insert a newline mid-word (`backl\nog`), which
  defeats a matcher that merely collapses whitespace runs. Stripping whitespace
  entirely makes the needle wrap-immune. C6 pins it.
- **Rejected:** collapsing runs to single spaces (`tr -s`) — fails the mid-word wrap,
  which is the common case for a long directive in a narrow pane.

### 2026-09-04 — `case` on a captured variable, never a pipe into `grep -q`

- **Chose:** capture the squashed pane into a variable and match with `case`.
- **Why:** the script runs under `set -uo pipefail`. An early-exiting `grep -q`
  SIGPIPEs its upstream and the pipeline returns 141 (L-387), so the guard would
  manufacture false refusals through its own plumbing — a bug in the same family as
  the one it is fixing.

### 2026-09-04 — T-3254's stub was modelling the bug as its success case

- **Chose:** fix `_stub_termlink` in `tests/unit/t3254_driver_refusals.bats` so an
  injecting transport also writes the text into the pane the stub serves.
- **Why:** its `quiet` mode returned a constant pane, so its C2 ("an injection is
  recorded") was exercising a transport that accepts and delivers nothing — the
  G-097 shape — and calling it success. That is why the pre-existing suite could
  never have caught G-097, and it is the more interesting half of this finding: the
  fixture encoded the same assumption the production code did. Both were fixed here.
- **Rejected:** special-casing the new guard to tolerate a constant pane. That would
  have kept the suite green by teaching the guard to accept the exact input it
  exists to reject.

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

### 2026-09-04T15:01:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3275-continuous-driver-infers-delivery-from-e.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ec44d68f
- **Timestamp:** 2026-09-04T22:04:33Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `out=$(bats tests/unit/t3275_delivery_confirmation.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok' && ! echo "$out" | grep -q '# skip'`

### 2026-09-04T22:03:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
