---
id: T-1961
name: "/approvals ingestion of close-ready arcs — ARC CLOSURE section"
description: >
  T-1959 build child B: add 'ARC CLOSURE — ready for review (N)' section to /approvals.
  Source: arcs in-progress with >=0.80 completion AND a recommendation block on anchor
  task. Click-through navigates to /arcs/<slug>/review (read) or /close (act).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [approval-ux, watchtower, arc, T-1959-followup, arc:arc-grooming]
components: [tests/playwright/test_approvals_arc_closure_section.py, 
      tests/unit/approvals_close_ready_arcs.bats, web/blueprints/approvals.py, 
      web/templates/_approvals_content.html]
related_tasks: [T-1959, T-1960]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T17:56:41Z
last_update: '2026-06-11T22:23:27Z'
date_finished: 2026-05-21T17:44:53Z
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
  - ts: '2026-05-20T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1961: /approvals ingestion of close-ready arcs — ARC CLOSURE section

## Context

T-1959 child B. T-1960 wired the agent's `## Recommendation` onto the anchor task and surfaced it on `/arcs/<slug>/close`. But the human still has to *know* which arcs are close-ready — `/approvals` doesn't list them, so the cognitive load of "scan the arc kanban looking for ones near 100% with a recommendation" stays on the human.

T-1961 closes that loop: add an ARC CLOSURE section to `/approvals` listing arcs that are (a) `status: in-progress`, (b) completion ratio ≥ 0.80, AND (c) have a non-empty `## Recommendation` block on the anchor task. Each row links to `/arcs/<slug>/close` (act) — and to `/arcs/<slug>` (read) since T-1963's dedicated review route hasn't shipped yet.

The completion-threshold (≥0.80) plus the recommendation-present filter keeps the section sharply close-ready — not "every in-progress arc" — so the human acts on a curated list, not a generic queue.

## Acceptance Criteria

### Agent
- [x] `_load_close_ready_arcs()` helper in `web/blueprints/approvals.py` returns a list of dicts (slug, name, id, anchor, verdict, completion_ratio, completed, total, headline_mechanic). Filters: `status == "in-progress"`, completion ratio ≥ 0.80, `_anchor_recommendation(arc).present` truthy
- [x] `_build_approvals_context()` exposes `arcs_close_ready` (list) and `arc_close_count` (int); `total_count` adjusted to include it
- [x] `web/templates/_approvals_content.html` adds an `ARC CLOSURE — ready for review (N)` section that lists each close-ready arc with verdict badge, completion fraction, anchor link, and an Approve/Override CTA pointing to `/arcs/<slug>/close`
- [x] The section is suppressed (not rendered as an empty list) when zero arcs match
- [x] Bats unit test `tests/unit/approvals_close_ready_arcs.bats` pins the filter logic (uses fixture arc YAMLs) — three cases: in-progress + ratio<0.80 (excluded), in-progress + ratio≥0.80 + no rec (excluded), in-progress + ratio≥0.80 + rec present (included)
- [x] Playwright test `tests/playwright/test_approvals_arc_closure_section.py` asserts the section renders on `/approvals` with DOM-content assertions (T-1575) — no element-presence grep
- [x] `python3 -c "import ast; ast.parse(open('web/blueprints/approvals.py').read())"` succeeds
- [x] Watchtower restart + `curl /approvals` confirms section visibility — present when ≥1 arc qualifies, suppressed when none do

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

- [ ] [REVIEW] ARC CLOSURE section rhythm — section header reads consistently with the existing approval sections (INCEPTION GO, HUMAN ACs, etc.), verdict + completion-ratio fields don't crowd the row, Approve CTA is visually obvious
  **Steps:**
  1. Open http://192.168.10.107:3000/approvals
  2. Scan the page top-to-bottom looking for the ARC CLOSURE section
  **Expected:** Section appears with header "ARC CLOSURE — ready for review (N)". Each arc row shows name, verdict badge (CLOSE/GO/KEEP-OPEN), completion fraction (e.g. "12/15 — 80%"), anchor-task link, and an "Approve/Override" button linking to `/arcs/<slug>/close`. Rhythm matches sibling sections; nothing crowds or wraps awkwardly.
  **If not:** Note which visual element clashes (badge too small, completion fraction hard to read, CTA buried, header inconsistent).

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

python3 -c "import ast; ast.parse(open('web/blueprints/approvals.py').read())"
bats tests/unit/approvals_close_ready_arcs.bats
# T-2771: was `FW_TEST_PORT=3000` — same foreign-Watchtower defect as T-1960.
# See CLAUDE.md §Watchtower Port: the port is per-project, never a literal.
FW_TEST_PORT="$(bin/fw watchtower port)" python3 -m pytest tests/playwright/test_approvals_arc_closure_section.py -q
WT=$(bin/fw watchtower url); out=$(curl -s "$WT/approvals" 2>&1); [[ "$out" == *"approvals"* ]]
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

### 2026-05-21 — threshold choice (0.80) and "review" vs "act" link split
- **What changed:** T-1959 Scope Fence named close-readiness as "in-progress with ≥0.80 completion AND recommendation". The 0.80 threshold is what makes the queue useful — anything lower would re-pollute /approvals with every active arc. Survey on this corpus: 5 in-progress arcs; arc-grooming (0.85) and orchestrator-rethink (0.80) qualify, value-prioritisation (0.71) and others fall below — exactly the curated cut the scope fence asked for.
- **Plan impact:** T-1963 (/arcs/<slug>/review read-only route) hasn't shipped yet, so the "Review" CTA on each row temporarily points to `/arcs/<slug>` (existing detail page). When T-1963 lands, that link's `href` should swap to `/arcs/<slug>/review`. Marked in the template as a forward link to update.
- **Triggered:** No new sub-task — when T-1963 builds the read-only route, that task will own the link swap.

### 2026-05-21 — helper placement (approvals.py vs arcs.py)
- **What changed:** The filter logic depends on `_resolve_constituents`, `_completion_stats`, `_anchor_recommendation` — all in `arcs.py`. The natural placement of `_load_close_ready_arcs` is `arcs.py` (helper) + import from `approvals.py` (consumer). Chose to define it in `approvals.py` and import the three deps from `arcs.py` — keeps the approval-queue-builders co-located in one file (sibling of `_load_pending_go_decisions`, `_load_pending_human_acs`, etc.).
- **Plan impact:** No regression risk; the arc helpers stay pure read-only.
- **Triggered:** None.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Closes T-1959 child B end-to-end. T-1960 wired the agent's `## Recommendation` onto the anchor and rendered it on `/arcs/<slug>/close`; T-1961 surfaces the *queue* of close-ready arcs on `/approvals` so the human doesn't have to scan the arc kanban looking for "near-done with rec". Filter is sharp (in-progress + ≥0.80 + rec present), so the queue stays curated, not generic. Two arcs currently qualify on this corpus (arc-grooming 0.85, orchestrator-rethink 0.80) — both render with verdict + completion + anchor link + Approve/Override CTA. Render-surface gate satisfied by the [REVIEW] AC.

**Evidence:**
- `web/blueprints/approvals.py`: new `_load_close_ready_arcs(threshold=0.80)` helper imports the three arc helpers from `arcs.py`, returns sorted list of qualifying arcs with all template fields (slug, name, id, anchor, verdict, completion ratio/count, headline_mechanic)
- `_build_approvals_context()` exposes `arcs_close_ready`, `arc_close_count`; `total_count` includes it
- `web/templates/_approvals_content.html`: new ARC CLOSURE section above Paused Dispatches with consistent rhythm (h2 + section-header + .approval-card rows); summary count strip includes Arc Closure card when ≥1 qualifies; section suppressed when 0
- bats `tests/unit/approvals_close_ready_arcs.bats` (6 tests, PASS) — pins the three filter dimensions with fixture YAMLs (ratio<0.80, no-rec, happy-path, closed-arc, verdict CLOSE/KEEP-OPEN/GO, empty-rec)
- Playwright `tests/playwright/test_approvals_arc_closure_section.py` (5 tests, PASS) — DOM-content per T-1575: h2 present, summary card with digit value, verdict badge + completion fraction on each row, /close CTA href, anchor task link
- Live smoke: `curl /approvals` shows `<h2 id="section-arc-closure">Arc Closure</h2>` + 2 cards (arc-grooming GO, orchestrator-rethink GO)

**Review on Watchtower:** http://192.168.10.107:3000/review/T-1961

## Updates

### 2026-05-20T17:56:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1961-approvals-ingestion-of-close-ready-arcs-.md
- **Context:** Initial task creation

### 2026-05-21T17:37:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-56be8ff9
- **Timestamp:** 2026-05-21T17:45:18Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `web/templates/_approvals_content.html` adds an `ARC CLOSURE — ready for review (N)` section that lists each close-ready arc with verdict badge, completion fraction, anchor link, and an Approve/Overri
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/_approvals_content.html in: `web/templates/_approvals_content.html` adds an `ARC CLOSURE — ready for review (N)` section that lists each close-ready arc with verdict badge, compl`

### 2026-05-21T17:44:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
