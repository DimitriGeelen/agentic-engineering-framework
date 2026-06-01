---
id: T-1941
name: "BVP T-1940 sibling — emit bvp_mode in /bvp scatter arc payload + tooltip"
description: >
  BVP T-1940 sibling — emit bvp_mode in /bvp scatter arc payload + tooltip

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:value-prioritisation, render-surface, parity, drift]
components: [bin/fw, tests/playwright/test_bvp_scatter.py, tests/unit/test_bvp_scatter_arc_mode.py, tests/unit/test_cron_registry_generated_drift.bats, web/blueprints/bvp.py, web/templates/bvp.html]
related_tasks: [T-1940, T-1939, T-1937, T-1938, T-1936, T-1934, T-1928]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-19T21:17:25Z
last_update: 2026-05-20T18:28:21Z
date_finished: 2026-05-20T18:28:21Z
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
  - ts: '2026-05-19T21:45:02Z'
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
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1941: BVP T-1940 sibling — emit bvp_mode in /bvp scatter arc payload + tooltip

## Context

T-1936 added the 4-tier ladder (direct-confirmed → direct-proposed →
derived-confirmed → derived-proposed) for arc BVP rollup. T-1939 plumbed
`bvp_mode` through to /arcs/<slug>. T-1940 pinned the structural label
with Playwright. **But the /bvp scatter payload (`_collect_arc_points` in
`web/blueprints/bvp.py`) computes `bvp_mode` locally and discards it**:
the returned dict carries only `proposed: bool`, not the mode slug.

Result: the scatter view (and any tooltip consumer) sees arcs as binary
confirmed/proposed and cannot distinguish:
  - direct-confirmed (anchored arc-level score)  vs
  - derived-confirmed (rolled up from members)
or:
  - direct-proposed (estimator on arc itself)    vs
  - derived-proposed (rollup with ≥1 proposed input)

This is the 7th silent-corpus / silent-divergence site in the BVP cluster
(L-407 generalised pattern). Caught by inspection after T-1940 landed —
proves the agent's own grep sweep missed it because it scans for `bvp_scores`
(a field), not for *consumers of bvp_mode* (a computed value never written
to a payload).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `_collect_arc_points` returns `bvp_mode` in each arc point dict
- [x] arc points always carry one of the 4 mode slugs or empty string (never missing key)
- [x] tooltip in `web/templates/bvp.html` surfaces mode for arc dots (visible to user)
- [x] unit test pins `bvp_mode` in payload for synthetic direct-confirmed + derived-proposed fixtures
- [x] live /bvp page renders without error; arc dot tooltip shows mode
- [x] live curl test: payload JSON for arcs contains `"bvp_mode":` key
- [x] post-grill governance closure (L-349): arc_id, tags, related_tasks; sibling pre-files if needed

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

- [ ] [REVIEW] Tooltip on /bvp scatter clearly communicates rollup vs direct provenance for arc dots
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && curl -sf http://localhost:3000/bvp` (verify page renders)
  2. Open http://localhost:3000/bvp in browser
  3. Hover an arc dot (orange, larger than task dots)
  4. Tooltip should surface the `bvp_mode` slug (e.g. "derived-proposed") clearly
  **Expected:** Mode is visible and parseable; visual weight of the label feels right
  **If not:** Note tooltip styling concern; reopen task or file follow-up

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

**Recommendation:** GO

**Rationale:** 7th silent-corpus / silent-divergence drift site in the BVP
cluster (L-407 generalised pattern). T-1936 added the 4-tier rollup ladder
with `bvp_mode` as the provenance signal, but `_collect_arc_points` consumed
`bvp_mode` locally to decide the `is_proposed` flag and then *dropped it*
from the payload. The scatter consequently could only distinguish "confirmed
vs proposed" — not "direct vs derived". This slice closes the gap:
  - `_collect_arc_points` now emits `bvp_mode` in every arc point dict
  - tooltip surfaces the slug as `source: <code>derived-proposed</code>`
  - unit tests pin the contract per mode variant (6 cases)
  - live payload confirmed via curl

**Evidence:**
  - `web/blueprints/bvp.py` arc payload dict gains `"bvp_mode": bvp_mode or ""`
  - `web/templates/bvp.html` tooltip surfaces mode for arc dots
  - `tests/unit/test_bvp_scatter_arc_mode.py` — 6 new tests, all pass
  - Live curl: `"bvp_mode": "derived-proposed"` present in /bvp page payload
  - Watchtower restarted clean; no errors in `/tmp/watchtower-restart.log`

## Evolution

### 2026-05-19 — 7th drift site found AFTER T-1939 "complete" sweep
- **What changed:** Sweep target was wrong. We swept for `bvp_scores` *readers*
  (storage-field consumers). What we missed was readers of `bvp_mode` (a
  *computed* value never written to storage). The 7th site computed it but
  failed to *propagate* it.
- **Plan impact:** L-407 needs a strengthening note — silent-divergence
  sweep must cover BOTH storage-field readers AND computed-value
  propagators. Otherwise a "complete" sweep declared after T-1939 misses
  the propagation class entirely.
- **Triggered:** Filed T-1941 (this task) immediately after T-1940
  commit. No further sibling tasks; this closes the BVP rendered-mode
  parity surface.

## Decisions

### 2026-05-19 — extend tooltip vs add separate UI element
- **Chose:** extend the existing scatter tooltip with a `<small>source:</small>` line
- **Why:** Tooltip is the established channel for per-dot metadata
  (already shows `(proposed)`, name, cost breakdown). Adding `bvp_mode`
  there keeps related provenance info co-located.
- **Rejected:** add a separate legend or in-page annotation —
  premature surface area; tooltip is sufficient unless aesthetic review
  pushes back.

### 2026-05-19 — emit mode only for arc dots, not task dots
- **Chose:** tooltip's `provenance` substring guards on `d.kind === "arc"`
- **Why:** Tasks have no rollup concept (their scores ARE their scores;
  there's no derived/direct distinction). Emitting mode for tasks would
  add empty/meaningless lines.
- **Rejected:** uniform mode emission — would force a task-side mode
  semantic that doesn't exist.

### 2026-05-19 — `bvp_mode or ""` fallback in payload
- **Chose:** defensive empty-string fallback even though the `continue`
  branch above should make `bvp_mode == ""` unreachable.
- **Why:** Defensive — the field MUST always be present (test pins this).
  Future refactoring that re-orders the resolution logic would not silently
  drop the key.
- **Rejected:** omit the key when unset — would create the same
  silent-corpus pattern this slice exists to close.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-19T21:17:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1941-bvp-t-1940-sibling--emit-bvpmode-in-bvp-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-b71f78c6
- **Timestamp:** 2026-05-20T18:28:22Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — tooltip in `web/templates/bvp.html` surfaces mode for arc dots (visible to user)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/bvp.html in: tooltip in `web/templates/bvp.html` surfaces mode for arc dots (visible to user)`

### 2026-05-20T18:28:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
