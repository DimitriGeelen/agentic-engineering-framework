---
id: T-2684
name: "corpus lint: lane membership vs node geometry disagreement detector"
description: >
  corpus lint: lane membership vs node geometry disagreement detector

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-07-29T21:00:40Z
last_update: '2026-08-16T22:25:14Z'
date_finished: 2026-07-29T21:10:30Z
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
  - ts: '2026-08-16T22:25:14Z'
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

# T-2684: corpus lint: lane membership vs node geometry disagreement detector

## Context

Our half of 832's T-310, reported at rail 333 and answered at rail 334.

A BPMN map carries lane membership twice over: structurally, as `flowNodeRef` inside the
`laneSet`, and visually, as each node's `aef:position` y-value falling inside a lane band.
The designer draws bands in laneSet **document order** and places nodes at their stored
position, so when the two disagree it does not reconcile them — it renders the geometry and
reports the membership. Two consequences, both silent:

1. **Read side (worse, and ours to surface).** `fw corpus explain` and every conformance
   rail read `flowNodeRef`. The operator reads the render. On a disagreeing map those are
   different answers to "who owns this step" — and lane membership is the *authority* axis
   in this dialect, not decoration.
2. **Write side (832's T-310).** `laneAtY(centerY)` rewrites `n.lane` on drag, so touching
   a disagreeing map silently rewrites membership from pixels.

Survey of the live store (11 maps, latest version each) found **4 disagreeing**:
`draft-exception-handling` v3 (12 of 13 nodes — wholesale agent↔framework inversion),
`draft-task-creation` v3 (14 nodes, same inversion), `aef-session-lifecycle` v1
(**promoted** — 3 agent-declared nodes inside the human band), `draft-knowledge-leveling`
v8 (exactly 2: `kl_dormant`, `kl_healing` — independently confirming 832's prediction that
these are the two nodes never dragged).

Authoring root cause, ours: the seeds treat framework verbs as the visual spine and put
them on the **top** row while the laneSet declares `agent` first. Systematic across my
authoring, not incidental to one map.

**This task is the detector only** — it makes the disagreement visible and unshippable.
Reconciling the four maps is deliberately separate: two are zero-semantic laneSet reorders,
but the other two need an authority call that belongs to the operator, not to me.

## Acceptance Criteria

### Agent
- [x] Band model validated before being relied on, and the outcome acted on: cross-checked
      against a y-origin-free span-ordering check across all store maps. **Result: band model
      REJECTED** — it needs a band origin the map does not carry, and disagrees with the
      origin-free check on `draft-trigger-handling` (7 phantom mismatches against cleanly
      ordered spans). The rule ships on the origin-free invariant only; band arithmetic is
      not used for detection
- [x] Detection invariant is origin-free and height-free: for lanes in laneSet declaration
      order, the y-ranges of their member nodes must be strictly ordered and non-overlapping
- [x] New `corpus_lint` rule `lane-geometry` flags a map whose declared lane membership
      contradicts its node geometry, with the rule's origin (T-2684 / 832 T-310) documented
      in the module docstring alongside the existing rules
- [x] Finding detail is actionable without over-claiming: one finding per violating lane
      pair (not per node — a wholesale inversion must not flood the report), naming both
      spans and the **extremal witness pair** (the upper lane's lowest-drawn node and the
      lower lane's highest-drawn node). That pair is the minimal provable witness of the
      crossing and needs no band origin; on `draft-knowledge-leveling` v8 it resolves to
      exactly `kl_healing` + `kl_dormant`, independently matching 832's account
- [x] Degrades honestly rather than guessing: maps with <2 populated lanes, or any node
      without a position, are skipped rather than reported clean (lane heights are not read
      at all, per the rejected band model)
- [x] Unit tests cover clean, wholesale-inversion, subset-crossing, equal-y, three-lane,
      wide-gap and every skip case, plus lint-driver integration and the docstring catalogue
      (16 tests, `tests/unit/test_corpus_lint_lane_geometry.py`)
- [x] Live-store detection matches the survey exactly, with the draft split made explicit:
      the default scan skips `draft-*` (T-2623 draft tier) so it reports the 1 non-draft
      disagreement (`aef-session-lifecycle`) and nothing else across the other 6; naming the
      4 drafts explicitly reports the 3 known disagreements and leaves `draft-trigger-handling`
      clean — the map the rejected band model would have false-flagged
- [x] `fw corpus lint` exit contract unchanged (0 clean / 1 findings / 2 usage); both
      pre-existing findings still surface (legacy-ref, emitterless-typed-event) with no rule
      shadowing. Live baseline deliberately moves 2 → 3 and the pin in
      `test_corpus_lint.py::test_live_corpus_current_findings` is updated with the reason
      and the condition under which the new entry should disappear rather than be re-pinned

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

# Rule tests + the existing lint suite (incl. the deliberately-moved live baseline pin).
python3 -m pytest tests/unit/test_corpus_lint_lane_geometry.py tests/unit/test_corpus_lint.py -q
# Corpus reader/writer suites unaffected by the new rule.
python3 -m pytest tests/unit/test_corpus_spec_roundtrip.py tests/unit/test_corpus_spec_doc_guard.py -q
# The rule fires on the promoted disagreement in the default (non-draft) scan.
out=$(bin/fw corpus lint 2>&1); echo "$out" | grep -q "lane-geometry.*aef-session-lifecycle"
# ...and stays silent on draft-trigger-handling, which the rejected band model false-flagged.
out=$(bin/fw corpus lint draft-trigger-handling 2>&1); echo "$out" | grep -q "^CLEAN"
# Both pre-existing rules still surface (no shadowing).
out=$(bin/fw corpus lint 2>&1); echo "$out" | grep -q "legacy-ref" && echo "$out" | grep -q "emitterless-typed-event"
# Conformance rails unaffected.
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

### 2026-07-29 — reject the band model; detect on an origin-free invariant

- **Chose:** detect disagreement purely from the ordering of per-lane node y-ranges against
  laneSet declaration order. No band arithmetic.
- **Why:** the band model looked strictly better — it names the exact offending nodes — so I
  cross-checked it before building on it (AC-1). It reconstructs bands by anchoring cumulative
  lane heights at the topmost node, and that anchor is a **guess**: the map stores no band
  origin, and lane heights tile the canvas rather than the node placement. On
  `draft-trigger-handling` the two models disagreed — 7 band mismatches against cleanly
  ordered spans. Since that map is clean under the sound invariant, those 7 were phantoms, and
  shipping band arithmetic would have meant a false-positive rule on a live map.
- **Rejected:** (a) band arithmetic as primary — false positives, as measured; (b) band
  arithmetic as a secondary "detail" pass — a rule that reports precise-but-wrong node ids is
  worse than one that reports a coarser truth, and this whole defect class exists *because*
  plausible-and-wrong beats empty at getting past checks; (c) asking 832 for the band origin
  and then using it — that couples our lint to an internal of their renderer, which is the
  dependency direction the T-559 boundary exists to avoid.

### 2026-07-29 — report the extremal witness pair rather than "all crossing nodes"

- **Chose:** name the upper lane's lowest-drawn node and the lower lane's highest-drawn node,
  plus per-side crossing counts.
- **Why:** that pair is provably involved in the crossing under the invariant, with no origin
  needed — it is the minimal witness. It also happens to be sharp where sharpness matters: on
  `draft-knowledge-leveling` v8 it resolves to exactly `kl_healing` + `kl_dormant`, which
  independently reproduces 832's account of the two nodes their operator never dragged. The
  counts then separate the two repair shapes: 100%-both-sides means reorder the laneSet
  (zero-semantic), a subset means an authority decision on the named nodes.
- **Rejected:** listing every node on the wrong side of the crossing — on the interleaved v8
  case that set is large and mostly innocent, which would bury the two nodes that matter;
  and one finding per node, which floods the report on the two wholesale-inverted drafts.

### 2026-07-29 — detector now, reconciliation separately

- **Chose:** ship the detector alone; do not repair the 4 disagreeing maps in this task.
- **Why:** two of them (`draft-exception-handling`, `draft-task-creation`) are wholesale
  inversions fixable by a zero-semantic laneSet reorder, but the other two are not: v8's
  two-node case and `aef-session-lifecycle`'s three-node overflow both ask "which lane owns
  this step", which is the authority axis and therefore the operator's call, not mine. Mixing
  a mechanical fix and a sovereignty question into one task would force the mechanical half to
  wait on a decision it does not need — and would tempt me to answer the authority question
  myself because the code change is trivial.
- **Rejected:** repairing everything now (crosses the authority boundary); repairing only the
  two mechanical ones inside this task (leaves the lint reporting findings the task claims to
  have fixed, and splits one deliverable across two rationales).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-29T21:00:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2684-corpus-lint-lane-membership-vs-node-geom.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-53fbd53b
- **Timestamp:** 2026-07-29T21:10:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_corpus_lint_lane_geometry.py tests/unit/test_corpus_lint.py -q`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 43
     - evidence: `out=$(python3 tools/corpus_conformance.py --all 2>&1); ! echo "$out" | grep -q "FAIL"`

### 2026-07-29T21:10:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
