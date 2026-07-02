---
id: T-2042
name: "ux-review height-check covers all parameterless Watchtower routes — close the
  5-page detector gap (T-2041 follow-up)"
description: >
  ux-review height-check covers all parameterless Watchtower routes — close the 5-page
  detector gap (T-2041 follow-up)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/ux-review/ux-review.py, tests/unit/test_ux_review_routes.py]
related_tasks: [T-2038, T-2039, T-2040, T-2041, T-2005]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T14:44:18Z
last_update: '2026-06-11T22:24:05Z'
date_finished: 2026-05-25T14:48:02Z
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
  - ts: '2026-05-25T14:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T14:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2042: ux-review height-check covers all parameterless Watchtower routes — close the 5-page detector gap (T-2041 follow-up)

## Context

G-019 root of the unbounded-page class (T-2038/T-2039/T-2040/T-2041). The ux-review
sweep records per-page rendered height (`shot_h`, full/clipped vs `TALL_PAGE_CAP_PX`) —
the detector exists — but it only runs over 5 hard-coded pages
(`DEFAULT_SWEEP_PAGES = ["/", "/tasks", "/approvals", "/fabric", "/arcs"]`). That is
exactly why `/inception` (83k) and `/timeline` (90k) grew unbounded undetected: they were
never in the list. Widening the static list just defers the next miss. Fix: derive the
page set from the running app's route map (`web.app.app.url_map`) so every parameterless
GET route is height-checked automatically — the detector can no longer be blind to a page
simply because nobody remembered to add it. See [[project_unbounded_watchtower_pages]].

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `discover_get_routes()` added to `agents/ux-review/ux-review.py` — enumerates `web.app.app.url_map`, returns sorted parameterless GET paths, excludes rules with arguments, `/api/*`, `/static/*`, and non-GET endpoints
- [x] `--all-routes` CLI flag sets the sweep page list to the discovered routes (existing sweep machinery then records `shot_h`/Capture for every page); falls back to `DEFAULT_SWEEP_PAGES` when discovery fails (import error), with a stderr note — confirmed in `--help`
- [x] Discovery includes the two pages this class previously missed (`/inception`, `/timeline`) and excludes parameterized routes (`/tasks/<id>`, `/review/<id>`) and `/api/*` — **47 routes** discovered (up from 5)
- [x] Unit test `tests/unit/test_ux_review_routes.py` pins the discovery contract (includes known growing pages, excludes param/api/static), passes — **3 passed**
- [x] New test registered in the component fabric (`fw fabric register`) — `.fabric/components/tests-unit-test_ux_review_routes.yaml`

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
python3 -m pytest tests/unit/test_ux_review_routes.py -q 2>&1 | tail -3
python3 -c "import sys; sys.argv=['x']; import importlib.util as u; s=u.spec_from_file_location('uxr','agents/ux-review/ux-review.py'); m=u.module_from_spec(s); s.loader.exec_module(m); r=m.discover_get_routes(); assert '/inception' in r and '/timeline' in r, r; assert not any('<' in p for p in r), r; print('discover_get_routes ok:', len(r), 'routes')"

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

### 2026-05-25 — detector already recorded height; only its scope was wrong

- **What changed:** The sweep already captures per-page `shot_h` and a full/clipped Capture
  verdict against `TALL_PAGE_CAP_PX` — the *measurement* was never the gap. The gap was
  purely the 5-entry `DEFAULT_SWEEP_PAGES` list deciding *which* pages get measured. So this
  task is a coverage change, not a new detector: feed the existing machinery every route.
- **Plan impact:** No new height-assertion logic needed (the sweep report's Capture column
  already flags clipped pages). The deliverable shrank to one discovery helper + one flag +
  the fallback. The "add a height-regression gate" idea floated at filing was unnecessary —
  the per-page Playwright tests (T-2038..T-2041) already gate the specific pages, and the
  exhaustive sweep gives the operator a full-corpus snapshot on demand.
- **Triggered:** None. The class is now both *fixed* on all 4 found pages and *guarded*
  exhaustively at the detector. If a future page grows unbounded, `--all-routes` surfaces it
  in the Capture column without anyone editing a list.

## Decisions

### 2026-05-25 — url_map-derived page set vs. widened static list

- **Chose:** Derive the sweep page set from `web.app.app.url_map` (`discover_get_routes()`),
  gated behind `--all-routes`, with a fallback to `DEFAULT_SWEEP_PAGES` on import failure.
- **Why:** A static list is exactly what caused the blindness — it drifts behind the route
  table and silently omits new pages (the /inception, /timeline misses). Deriving from the
  url_map is self-maintaining: a page added to the app is height-checked the next sweep with
  zero list edits. Excluding parameterized/`/api`/`/static` rules keeps it to loadable human
  surfaces.
- **Rejected:** (a) *Widen the static list to 7 (+inception,+timeline)* — defers the next
  miss, doesn't close the class. (b) *Replace `--sweep` default with discovery* — would
  change the theme-bridge sweep's scope and slow it 5→47 pages unconditionally; kept behind
  an opt-in flag so the fast 5-page theme sweep is unchanged.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the G-019 root of the unbounded-page class. The ux-review height
detector now derives its page set from the app url_map (47 routes) instead of a 5-entry
hard-code, so a page can no longer grow unbounded simply because nobody added it to a
list. Both previously-missed pages (/inception, /timeline) are now in scope; the discovery
contract is pinned by a unit test. Pure tooling — no render surface, all criteria
agent-verifiable.

**Evidence:**
- `discover_get_routes()` returns **47** parameterless GET routes (was 5 hard-coded); includes /inception + /timeline, excludes params/`/api`/`/static`
- `tests/unit/test_ux_review_routes.py`: **3 passed**
- `--all-routes` flag present in CLI `--help`; falls back to `DEFAULT_SWEEP_PAGES` on import failure
- `agents/ux-review/ux-review.py` — `discover_get_routes()` + `--all-routes` wiring

## Updates

### 2026-05-25T14:44:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2042-ux-review-height-check-covers-all-parame.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4b49545e
- **Timestamp:** 2026-06-02T15:00:52Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — New test registered in the component fabric (`fw fabric register`) — `.fabric/components/tests-unit-test_ux_review_routes.yaml`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/tests-unit-test_ux_review_routes.yaml in: New test registered in the component fabric (`fw fabric register`) — `.fabric/components/tests-unit-test_ux_review_routes.yaml``
### 2026-05-25T14:48:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
