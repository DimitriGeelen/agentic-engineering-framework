---
id: T-3457
name: "delegation classifier misses install-and-authenticate as act-in-the-world,
  so an interactive operator login can convert to REVIEWER and be auto-ticked by a
  static scan that cannot see it"
description: >
  delegation classifier misses install-and-authenticate as act-in-the-world, so an
  interactive operator login can convert to REVIEWER and be auto-ticked by a static
  scan that cannot see it

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
created: 2026-09-25T07:10:13Z
last_update: '2026-09-25T07:15:37Z'
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
  - ts: '2026-09-25T07:15:14Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=293,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-25T07:15:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3457: delegation classifier misses install-and-authenticate as act-in-the-world, so an interactive operator login can convert to REVIEWER and be auto-ticked by a static scan that cannot see it

## Context

Split out of T-3456's measurement per one-bug-one-task. T-3456 set out to convert the
reviewer-closeable set and found the set unsafe to convert.

### The verb's own output, before

```
AC#1  deterministic  -> REVIEWER  [RUBBER-STAMP] **#H1: Install pi**
AC#2  deterministic  -> REVIEWER  [RUBBER-STAMP] **#H2: pi /login (Anthropic Pro)**
      author declared it mechanical ([RUBBER-STAMP])
```

An interactive `/login` against the operator's Anthropic account converted to
`[REVIEWER]` on the strength of an author prefix. The T-1985 auto-tick rail then ticks a
`[REVIEWER]` criterion when the static scan returns PASS with no findings — and a static
scan cannot observe a login. **A false green on the operator's own credentials.**

### Why it happened

Not precedence. `lib/delegation.py:440-456` checks act-in-the-world (rank 5) before
deterministic (rank 7), exactly as its docstring and CLAUDE.md claim. The gap was the
**vocabulary**: every alternative in `_ACT_IN_THE_WORLD_RE` described an *outbound
irreversible* act — publish, deploy, release, push to origin, pay, delete remote,
customer-facing. That framing is one true axis of the class and silently excluded a
second: acts needing the operator's own machine or their own credentials.

The sharper rule, now written at the vocabulary: **the test is not irreversibility, it is
that the agent cannot perform it and a static scan cannot verify it happened.** An
install and a login are both trivially reversible and both completely undelegable.

### After

```
AC#1  act-in-the-world  stays human  [RUBBER-STAMP] **#H1: Install pi**
AC#2  act-in-the-world  stays human  [RUBBER-STAMP] **#H2: pi /login (Anthropic Pro)**
      the agent cannot perform it and no scan can verify it happened
  converted 0, left human 4
```

### Corpus diff (AC 2, AC 3)

Same scan, pre-fix module read from git vs the live one, **`framework_root` pinned for
both**:

```
pre deterministic: 16   post: 13
LEFT (3):
   - T-1701  [RUBBER-STAMP] #H1: Install pi
   - T-1701  [RUBBER-STAMP] #H2: pi /login (Anthropic Pro)
   - T-1773  [REVIEW]       #H1: End-to-end smoke (after T-1701 #H1+#H2)
ENTERED (0):
```

Exactly the three predicted, nothing else moved, and the other 13 still convert.

**A measurement artefact caught on the way, worth recording.** The first run of that diff
reported `pre 21 / post 13, 8 left` — which would have been a much more alarming and
entirely false result. Loading the pre-fix module from `/tmp` broke its `framework_root`
inference, so render-surface detection silently failed and five render tasks (T-1936,
T-1939, T-2160, T-3028, T-3368) fell through to `deterministic` in the control only. The
control was measuring a different classifier from the treatment. Pinning
`framework_root=ROOT` on both sides is what makes the comparison mean anything.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **The three measured criteria reclassify.** After the fix, T-1701 AC#1
      (`[RUBBER-STAMP] Install pi`), T-1701 AC#2 (`[RUBBER-STAMP] pi /login (Anthropic
      Pro)`) and T-1773 AC#1 are classified `act-in-the-world` → stays human, not
      `deterministic` → REVIEWER. Verified by re-running `fw task delegate <id> --dry-run`
      and quoting the before/after verdict lines.
- [x] **The corpus count moves in the right direction and by the right amount.** The
      whole-corpus scan is re-run: the deterministic set drops from 16 to 13, and the
      three that left are exactly the three named above — not some other three, and not
      more. A fix that quietly reclassified unrelated criteria is a different change.
- [x] **Nothing that legitimately converts stops converting.** The other 13 deterministic
      criteria still classify `deterministic`. This is the leg that catches a vocabulary
      so broad it swallows the convertible set — the failure mode of fixing a
      false-negative by manufacturing false-positives.
- [x] **Tests pin both directions, with the failing leg demonstrated against the pre-fix
      classifier.** Fixture criteria for install / interactive-login / credential-entry
      classify `act-in-the-world`; fixture criteria for genuinely mechanical checks (a
      grep, a file-exists, an HTTP status) still classify `deterministic`. The
      act-in-the-world legs must be shown to FAIL against the pre-fix vocabulary, or they
      guard nothing. `TEST_TEMP_DIR` in setup; no bare `! grep -q`; no live corpus counts
      pinned (T-3326).
- [x] **The rule is stated where the vocabulary lives**, in one sentence a future author
      can apply: what makes something act-in-the-world here is not irreversibility alone
      but that *the agent cannot perform it and a static scan cannot verify it happened*.
      The existing list is all outbound-irreversible; that is the gap this widens.
- [x] Vendored copies synced for every touched file under `lib/`; `bin/fw vendor self
      --check` clean.

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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
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
#
# No live corpus counts pinned (T-3326): "16 -> 13" is true today and will move
# as tasks close. The bats file pins the CLASSIFICATION RULE against fixtures,
# which is the invariant; the corpus numbers live in ## Context as evidence.

timeout 600 bats tests/unit/t3457_act_in_the_world_credentials.bats > /tmp/.t3457-v1.out 2>&1 && grep -q "^ok 1 " /tmp/.t3457-v1.out
timeout 900 bats tests/unit/t3445_delegation_close_path.bats > /tmp/.t3457-v2.out 2>&1 && grep -q "^ok 1 " /tmp/.t3457-v2.out
timeout 600 python3 -m pytest tests/unit/test_delegation_classifier.py -q > /tmp/.t3457-v3.out 2>&1 && grep -q "passed" /tmp/.t3457-v3.out
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

**Symptom:** `fw task delegate T-1701 --dry-run` classified `[RUBBER-STAMP] pi /login
(Anthropic Pro)` as `deterministic → REVIEWER`. Converting it would hand an interactive
login against the operator's Anthropic account to a static scanner, and the T-1985
auto-tick rail ticks a `[REVIEWER]` criterion whenever that scan returns PASS with no
findings. 3 of the 16 convertible criteria corpus-wide were this shape — 19%.

**Root cause:** `_ACT_IN_THE_WORLD_RE` (`lib/delegation.py:173`) enumerated only
*outbound-irreversible* acts. Every alternative — publish, deploy, release, push to
origin, pay, invoice, delete remote, customer-facing — describes something escaping into
the world. Acts requiring the operator's own machine or credentials are equally
undelegable and were absent, so they fell through six carve-outs to `deterministic`,
where the author's `[RUBBER-STAMP]` prefix was sufficient on its own.

**Why structurally allowed:** the class was named for the wrong property. "Act in the
world" reads as *irreversible*, and an install is reversible, so nobody looking at the
list would notice the omission — the list is internally coherent and complete for the
axis it encodes. The real axis is **can the agent do it, and can a scan see that it was
done**, on which install and login score identically to publishing. A vocabulary that
enumerates instances of a class without stating the class's test will always have holes
exactly where the author's examples ran out, and they are invisible by construction
because every entry present looks right.

This is also the false-green family this repo keeps meeting (L-621, T-3451, T-3453): the
failure is silent and the output looks like success. Here it is one turn worse than
usual — the mechanism that would have produced the false tick is the auto-tick rail whose
entire purpose is to close criteria without the operator.

**Prevention:** the vocabulary now carries the class's test in a comment above the
additions, in one sentence a future author can apply rather than pattern-match against.
The reason string was corrected too — it said *"irreversible external action"* for every
member, which was false for the new family and would have told an operator something
untrue about their own criterion. `tests/unit/t3457_act_in_the_world_credentials.bats`
pins both directions: seven legs for the missed family, five that the convertible set
still converts (including the two shapes a careless widening would swallow — `installed`
as a passive noun and `token` in a budget context). Two of those legs run against the
pre-fix module read from git, so the suite fails if the vocabulary is reverted rather
than passing regardless.

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

### 2026-09-25T07:10:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3457-delegation-classifier-misses-install-and.md
- **Context:** Initial task creation
