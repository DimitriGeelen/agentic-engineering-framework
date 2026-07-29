---
id: T-2686
name: "reorder laneSet on two wholesale-inverted drafts (832 T-310 race)"
description: >
  reorder laneSet on two wholesale-inverted drafts (832 T-310 race)

status: started-work
workflow_type: refactor
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
created: 2026-07-29T21:44:11Z
last_update: 2026-07-29T21:52:30Z
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
  - ts: '2026-07-29T21:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-29T21:45:09Z'
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

# T-2686: reorder laneSet on two wholesale-inverted drafts (832 T-310 race)

## Context

Repair leg of the T-2684 survey, and a race against 832's shipped fix.

Two drafts declare `agent` as the first lane while drawing the framework-owned nodes on
the top row — so `flowNodeRef` (what `fw corpus explain` and every conformance rail read)
and the rendered bands (what the operator reads) disagree about who owns nearly every
node. Lane membership is the "who" axis in this dialect, so that is an authority misread,
not a cosmetic one. Both maps are in the operator's taste queue right now.

**Why now, not later (the race).** 832 answered the rail-334 question at rail 335: band
top-to-bottom order is derived **purely from laneSet document order** — no stored index,
no first-appearance-of-flowNodeRef, no canonical lane sort (their src 9469-9481 parse,
2089-2096 `laneTop`, 9322-9334 export re-emit, so a reorder round-trips). That makes a
laneSet reorder a real, membership-untouched repair. But they have **already shipped
T-310**: their importer now reconciles in favour of the declared lane and sets y to lane
centre. If these two maps reach a designer pin before we reorder, 12 and 15 nodes collapse
to one row per lane and the drawn layout is destroyed. Reordering first means their
importer reconciles zero and the drawing survives.

**Their caveat, and why it does not bite here.** Band boundaries are cumulative
`aef:laneMeta height`, so swapping unequal-height lanes moves the boundary between them —
these are 220/300 and 200/320/140, i.e. unequal. The reorder is therefore not
*automatically* exact and must be re-verified against the geometry oracle afterwards. It
also means the reorder only fits a **swap**: `aef-session-lifecycle` v1 (3 agent-declared
nodes overflowing the human band) is a partial overlap that no lane permutation fixes, and
`draft-knowledge-leveling` v8 (2 nodes) is an authority call for the operator. Both stay
out of scope here.

**Origin-free feasibility (found while scoping, stronger than the shipped ordering rule).**
Asking whether *any* band origin O places every node inside its own declared band is pure
interval algebra over the stored heights — it assumes nothing about O's value, so it is as
origin-free as the T-2684 ordering invariant but strictly stronger. Measured before
touching anything:

| map | O-interval as declared | O-interval reordered |
|-----|------------------------|----------------------|
| draft-exception-handling v3 | `[160, -80]` **EMPTY** | `[-140, 80]` feasible |
| draft-task-creation v3 | `[120, -160]` **EMPTY** | `[-20, 0]` feasible |

An empty interval is a proof that the pre-state is broken for *every* origin, not a
heuristic — which is the evidence the T-2684 band model could not produce. Whether this
becomes a lint upgrade is a separate question (filed separately, not scope-crept here).

Geometric order is `framework`-first in both, so each repair is a swap of the first two
declared lanes; `human` stays third in `draft-task-creation`.

## Acceptance Criteria

### Agent
- [x] Both drafts declare lanes in drawn order (`framework` first); `flowNodeRef`
      membership sets and every `aef:position` are byte-identical to the pre-state
- [x] `lane-geometry` findings on both drafts drop to **zero** (`fw corpus lint
      draft-exception-handling draft-task-creation` → CLEAN)
      <!-- Measured pre-state, correcting the figures I quoted to 832 on rail 334:
           draft-exception-handling was 5/5 agent + 7/7 framework = 12 of 12 nodes, i.e.
           fully wholesale, not "12 of 13"; draft-task-creation was 3/3 agent + 12/12
           framework = 15 of 16 nodes (the single human node was correctly placed), not
           "14". Both were understatements. Correction goes out on the rail with the
           result — they explicitly valued the per-node survey's precision, so the
           numbers have to be right. -->
- [x] Origin-free feasibility interval is non-empty post-reorder for both maps (was
      provably EMPTY for every origin pre-reorder)
- [x] Semantic delta is exactly lane declaration order — node/flow ids, lane→node
      membership, positions, heights, abbrs and authorities all compare equal pre/post
- [x] No generator drift rode in with the edit: the `emit_map`-vs-stored byte delta is
      **unchanged** by the reorder (−48B / −64B before *and* after)
      <!-- AC corrected mid-task, with evidence. As first written this AC demanded
           parse→emit be byte-identical to the stored bytes. Measured: it is not — and was
           not before the edit either, by exactly the same delta. The store carries three
           cosmetic differences from what the generator would emit (numeric entity
           `&#8594;` vs literal `→`, a hand-authored `laneSet id`, and flowNodeRef order
           within a lane). That is the already-known "prove rewrites store bytes" property
           of draft maps, not something this edit caused. Ticking the original wording
           would have been false; deleting it would have dropped the risk it was guarding.
           The delta-unchanged form is the invariant that actually guards the edit. -->
- [x] Live corpus baseline holds: `fw corpus lint` default scan still reports exactly the
      3 pinned findings, and all 5 conformance rails still PASS (45 corpus tests green)
- [x] Live-served designer bytes carry the new lane order (fetched from the running
      Watchtower, not read off disk — disk/live md5 match `0aaa69ab` / `538fd01a`)
- [ ] Result reported to 832 on the DM rail, naming explicitly the one thing only they can
      verify — that their T-310 importer now reconciles **zero** on these two maps, which
      needs their `POOL_Y`/`POOL_HEADER`/node-height constants we deliberately do not read

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

- [ ] [REVIEW] The two reordered drafts still read right, and the pending taste verdicts
      are re-collected against the corrected rendering rather than reinterpreted
  **Steps:**
  1. Open http://192.168.10.107:3001/designer and load `draft-exception-handling` (v3),
     then `draft-task-creation` (v3)
  2. Read the **band labels** against the nodes drawn inside them. Nothing moved — only the
     labels and the boundary between them changed, so the top band should now say
     `Framework · Authority` over the framework verbs it always contained
  3. Judge whether the corrected authority reading changes your taste verdict on either map
  **Expected:** each band's label matches the ownership of the steps drawn in it; the
  layout you reviewed before is otherwise unchanged (same nodes, same positions)
  **If not:** say which node reads as belonging to the other lane — that is a membership
  decision (yours), not a geometry repair (mine), and it goes back as a separate slice

  Why this is [REVIEW] and not [REVIEWER]: the structural half is fully covered by the
  Agent ACs above. What cannot be scanned is whether verdicts already formed against a
  contradicting rendering should stand. 832's position on rail 335 was "I would re-collect
  rather than reinterpret them"; that call is the operator's, and it is the reason this
  task closes partial-complete instead of clean.

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

# 1. Both repaired drafts are lane-geometry clean (they are drafts, so the default
#    scan skips them — they must be named explicitly or this proves nothing).
out=$(bin/fw corpus lint draft-exception-handling draft-task-creation 2>&1); echo "$out" | grep -q "CLEAN"
# 2. Declared lane order is the drawn order in both.
head -60 .context/designer/projects/draft-exception-handling/v3.bpmn | grep -A1 '<bpmn:laneSet' | grep -q 'bpmn:lane id="framework"'
out=$(grep -oE '<bpmn:lane id="[^"]+"' .context/designer/projects/draft-task-creation/v3.bpmn); echo "$out" | head -1 | grep -q 'framework'
# 3. Reorder is a pure permutation: membership, positions, heights and the
#    origin-free feasibility interval all re-checked against HEAD's bytes.
python3 -m pytest tests/unit/test_t2686_laneset_order.py -q
# 4. Live corpus baseline unmoved (still exactly the 3 pinned findings) and rails green.
out=$(bin/fw corpus lint 2>&1); echo "$out" | grep -q "^3 finding(s)"
python3 tools/corpus_conformance.py --all
# 5. Corpus suites green (lane-geometry rule + explain authority staging).
python3 -m pytest tests/unit/test_corpus_lint.py tests/unit/test_corpus_lint_lane_geometry.py tests/unit/test_corpus_explain.py -q

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

### 2026-07-29 — reorder the declaration, do not move the drawing

- **Chose:** swap the declared lane order to match the drawn order, leaving every
  `aef:position` and every `flowNodeRef` byte-untouched.
- **Why:** three independent confirmations that this is the zero-semantic repair.
  (1) 832 confirmed from source that band order derives purely from laneSet document
  order, so the reorder actually fixes the render. (2) `corpus_spec.canonical()` sorts
  lanes by id (`tools/corpus_spec.py:470`) — verified by reading it *and* by comparing
  canonical forms pre/post, which are identical. (3) The origin-free feasibility interval
  flips from EMPTY to non-empty, so the declaration becomes satisfiable at all.
- **Rejected:** moving the y positions. It would destroy the layout the operator drew and
  has already reviewed, and it is precisely what 832's shipped T-310 importer does
  (reconcile to declared lane, y ← lane centre) — collapsing 12 and 15 nodes to one row
  per lane. Getting ahead of that repair is the whole reason this task ran now.

### 2026-07-29 — the feasibility check does not become a lint rule in this task

- **Chose:** implement the origin-free feasibility interval as a test helper in
  `tests/unit/test_t2686_laneset_order.py`, and file the lint-rule question separately.
- **Why:** it is strictly stronger than the shipped `lane-geometry` ordering rule (ordered
  non-overlapping spans are necessary for feasibility, not sufficient) and it found the
  cleanest evidence in this task — an EMPTY interval is a *proof* the declaration is
  unsatisfiable for every origin, which is exactly the evidence class the T-2684 band
  model failed to produce. But shipping it as a corpus rule means deciding how it treats
  node-centre vs node-top resolution (832's `laneAtY` uses centre), and re-baselining
  every map against a stricter rule. That is a second deliverable.
- **Rejected:** bolting it onto `lane-geometry` now. T-2684's lesson was that a
  stronger-looking geometric check needs validating against the whole corpus before it is
  relied on; doing that inside a time-pressured repair is how the band model nearly
  shipped.

### 2026-07-29 — scope stops at the two swaps

- **Chose:** repair only `draft-exception-handling` and `draft-task-creation`.
- **Why:** 832's caveat is decisive and matches the maths. `aef-session-lifecycle` v1 is a
  *partial* overlap (3 agent-declared nodes inside the human band) and no permutation of
  lane order fixes a partial overlap — only y values do. `draft-knowledge-leveling` v8 is
  two nodes and is an authority question (which lane owns the dormant wait, which owns
  healing) that belongs to the operator with the taste round.
- **Rejected:** repairing all four in one pass. Two of them are not the same defect and
  one of them is not mine to decide.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-29T21:44:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2686-reorder-laneset-on-two-wholesale-inverte.md
- **Context:** Initial task creation
