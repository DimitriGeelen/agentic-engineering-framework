---
id: T-1939
name: "BVP T-1936/T-1937 sibling — /arcs/<slug> BVP signals use constituent rollup"
description: >
  BVP T-1936/T-1937 sibling — /arcs/<slug> BVP signals use constituent rollup

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:value-prioritisation, parity, render-surface]
components: [tests/playwright/test_arc_detail_bvp.py, tests/unit/test_bvp_scatter_arc_mode.py, web/blueprints/arcs.py, web/blueprints/bvp.py, web/templates/arc_detail.html, web/templates/bvp.html]
related_tasks: [T-1936, T-1937, T-1938, T-1934]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-19T20:10:10Z
last_update: 2026-05-20T18:24:23Z
date_finished: 2026-05-20T18:24:23Z
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
  - ts: '2026-05-19T20:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1939: BVP T-1936/T-1937 sibling — /arcs/<slug> BVP signals use constituent rollup

## Context

T-1936 shipped constituent-task rollup on `/bvp` scatter (5 arcs render
at BVP norms 0.31-0.53). T-1937 ported the same rollup to the `fw bvp arcs`
CLI. The `/arcs/<slug>` BVP signals block in `web/blueprints/arcs.py:_bvp_signals`
remained at the original "direct-only" implementation — it reads
`arc.get("bvp_scores")` and falls through to `has_scores=False` with the
text "Arc has no `bvp_scores:` set".

Visible drift: `/arcs/value-prioritisation` currently shows
"Arc has no bvp_scores: set" while `/bvp` shows the same arc at BVP=37
norm=0.31. Two render surfaces, same arc data, diverged output. Live
curl evidence captured at filing time.

Fix: `_bvp_signals` should call the existing helpers from
`web.blueprints.bvp` (`_arc_member_tasks`, `_arc_rolled_up_scores`) when
direct `bvp_scores:` is absent, mirroring `_collect_arc_points` ladder
(direct-confirmed → direct-proposed → rollup → empty). When rolled-up
signals are surfaced, the template should label them clearly so the
human sees provenance (`derived-confirmed` / `derived-proposed`).

Render-surface (P-013): this edits `web/blueprints/arcs.py` → gate
requires `[REVIEW]` Human AC for visual verification.

## Acceptance Criteria

### Agent
- [x] `_bvp_signals(arc, slug, numeric)` falls back to constituent-task rollup when arc lacks direct `bvp_scores:`, mirroring `web.blueprints.bvp._collect_arc_points`
- [x] Returns a new `bvp_mode` field in the signal dict (`""` / `"direct-confirmed"` / `"direct-proposed"` / `"derived-confirmed"` / `"derived-proposed"`) so the template can label provenance
- [x] `has_scores=True` when rollup yields any scores (template renders the BVP block instead of the "no scores" stub)
- [x] `per_driver` rows populated from rolled-up scores when direct are absent
- [x] Live verification: `curl -sf http://localhost:PORT/arcs/value-prioritisation 2>&1 | grep -q "derived"` confirms the provenance label appears in HTML
- [x] Live verification: same page no longer shows "Arc has no bvp_scores: set" when constituent tasks have scores
- [x] Unit tests in `tests/unit/test_bvp_signals_rollup.py` cover: direct-confirmed bypass, derived-confirmed via task rollup, mixed-mode degrades to derived-proposed, fallback to empty when no signal anywhere
- [x] All new tests PASS; existing tests still PASS (`unit/test_bvp_blueprint_cost.py`, `unit/test_bvp_cli_arcs_rollup.py`, `unit/test_bvp_cli_rank_proposed.py`)

### Human
- [ ] [REVIEW] `/arcs/value-prioritisation` BVP signals block renders coherently with the new rollup data
  **Steps:**
  1. Open http://localhost:3000/arcs/value-prioritisation (or current Watchtower URL)
  2. Locate the "BVP signals" section
  3. Confirm it now shows a numeric BVP_norm + per-driver breakdown (not the "no scores set" stub)
  4. Confirm provenance label visible (e.g. "derived-proposed" or similar wording)
  5. Confirm the per-driver score grid is populated with integer values
  **Expected:** BVP block shows arc-006 at BVP_norm≈0.31, per-driver scores visible, provenance labelled as derived
  **If not:** Screenshot what renders + paste section HTML; note whether numbers/labels disagree with `bin/fw bvp arcs` for arc-006

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

cd /opt/999-Agentic-Engineering-Framework/tests && python3 -m pytest unit/test_bvp_signals_rollup.py unit/test_bvp_blueprint_cost.py unit/test_bvp_cli_arcs_rollup.py unit/test_bvp_cli_rank_proposed.py -q
out=$(curl -sf "$(cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url)/arcs/value-prioritisation" 2>&1); grep -q "derived" <<<"$out"
out=$(curl -sf "$(cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url)/arcs/value-prioritisation" 2>&1); ! grep -q "Arc has no .bvp_scores: set" <<<"$out"

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

## Recommendation

**Recommendation:** GO (pending [REVIEW] visual check)

**Rationale:** Third sibling drift in the BVP arc-006 cluster fixed —
`_bvp_signals` on `/arcs/<slug>` now mirrors `_collect_arc_points` on
`/bvp`. Same 4-tier resolution ladder, same sovereignty semantics,
same per-driver rollup. Provenance label exposed via new `bvp_mode`
field and rendered in the template's stats strip.

**Evidence:**
- `curl /arcs/value-prioritisation` shows `Source: <code>derived-proposed</code>` (was: "Arc has no bvp_scores: set")
- Arc BVP_norm = 0.333 displayed (web) — broadly aligns with CLI `fw bvp arcs` 0.31 (small delta reflects new T-1937/T-1938 proposed scores added between captures, not a logic gap)
- 6/6 new unit tests PASS; 89/89 BVP test suite total still PASS
- Three render surfaces (/bvp scatter, fw bvp arcs CLI, /arcs/<slug>) now agree on the same arc data

## Evolution

### 2026-05-19 — three render surfaces now match

- **What changed:** Discovered after T-1937/T-1938 commits that `/arcs/<slug>` was still showing "Arc has no bvp_scores: set" while `/bvp` rolled up the same arc. Same root cause as T-1936/T-1937 (silent-corpus, L-329).
- **Plan impact:** Original BVP arc inception (T-1915) listed `/bvp` as primary surface. Arc-detail BVP block (T-1930) was added later but the T-1936 rollup helpers only got integrated into the scatter, not the detail page. Three render surfaces, three sweeps required to reach parity.
- **Triggered:** This task (T-1939). Possible next: `agents/audit/audit.sh` per-driver coherence check (T-1927) reads task `bvp_scores` directly without proposed fallback. Different semantics there (coherence wants confirmed-only), so likely no action needed — but deferred to a 1-task assessment if a 4th drift emerges.

## Decisions

### 2026-05-19 — bvp_mode in signal dict vs separate function

- **Chose:** Return `bvp_mode` as a field on the existing signal dict.
- **Why:** Template can branch on it via `{% if bvp_info.bvp_mode == 'derived-proposed' %}`. Adding a separate function would require a second template call site for no benefit.
- **Rejected:** Compute mode in template via flags — would couple template to module-internal helpers.

### 2026-05-19 — template badge below stats vs inline

- **Chose:** Place provenance line under the stats strip (one extra `<p class="muted">` line, only when `bvp_mode != 'direct-confirmed'`).
- **Why:** Direct-confirmed is the "normal" case — no badge clutter. Derived/proposed cases get a humble explainer so the reader doesn't think the numbers came from human review.
- **Rejected:** Always render the source line (too visually noisy for the common case).

<!-- ORIGINAL Evolution template, kept below for arc-tagged completion gate (T-1718).

     REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
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

### 2026-05-19T20:10:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1939-bvp-t-1936t-1937-sibling--arcsslug-bvp-s.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-04946b69
- **Timestamp:** 2026-05-20T18:24:26Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#7 (Agent)** — Unit tests in `tests/unit/test_bvp_signals_rollup.py` cover: direct-confirmed bypass, derived-confirmed via task rollup, mixed-mode degrades to derived-proposed, fallback to empty when no signal anywh
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/test_bvp_signals_rollup.py in: Unit tests in `tests/unit/test_bvp_signals_rollup.py` cover: direct-confirmed bypass, derived-confirmed via task rollup, mixed-mode degrades to derive`
- **AC#1 (Human)** — [REVIEW] `/arcs/value-prioritisation` BVP signals block renders coherently with the new rollup data
  - **human-ac-mechanical-signal** (partial, heuristic) — `matched='shows a' in Expected: BVP block shows arc-006 at BVP_norm≈0.31, per-driver scores visible, provenance labelled as derived`

### 2026-05-20T18:24:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
