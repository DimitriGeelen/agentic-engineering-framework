---
id: T-3231
name: "the --help exemption skips every gate — narrow it to real help invocations"
description: >
  the --help exemption skips every gate — narrow it to real help invocations

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:continuous-run]
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
created: 2026-08-31T12:57:28Z
last_update: 2026-08-31T13:06:01Z
date_finished: 2026-08-31T13:06:01Z
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
  - ts: '2026-08-31T13:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=285,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-31T13:00:22Z'
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

# T-3231: the --help exemption skips every gate — narrow it to real help invocations

## Context

Finding C2 of the arc-012 review (`docs/reports/arc-012-review/SYNTHESIS.md:51`,
worker W2-F1). `agents/context/check-active-task.sh:179-180` is an unconditional
`exit 0` — ahead of every gate, the first of which is at line 220 — taken whenever
`--help` or `--version` matches **anywhere** in the Bash command, including inside a
quoted argument. Any command opts out of governance by appending seven characters.

Measured before/after against the real hook, with no active task in the fixture
(with one, the gate allows everything and exempt is indistinguishable from gated —
this is the false green that made an earlier attempt at C2 read as verified):

| command | before | after |
|---|---|---|
| `fw upstream --help` | ALLOW | ALLOW |
| `cd /tmp && fw upstream --help` | ALLOW | ALLOW |
| `rm -rf /important/data --help` | ALLOW | **GATED** |
| `rm -rf /important/data` | GATED | GATED (control) |
| `echo "the --help flag" > /etc/passwd` | ALLOW | **GATED** |
| `echo "x" > /etc/passwd` | GATED | GATED (control) |
| `git commit -m "document the --help flag"` | ALLOW | ALLOW |

**The review's third row was overstated and is corrected here.** `git commit` took
the exemption, but the task gate does not block it either way — it is neither a
write pattern nor safe-listed, and for Bash the gate only blocks detected writes.
That row demonstrated the regex flaw without being a governance loss. The
consequential quoted-payload case is `echo "… --help …" > /etc/passwd`, which does
flip, and the sharper one is the focus-drift case below.

Separately measured, with an active task in focus (leg 1 in isolation, no write
pattern anywhere — the gate that should fire is focus-drift):

| command (focus = T-3231) | before | after |
|---|---|---|
| `bin/fw task update T-3229 --add-tag ui` | GATED | GATED (control) |
| `bin/fw task update T-3229 --add-tag "see --help first"` | **ALLOW** | **GATED** |

This is the more serious instance: focus-drift is the most-bypassed gate in the
log (852 of 1072 Tier-2 entries), and a quoted `--help` skipped it silently.

T-2410's intent was legitimate — `fw upstream --help` blocked at the focus gate
purely because `upstream` is not safe-listed — and the fix must preserve it,
including the chained `cd … && fw upstream --help` form its comment names.

The corrective discipline already exists **33 lines below** in the same file: the
T-2936 bootstrap branch (:212-217) decides on a quote-stripped view precisely so a
quoted payload cannot be read as a command. It was never applied here. Same shape as
T-3228 (C1), where the right pattern also sat one function away.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The exemption is decided on a quote-stripped view, so `--help` inside a quoted argument no longer exempts
- [x] The exemption is refused when the quote-stripped command carries a write pattern, so `rm -rf … --help` no longer exempts
- [x] `fw upstream --help` is still exempt (T-2410's origin case does not regress)
- [x] `cd /tmp && fw upstream --help` is still exempt (T-2410's chained case does not regress)
- [x] `rm -rf /important/data` remains gated — the control that proves the suite is not vacuously passing
- [x] A bats suite drives the REAL hook (not a reimplementation of its predicate) across both fixtures, with controls proving the harness can both gate and allow
- [x] The suite is mutation-tested: each of the two legs, the fail-closed ordering, and a full revert to the original C2 code each redden a named test
- [x] `bash -n agents/context/check-active-task.sh` parses, and the vendored mirror copy is in sync

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

# 10 tests, 5 of them controls; 0 skips asserted separately because a skipped
# bats test reports `ok` (T-3217) and this suite's whole value is that it ran.
timeout 300 bats tests/unit/t3231_help_exemption_scope.bats > /tmp/.t3231 2>&1 && ! grep -q "^not ok" /tmp/.t3231
test "$(grep -c '# skip' /tmp/.t3231)" -eq 0
# both legs present in the source: the quote-stripped view, and the write refusal
grep -q '_help_unquoted' agents/context/check-active-task.sh
grep -q 'type has_bash_write_pattern' agents/context/check-active-task.sh
# the vendored mirror carries the fix — a governance hook fixed only in the source
# tree leaves every consumer on the vulnerable copy
diff -q agents/context/check-active-task.sh .agentic-framework/agents/context/check-active-task.sh

## RCA

**Symptom:** any Bash command could skip every gate in `check-active-task.sh` by
containing `--help` or `--version` anywhere, including inside a quoted argument.
`rm -rf /important/data --help` was exempt; so was
`bin/fw task update T-3229 --add-tag "see --help first"` while focused elsewhere.

**Root cause:** `agents/context/check-active-task.sh:179-180` was an unconditional
`exit 0`, positioned ahead of every gate, guarded only by a position-independent
regex over the raw command string. The predicate answered *"does this text contain
a help flag"* while the code around it assumed *"is this a help invocation"*.

**Why structurally allowed:** T-2410 added the exemption to fix a real complaint —
`fw upstream --help` blocked at the focus gate because `upstream` is not
safe-listed. The fix was correct in intent and evaluated only against its own
motivating case, where a broad regex and a narrow one are indistinguishable. No
test asked what the exemption *also* admitted. This is the same asymmetry the arc
keeps producing: an exemption is only ever exercised by the cases it was written
for, so its over-breadth is invisible until someone probes the complement.

**Prevention:** `tests/unit/t3231_help_exemption_scope.bats` drives the real hook
(not a reimplementation of its predicate) across 10 cases, 5 of them controls, and
is mutation-tested against four independent reversions — including a full revert to
the original C2 code, which reddens 4 tests. Each leg has a test that reddens
uniquely for it. The suite additionally pins that the exemption **fails closed**
when `has_bash_write_pattern` is unavailable, which is the way a naive rewrite
(`! { type … && … ; }`) would silently reopen the hole.

**Two near-misses worth recording, both instances of this task's own subject.**

1. *The first verification was a false green.* Driving the hook from the live repo
   returned rc=0 for all five rows — including the control that must gate — because
   T-3231 was focused, so the active-task check passed and the exemption never
   mattered. Exempt and gated are indistinguishable whenever a task is active. The
   fixture has no active task, which is the only state where the thing under test
   is observable. An earlier attempt at C2 recorded exactly this shape.

2. *Mutation M1 reddened nothing on the first pass.* Reverting the quote-strip
   changed no test result, because the only quoted-payload case was
   `echo "… --help …" > /etc/passwd`, whose redirect survives stripping and is
   therefore caught by leg 2 regardless. The suite could not tell the two legs
   apart. Per the landing-mode rule, a mutation that reddens nothing is a finding:
   here it was an inert *test*, not an inert mutation. Resolving it produced the
   focus-drift case above — which turned out to be the more serious instance of the
   defect, and would not have been found by any amount of re-reading the diff.

3. *The suite shipped with a dead negation, and the pre-push audit caught it.* The
   `--version` test was written as `! hook_allows '…'` followed by a second
   statement. A `!` in non-final position never trips errexit, so it asserts
   nothing (L-628) — in the suite written to prove assertions are not inert. The
   T-3138/AC3 invariant flagged it at the push gate: 1 dead negation across 706
   scanned files. Split into two tests with `run` + explicit status checks.

   **The mutation delta is the proof it was inert, not merely suspect:** M2 went
   from 2 reddened tests to 3, and M4 from 4 to 5, and the newly-reddening test in
   both is the `--version` destructive case. Before the split, that test passed
   under mutations that broke exactly what it claimed to cover. Worth stating
   plainly — the audit said "dead negation", which is a claim about *shape*; the
   mutation count is the claim about *behaviour*, and only the second one settles
   it.

## Evolution

### 2026-08-31 — leg independence is not a property you can assert

- **What changed:** the fix was designed as "two independent legs, neither
  subsuming the other", and that claim was written into the source comment before
  it was tested. Mutation M1 falsified it for the cases then in the suite: leg 2
  masks leg 1 wherever the quoted payload also contains a redirect. The legs *are*
  independent, but proving it required constructing a command with no write pattern
  at all — which meant a second fixture and a different gate.
- **Plan impact:** the suite grew a second fixture (active task + cross-task
  attribution) that the original plan did not anticipate. The source comment's
  "neither leg subsumes the other" now has a test behind it rather than an
  assertion.
- **Triggered:** no new task. The correction landed in the same commit, which is
  what the filing budget asks for when the finding is this local.

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

### 2026-08-31T12:57:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3231-the---help-exemption-skips-every-gate--n.md
- **Context:** Initial task creation

### 2026-08-31T13:05:55Z — status-update [task-update-agent]
- **Change:** tags: +arc:continuous-run

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6ed90243
- **Timestamp:** 2026-08-31T13:06:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-31T13:06:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
