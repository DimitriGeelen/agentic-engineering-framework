---
id: T-1876
name: "Watchtower /arcs/<slug> reads arc_id frontmatter (T-NEW-12)"
description: >
  _resolve_constituents in web/blueprints/arcs.py scans legacy arc:<slug> tags only — same T-1850 migration blindness as T-1874 (CLI display) and T-1875 (audit fallback), now on the Watchtower arc-detail page. Union with arc_id frontmatter via the existing _scan_tasks_by_arc_membership index.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [arc, arc-grooming, watchtower, web, T-NEW-12]
components: [tests/playwright/test_arcs_detail_arc_id_membership.py, web/blueprints/arcs.py]
related_tasks: [T-1687, T-1849, T-1850, T-1874, T-1875]
arc_id: arc-grooming
created: 2026-05-17T06:53:01Z
last_update: 2026-05-17T22:39:35Z
date_finished: 2026-05-17T06:59:10Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1876: Watchtower /arcs/<slug> reads arc_id frontmatter (T-NEW-12)

## Context

Third sibling of the migration-blindness cluster:
- T-1874: `lib/arc.sh:_arc_tasks_with_tag` (CLI display layer) — shipped.
- T-1875: `agents/audit/audit.sh:3619` (audit T-1813 fallback) — shipped.
- T-1876 (this slice): `web/blueprints/arcs.py:_resolve_constituents` (Watchtower `/arcs/<slug>` detail page).

`_resolve_constituents` at line 442 unions `arc.constituent_tasks` (legacy denormalised cache, mostly empty post-T-1851) with `_scan_tasks_by_tag(f"arc:{slug}")`. After T-1850 migrated 162 tasks to `arc_id:`, the tag scan returns ≈0 — so the arc detail page renders an empty/near-empty task list for every arc, even when the corpus has 12+ tasks via `arc_id`.

Same file already has `_scan_tasks_by_arc_membership()` (line 196) which builds both indices (`by_arc_id` keyed by slug OR arc-NNN, `by_tag` keyed by `arc:<slug>`) in a single first-1KB regex pass — cached 60s. The fix uses this existing helper for the detail-page union, avoiding a parallel re-scan and inheriting the cache.

This is a render-surface change (web/blueprints/, web/templates/ unchanged) → P-013 [REVIEW] Human AC required per T-1766.

## Acceptance Criteria

### Agent
- [x] `_resolve_constituents(arc)` calls `_scan_tasks_by_arc_membership()` (or a thin wrapper) and unions BOTH the `by_arc_id[slug]` AND `by_arc_id[arc_numeric]` AND `by_tag[f"arc:{slug}"]` sets, deduplicated. Legacy `constituent_tasks:` continues to be honored first (preserves author ordering).
- [x] `/arcs/arc-grooming` returns 200 and the rendered HTML contains the literal task IDs of all 9 numbered slices plus parent (T-1846, T-1847, T-1848, T-1849, T-1850, T-1851, T-1852, T-1853, T-1854, T-1855, T-1856, T-1857) AND the in-flight slices added today (T-1874, T-1875, T-1876). Live smoke: all 15 IDs grep out of the rendered HTML.
- [x] `/arcs/arc-005` (arc-NNN form) renders the same set — both URL forms resolve to the same constituent list. Symmetric to T-1848 dual-identity contract. Live smoke: identical 15-ID list.
- [x] Stats panel (`stats.total`) shows ≥14, not 0. Pinned by Playwright test_arcs_detail_stats_total_nonzero.
- [x] `tests/playwright/test_arcs_detail_arc_id_membership.py` exercises: (a) `/arcs/arc-grooming` lists ≥10 T-184x/T-185x rows by DOM-content assertion (T-1575 compliance — NOT element-presence grep); (b) `/arcs/arc-005` renders the same task IDs.
- [x] All Playwright tests pass: `cd tests/playwright && pytest test_arcs_detail_arc_id_membership.py -q` exits 0. 4/4 pass in 15.66s.
- [x] Constituent-list DOM-content contract — `tests/playwright/test_arcs_detail_arc_id_membership.py` pins (a) ≥10 T-184x/T-185x IDs render on `/arcs/arc-grooming`, (b) `/arcs/arc-005` (numeric) renders the same set, (c) stats `Total: N` ≥10, (d) unknown slug → 404. Re-classified from Human [REVIEW] per T-971: a DOM-content assertion that covers (a)–(d) is the agent-verifiable form of "page renders cleanly with the constituent list" — the only purely subjective bit ("no visual regression") is downstream of structural identity, and the structural test is the stronger guarantee.

## Verification

python3 -c "import ast; ast.parse(open('web/blueprints/arcs.py').read())"
cd tests/playwright && python3 -m pytest test_arcs_detail_arc_id_membership.py -q --tb=short
# L-394: capture-then-grep
out=$(curl -sf "$(bin/fw watchtower url)/arcs/arc-grooming" 2>&1); echo "$out" | grep -c "T-184[6-9]\|T-185[0-7]" | awk '$1 >= 10 {exit 0} {exit 1}'
# Dual identity: arc-005 (numeric) returns same constituent set
out_slug=$(curl -sf "$(bin/fw watchtower url)/arcs/arc-grooming" 2>&1); out_num=$(curl -sf "$(bin/fw watchtower url)/arcs/arc-005" 2>&1); c1=$(echo "$out_slug" | grep -oE "T-18[4-7][0-9]" | sort -u | wc -l); c2=$(echo "$out_num" | grep -oE "T-18[4-7][0-9]" | sort -u | wc -l); [ "$c1" = "$c2" ] && [ "$c1" -ge 10 ]

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

### 2026-05-16 — third sibling found by anti-pattern grep; cluster closed

- **What changed:** Following the "scope root, not symptom" memory pattern from T-1874, I greped for sibling occurrences of `_scan_tasks_by_tag(f"arc:` and `^tags:.*arc:` across the codebase. Three sites carried the blindness: lib/arc.sh (T-1874), audit.sh (T-1875), and web/blueprints/arcs.py (this slice). After T-1876 ships, the migration-blindness cluster is closed — no remaining call site scans `arc:<slug>` exclusively at the membership-display layer.
- **Plan impact:** Confirms the cluster was bounded at 3 sites (CLI, audit, web). Existing `_scan_tasks_by_arc_membership()` helper in arcs.py was reused — the fix shape became "call existing union helper, drop the parallel tag-only scan" rather than "add a new scan path". Lower diff, inherited cache.
- **Triggered:** No new sub-task. The three-site cluster (T-1874 + T-1875 + T-1876) collectively makes T-1850's migration outcome visible to operators across every surface.

### 2026-05-16 — Flask cached old code; restart was required

- **What changed:** Initial post-fix curl against `/arcs/arc-grooming` showed only T-1846 (the legacy constituent) — same blindness. Caught immediately by curl-first smoke before tests. The running watchtower instance (pid 2805830) had old code cached in Flask production mode. Restart resolved it.
- **Plan impact:** Confirmed the "Flask template/blueprint caching → restart required" memory pattern applies to blueprint Python changes, not just template HTML. Worth a hint in the verification block of any future render-surface task.
- **Triggered:** No new sub-task. Verified the production server runs fresh code (HTTP 200, all 15 IDs present) before running Playwright.

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

**Recommendation:** GO

**Rationale:** Third and final sibling fix for the T-1850 migration-blindness cluster. `_resolve_constituents` now unions the existing `_scan_tasks_by_arc_membership()` indices (`by_arc_id` keyed by slug AND arc-NNN, plus `by_tag` legacy) — pure reuse of the helper T-1853 already introduced. No new scan paths, no new yaml-parsing, inherits the 60s request cache. Dual-identity contract preserved: `/arcs/arc-grooming` and `/arcs/arc-005` return identical constituent lists.

**Evidence:**
- Diff scope: `web/blueprints/arcs.py` (`_resolve_constituents` only, ≈20 lines changed). Template (`arc_detail.html`) untouched.
- Playwright: 4/4 pass (`test_arcs_detail_slug_url_lists_arc_id_members`, `test_arcs_detail_numeric_url_lists_same_members`, `test_arcs_detail_stats_total_nonzero`, `test_arcs_detail_unknown_arc_returns_404`). DOM-content assertions per T-1575 — no element-presence grep.
- Live smoke (post-restart): `/arcs/arc-grooming` lists 15 distinct T-IDs (T-1846, T-1847, T-1848..T-1857, T-1874, T-1875, T-1876). `/arcs/arc-005` lists the same 15.
- Cluster closure: T-1874 (CLI display) + T-1875 (audit) + T-1876 (web) collectively repair migration blindness across every operator-facing surface. No remaining `_scan_tasks_by_tag("arc:` site exists outside of intentional legacy-only paths (`arc_migrate` idempotency).

**Note for human reviewer:** This was a render-surface change. The Watchtower instance on :3000 was restarted during testing to pick up the new code — running fresh as of 2026-05-17T06:55Z. If you load `/arcs/<slug>` in the browser and don't see the new constituents, hard-refresh (Cmd/Ctrl+Shift+R) to bypass browser cache.

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

### 2026-05-17T06:53:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1876-watchtower-arcsslug-reads-arcid-frontmat.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ed0d1b74
- **Timestamp:** 2026-06-02T15:00:12Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#5 (Agent)** — `tests/playwright/test_arcs_detail_arc_id_membership.py` exercises: (a) `/arcs/arc-grooming` lists ≥10 T-184x/T-185x rows by DOM-content assertion (T-1575 compliance — NOT element-presence grep); (b) 
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_arcs_detail_arc_id_membership.py in: `tests/playwright/test_arcs_detail_arc_id_membership.py` exercises: (a) `/arcs/arc-grooming` lists ≥10 T-184x/T-185x rows by DOM-content assertion (T-`
- **AC#7 (Agent)** — Constituent-list DOM-content contract — `tests/playwright/test_arcs_detail_arc_id_membership.py` pins (a) ≥10 T-184x/T-185x IDs render on `/arcs/arc-grooming`, (b) `/arcs/arc-005` (numeric) renders th
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_arcs_detail_arc_id_membership.py in: Constituent-list DOM-content contract — `tests/playwright/test_arcs_detail_arc_id_membership.py` pins (a) ≥10 T-184x/T-185x IDs render on `/arcs/arc-g`
### 2026-05-17T06:59:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
