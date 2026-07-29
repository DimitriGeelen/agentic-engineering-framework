---
id: T-2685
name: "fix corpus explain rail arity drift silently downgrading authority stage (OBS-102)"
description: >
  fix corpus explain rail arity drift silently downgrading authority stage (OBS-102)

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-07-29T21:13:46Z
last_update: 2026-07-29T21:19:24Z
date_finished: 2026-07-29T21:19:24Z
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
  - ts: '2026-07-29T21:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-29T21:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2685: fix corpus explain rail arity drift silently downgrading authority stage (OBS-102)

## Context

OBS-102, found while running the corpus suites for T-2684.

`tools/corpus_explain.py:74` calls `conformance.canonical_transitions(root)` with one
argument. T-2654's registry refactor changed the signature to `(root, source)`. The call
sits inside a broad `except Exception` whose handler returns
`("transitional-subordinate", f"rail unreadable: {e}")` — so the `TypeError` never
surfaces as an error. It renders as a sentence, and the authority stage silently falls
back to a value that is perfectly legitimate for other maps.

Live effect: `fw corpus explain aef-task-lifecycle` prints
`authority stage: transitional-subordinate` and `precedence: descriptive only — CLAUDE.md
prose wins on conflict until the conformance rail goes green`, while that map's rail
**actually passes** (`corpus_conformance.py --all` → PASS on the 6 enforced transitions).
The flagship map has been denied the detail-authority it earned, on every invocation,
since T-2654. Three tests in `tests/unit/test_corpus_explain.py` have been red the whole
time.

This is a G-071 instance in the framework's own tooling: a deterministic component whose
frozen world-assumption (a function's arity) drifted, and which then produced a
plausible-and-wrong answer instead of failing. The catch-all handler is what converted a
loud crash into a quiet lie.

## Acceptance Criteria

### Agent
- [x] `authority_stage` passes the registry `source` through, read from the same registry
      the checker reads — and the hardcoded `map_id != "aef-task-lifecycle"` literal is gone
      too. Both literals were the same staleness class; fixing only the arity would have
      left explain claiming "no conformance rail exists" for the 4 maps that have since
      gained one
- [x] `fw corpus explain aef-task-lifecycle` reports `authority stage: detail-authority`
      with a GREEN rail line, and the precedence line now reads "this map holds the process
      detail … on detail conflict the map wins" — matching what
      `corpus_conformance.py --map aef-task-lifecycle` independently reports (PASS, 6
      enforced transitions)
- [x] The catch-all no longer masks programming errors: narrowed to
      `conformance.LoadError`, which is what every genuine unreadable-rail condition
      already raises (`load_registry`, `load_latest_spec`, `canonical_transitions` all
      raise it). A TypeError/AttributeError in the rail path now propagates
- [x] All previously-red tests in `tests/unit/test_corpus_explain.py` pass with no
      assertion weakened. The fixture gained a conformance registry — that is the fixture
      catching up to reality (the registry has been the rail opt-in surface since T-2654),
      not an accommodation: a fixture with a rail but no registry modelled a world that
      cannot exist. 13/13, up from 5/9
- [x] Regression test pins the property that actually protects us — a non-LoadError raised
      in the rail path must reach the caller instead of becoming a verdict
      (`test_programming_errors_in_the_rail_path_are_not_swallowed`), plus a live-repo test
      asserting explain's verdict agrees with the checker's own on the real corpus. A bare
      signature-shape assertion was rejected: it would only restate today's arity, and the
      defect was the swallowing, not the arity
- [x] Maps with no registry entry still report `transitional-subordinate` /
      "no conformance rail exists"; maps with a non-transition-table rail now say
      "rail present (vocabulary-set) …" instead of falsely claiming no rail exists
- [x] Full corpus suite green: 103 passed across explain, lint, lane-geometry,
      conformance, conformance-registry, spec round-trip, doc guard, overlay, prove-guard

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
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# The whole corpus suite, including the two new regression pins.
python3 -m pytest tests/unit/test_corpus_explain.py tests/unit/test_corpus_lint.py tests/unit/test_corpus_lint_lane_geometry.py tests/unit/test_corpus_conformance.py tests/unit/test_corpus_conformance_registry.py tests/unit/test_corpus_spec_roundtrip.py tests/unit/test_corpus_spec_doc_guard.py -q
# The user-visible symptom is gone: the rail-anchor map holds the authority it earned.
out=$(bin/fw corpus explain aef-task-lifecycle 2>&1); echo "$out" | grep -q "authority stage: detail-authority"
# ...and explain no longer renders our own bugs as a verdict.
out=$(bin/fw corpus explain aef-task-lifecycle 2>&1); ! echo "$out" | grep -q "rail unreadable"
# explain's verdict agrees with the independent checker.
out=$(python3 tools/corpus_conformance.py --map aef-task-lifecycle 2>&1); echo "$out" | grep -q "PASS"
# A railed-but-not-staged map states that, rather than claiming no rail exists.
out=$(bin/fw corpus explain aef-audit-cron 2>&1); echo "$out" | grep -q "rail present (vocabulary-set)"
# No rail regressed.
out=$(python3 tools/corpus_conformance.py --all 2>&1); ! echo "$out" | grep -q "FAIL"

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

**Symptom:** `fw corpus explain aef-task-lifecycle` reported `authority stage:
transitional-subordinate` with `rail: rail unreadable: canonical_transitions() missing 1
required positional argument: 'source'`, and a precedence line stating CLAUDE.md prose wins
until the rail goes green — while that map's rail was in fact green
(`corpus_conformance.py --map aef-task-lifecycle` → PASS, 6 enforced transitions).

**Root cause:** T-2654's registry refactor changed `canonical_transitions(root)` to
`canonical_transitions(root, source)`. `corpus_explain.authority_stage` was not updated, so
every call raised `TypeError` — inside a bare `except Exception` that returned
`("transitional-subordinate", f"rail unreadable: {e}")`. The same function also hardcoded
`map_id != "aef-task-lifecycle"`, so the 4 maps that gained rails after T-2654 were reported
as having none.

**Why structurally allowed:** three things had to line up, and they did.
(1) The broad catch turned a crash into a return value. (2) The fallback value was
*legitimate* — `transitional-subordinate` is the correct answer for most maps, so the wrong
answer was indistinguishable from a right one by inspection. (3) The only surface that would
have shouted — 3 red tests in `test_corpus_explain.py` — was red without anyone acting,
because nothing runs the corpus suites at task close unless a task's own Verification block
names them, and T-2654's did not. So the signal existed and went unread for the entire
window. This is G-071 in the framework's own tooling: a deterministic component carrying a
frozen world-assumption (a function's arity), producing plausible-and-wrong output rather
than an error.

**Prevention:** three legs, none of which is "remember to update call sites".
(1) The catch is narrowed to `LoadError`, so the *class* of defect — our own bug rendered as
a verdict — cannot recur in this function regardless of what drifts next; a regression test
pins that property directly rather than pinning today's signature.
(2) The literals are gone: `authority_stage` reads the registry, so it tracks rail
membership instead of restating it.
(3) A live-repo test asserts explain's verdict agrees with the checker's independent verdict
on the real corpus — a cross-check between two components that had silently disagreed, which
is the shape that catches the next divergence even if it arrives by a different route.
The remaining hole is the one that let the red tests sit unread; that is
[[T-2680]]/[[T-2681]] territory (G-071 stays open) and is not claimed as fixed here.

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

### 2026-07-29T21:13:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2685-fix-corpus-explain-rail-arity-drift-sile.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5bbfbe87
- **Timestamp:** 2026-07-29T21:19:31Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 37
     - evidence: `out=$(bin/fw corpus explain aef-task-lifecycle 2>&1); ! echo "$out" | grep -q "rail unreadable"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 43
     - evidence: `out=$(python3 tools/corpus_conformance.py --all 2>&1); ! echo "$out" | grep -q "FAIL"`

### 2026-07-29T21:19:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
