---
id: T-3121
name: "fw fabric enrich is blind to dotted imports - consumer package layouts get
  an empty graph plus a mitigation that cannot clear its own WARN"
description: >
  agents/fabric/lib/enrich.py:460 matches only 'from <word> import'. \w excludes '.',
  so package-style 'from pkg.mod import X' fails outright. Reported by 001-CashWeb
  (T-091), confirmed here: 114 dotted from-imports across lib/ web/ agents/ are invisible.
  The audit WARN 'N cards have no edges' advertises 'Run: fw fabric enrich' as its
  fix, which cannot clear it.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
arc_id: arc-004
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
created: 2026-08-23T19:24:53Z
last_update: 2026-08-23T19:41:19Z
date_finished: 2026-08-23T19:41:19Z
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
  - ts: '2026-08-23T19:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=224,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-23T19:30:19Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3121: fw fabric enrich is blind to dotted imports - consumer package layouts get an empty graph plus a mitigation that cannot clear its own WARN

## Context

`detect_generic_python_imports` (`agents/fabric/lib/enrich.py`) matches
`from\s+(\w+)\s+import`. `\w` excludes `.`, and the pattern is not anchored to a
partial match — a dotted path fails outright rather than degrading to its first
segment. `import pkg.mod` is not looked at at all.

Reported by 001-CashWeb (their T-091) with file, line, regex and measurement.

**A first reading of this task said our 114 dotted `from a.b import` statements
were "invisible". That was wrong, and being wrong is the useful part.** They are
seen — by a *different* detector. `detect_python_imports:271` matches
`from ((?:web|lib|agents|tools)(?:\.\w+)+) import`: dotted paths, but only under
four hardcoded prefixes, which are precisely this framework's own top-level
package names. So the framework is exempt from its own bug by a coincidence
someone hardcoded, and every consumer whose packages are not named `web`, `lib`,
`agents` or `tools` is not.

That is the arc-004 conflation class stated exactly: the generic detector was
never the one carrying us, so its brokenness could not show up in our numbers.
The peer's report is the first instance from outside our tree, and the only
reason it surfaced at all.

The second half of the defect is resolution, not matching. The generic detector
resolved a module only against the source file's own directory and its parent —
never the project root. `web/blueprints/tasks.py` doing `from web.shared import x`
means `<root>/web/shared.py`, which no strategy could reach from
`web/blueprints/`. Measured: the generic detector returned **zero** edges for our
files. The hardcoded prefix list is that missing root-relative strategy, written
out longhand for one project.

Why this is worth a task rather than a one-line patch: the audit emits
`WARN Fabric: N cards have no edges` whose mitigation is `Run: fw fabric enrich`.
For a consumer, that advice cannot clear the WARN it is attached to, and it fails
silently — enrich reports success having found nothing. Advice that cannot work
trains operators to ignore audits.

## Acceptance Criteria

### Agent
- [x] `detect_generic_python_imports` resolves dotted `from pkg.mod import X` to `pkg/mod.py` and to `pkg/mod/__init__.py`, keeping the existing three flat strategies working unchanged
- [x] Plain `import pkg.mod` and `import mod` are detected, which the current pattern never looked at
- [x] The skip-list is consulted on the ROOT segment, so `from yaml.parser import X` is still skipped as third-party rather than resolved as a project path
- [x] A regression test builds its own fixture tree (per L-599 — it must not assert against the live corpus, which changes under it) and covers: dotted→file, dotted→package `__init__`, plain `import a.b`, root-segment skip, and no self-edge
- [x] A dotted module resolves project-root-relative as well as source-relative, so a nested file's `from pkg.mod import X` is reachable — the generalisation of the hardcoded `web|lib|agents|tools` prefix list
- [x] Run over this repo, `fw fabric enrich` adds strictly more edges than the pre-fix baseline, measured by running the same command against both versions and reporting the number rather than asserting a constant: **468 → 827 forward edges, 269 → 469 cards enriched**. Split honestly: the dotted/`import X` fix accounts for +16, root-relative resolution for +343
- [x] No invented edges: every emitted edge resolves to a file that exists on disk

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

python3 -c "import ast; ast.parse(open('agents/fabric/lib/enrich.py').read())"
python3 -m pytest tests/unit/test_fabric_dotted_imports.py -q 2>&1 | tail -3 | grep -qE '[0-9]+ passed'

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

**Symptom:** a consumer project (001-CashWeb) carried `WARN Fabric: 15/18 cards
have no edges` on every audit. Its advertised mitigation, `Run: fw fabric enrich`,
processed 20 cards and added one edge — and that one came from a filename
convention, not from import analysis. Their real graph had 23 edges; the detector
saw none of them.

**Root cause:** two independent defects in `detect_generic_python_imports`, either
of which alone yields an empty graph for a package-laid-out project.
1. *Matching* — `from\s+(\w+)\s+import`. `\w` excludes `.`, and the pattern is not
   a partial match, so a dotted path fails outright rather than degrading to its
   first segment. `import pkg.mod` was never looked at in any form.
2. *Resolution* — candidates were built only from the source file's directory and
   its parent, never the project root. Even with matching fixed, a nested file
   importing a root-level package resolves to nothing.

**Why structurally allowed:** the framework could not observe its own defect,
because it does not depend on the defective code path. `detect_python_imports`
carries a separate pattern hardcoding `web|lib|agents|tools` — this project's own
four top-level package names — so our dotted imports resolved through a detector
the consumer prototype never touches. Our numbers were healthy for a reason that
does not generalise past this one repo's directory names. That is the exact shape
arc-004 exists to kill, and it is worse than a blind spot: the framework's own
green readings were *evidence against* the bug existing.

The compounding factor is that the failure is silent and shaped like success.
Enrich exits 0 and prints a summary having found nothing, so the only signal is a
WARN whose own mitigation is the broken command. Nothing in that loop ever
escalates.

**Prevention** (distinct from the fix):
- `tests/unit/test_fabric_dotted_imports.py` builds a fixture tree with
  *consumer-shaped* package names — deliberately not `web`/`lib`/`agents`/`tools`,
  so the hardcoded prefix list cannot mask a regression. Per L-599 it asserts
  against its own fixture, never the live corpus.
- The root-segment skip case (`from yaml.parser import X` must stay third-party)
  is pinned as its own test. Widening the pattern silently breaks `SKIP_MODULES`,
  and that regression is invisible in an otherwise-green run.
- Open follow-on, deliberately not fixed here: an audit WARN whose mitigation
  command cannot clear it is a false-advice class with no detector. This instance
  ran for as long as the prototype has existed and was caught only because a
  consumer read its own graph and disbelieved it.

## Evolution

### 2026-08-23 — the framework was exempt, and that was the finding

- **What changed:** the task was filed asserting that 114 dotted imports in this
  repo were invisible to the enricher. That was wrong. Measuring the fix's effect
  produced an identical edge count before and after, which only made sense if
  something else was already resolving those imports. It was:
  `detect_python_imports:271` matches dotted paths under a hardcoded
  `web|lib|agents|tools` prefix list — this repo's own package names. Our imports
  were never invisible; they were carried by a detector consumers cannot benefit
  from.
- **Plan impact:** the acceptance criterion "enrich adds strictly more edges than
  baseline on this repo" was near-unsatisfiable as written. The dotted-path fix
  alone moved this repo by +16 edges, because this repo was never the victim. The
  real defect was resolution, not matching: candidates were built only from the
  source file's directory and its parent, never the project root, so the generic
  detector returned **zero** edges for every nested file. Added that as strategy 4
  — the generalisation of the hardcoded prefix list — which moved the repo +343.
- **Triggered:** one AC added (root-relative resolution) and one rewritten to
  report the measured split rather than assert a constant. Two tests added beyond
  the dispatched worker's scope: nested-source root-relative resolution, and a
  precedence test that local resolution still wins so the fallback cannot silently
  re-point existing edges. Fixture names deliberately avoid `web`/`lib`/`agents`/
  `tools`, since with them the suite passes against the broken code.
- **Worth keeping:** the initial framing was the sort of error that ships quietly.
  Both the peer's report and my own confirmation pointed the same way, the fix was
  real, and the tests were green — only the *measurement* disagreed. It is the
  cheapest of the three to skip.

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

### 2026-08-23T19:24:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3121-fw-fabric-enrich-is-blind-to-dotted-impo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d1745cb4
- **Timestamp:** 2026-08-23T19:41:22Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `detect_generic_python_imports` resolves dotted `from pkg.mod import X` to `pkg/mod.py` and to `pkg/mod/__init__.py`, keeping the existing three flat strategies working unchanged
  - **AC-verify-mismatch** (narrow, heuristic) — `path=pkg/mod.py in: `detect_generic_python_imports` resolves dotted `from pkg.mod import X` to `pkg/mod.py` and to `pkg/mod/__init__.py`, keeping the existing three flat `

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `python3 -m pytest tests/unit/test_fabric_dotted_imports.py -q 2>&1 | tail -3 | grep -qE '[0-9]+ passed'`

### 2026-08-23T19:41:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
