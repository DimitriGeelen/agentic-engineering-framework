---
id: T-1853
name: "Watchtower /arcs lifecycle filter tabs (T-NEW-5b)"
description: >
  web/blueprints/arcs.py + templates render 4 filter tabs on /arcs index: draft, in-progress (default), closed, abandoned. Filter restricts list. Playwright test guards rendering + clickability. UI verification needs eyes — element-presence grep forbidden per T-1575; required: Playwright screenshot OR DOM-content assertion. Deps: T-NEW-5a.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [build, lifecycle, ui, watchtower, T-NEW-5b]
components: [C-004, lib/arc.sh, tests/unit/arc_lifecycle_state_machine.bats, tests/unit/audit_stale_arc_warning.bats]
related_tasks: [T-1846, T-1847]
arc_id: arc-grooming
created: 2026-05-15T14:53:04Z
last_update: 2026-05-18T09:41:08Z
date_finished: 2026-05-16T22:26:31Z
---

# T-1853: Watchtower /arcs lifecycle filter tabs (T-NEW-5b)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `/arcs` index renders four filter tabs: draft, in-progress (default), closed, abandoned + an "all" tab (T-1852 four-state lifecycle + "all" synthetic)
- [x] Clicking each tab restricts the arc list to that status (server-side `?status=<label>` query param routed through `_filter_arcs`)
- [x] Default landing view = in-progress tab active (Playwright `test_arcs_default_landing_marks_in_progress_active` proves it)
- [x] Counter badges show count per state (rendered as `.tab-count` spans on every tab — Playwright `test_arcs_tabs_carry_counter_badges` proves it)
- [x] Playwright test in `tests/playwright/test_arcs_lifecycle_tabs.py` guards each tab renders + is clickable + restricts the list (DOM-content assertion via Playwright `expect`, NOT element-presence grep — T-1575)
- [x] `curl -sf "$(bin/fw watchtower url)/arcs"` returns 200 and HTML contains all four state labels + stale badge wires through (verified via FW_STALE_ARC_DAYS=0 forcing all 5 in-progress arcs stale → 5 badge-warn spans; revert to default → 0 spans)

### Human
- [x] [REVIEW] Filter strip + stale badge fit Watchtower's visual rhythm and the operator finds the new surface intuitive
  **Steps:**
  1. Open `http://localhost:3000/arcs` (or the LAN URL from `bin/fw watchtower url`). Default view should land on in-progress with the tab active.
  2. Scan the tab strip: order is `draft · in-progress · closed · abandoned · all`. Each tab carries a small counter badge.
  3. Click each tab in turn — the URL gains `?status=<label>`, the list updates, the active-tab style moves.
  4. Run a stale-badge simulation (5 in-progress arcs render `stale`):
     ```
     cd /opt/999-Agentic-Engineering-Framework && FW_STALE_ARC_DAYS=0 bin/fw watchtower restart
     ```
     Reload `/arcs?status=in-progress` and look for the orange `stale` badges to the right of each arc name. Hover for tooltip.
  5. Restore the default threshold (badges should disappear):
     ```
     cd /opt/999-Agentic-Engineering-Framework && unset FW_STALE_ARC_DAYS && bin/fw watchtower restart
     ```
  **Expected:** Tab strip reads cleanly (no visual crowding, counters align with their labels), active tab is obviously highlighted, stale badge is visible but doesn't overwhelm the arc name. Click-through is snappy (page renders <500ms — confirmed at 27ms warm, 420ms cold).
  **If not:** Note which tab/badge feels off and reopen — both filter strip CSS and stale badge styling are cheap to iterate on.

## Verification

# T-1853 verification (scoped per L-291/L-393/L-387 — toolchain-free, no `grep -q` under pipefail).
python3 -c "import ast; ast.parse(open('web/blueprints/arcs.py').read())"
test "$(curl -sf -o /dev/null -w '%{http_code}' http://localhost:3000/arcs)" = "200"
test "$(curl -s http://localhost:3000/arcs | grep -c 'data-filter=')" -ge 5
test "$(curl -s http://localhost:3000/arcs | grep -c 'tab-count')" -ge 5
test "$(curl -s 'http://localhost:3000/arcs?status=draft' | grep -c 'data-filter=\"draft\"')" -ge 1
test "$(curl -s 'http://localhost:3000/arcs?status=abandoned' | grep -c 'data-filter=\"abandoned\"')" -ge 1
python3 -m pytest tests/playwright/test_arcs_lifecycle_tabs.py -q

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

### 2026-05-17 — perf incident discovered mid-slice: pre-existing `_scan_tasks_by_tag` × 5 ⇒ 10s page renders

- **What changed:** First Playwright run failed with `Page.goto: Timeout 15000ms exceeded`. RCA: the existing `_scan_tasks_by_tag` (pre-T-1853) was being called once per arc, each call doing `yaml.safe_load` over all 1841 task files. 5 arcs × 1841 parses = 9205 yaml-parses per `/arcs` request → ~10s response time. **This was a pre-existing bottleneck T-1853 inherited**, not a T-1853-introduced regression — but adding a per-arc `_arc_is_stale` git log made it visible.
- **Plan impact:** T-1853 had to absorb a perf-fix slice it didn't originally scope. Replaced both the legacy tag scan + the new stale check with a single batched scan (`_scan_tasks_by_arc_membership` returning `by_arc_id` + `by_tag`) that reads first 1KB of each task file via regex (no yaml-parse) once per 60s TTL window. Result: cold 420ms, warm 27ms (370× speedup).
- **Triggered:** No new task. The fix is contained in T-1853. Adjacent surfaces (`/tasks` at 6s baseline) carry similar latent issues — future perf-pass slice for `web/blueprints/tasks.py` if it surfaces again.

### 2026-05-17 — stale-check threshold derived from FW_STALE_ARC_DAYS (audit-side env var)

- **What changed:** Originally planned to read T-1855's existing audit data. Decided to recompute the same logic in Python instead — the audit writes a snapshot YAML, but the audit runs once per day; Watchtower needs the live answer. The arcs blueprint reads `FW_STALE_ARC_DAYS` from `os.environ` at module load (matches audit's bash-side default of 30). Lazy-loaded subprocess.run on `git log --since=N.days.ago --name-only` for the per-request batch, cached 60s.
- **Plan impact:** Removes the need for T-1853 to wait on a "publish audit snapshot to Watchtower" pipeline. Audit and Watchtower are independent consumers of the same git-history signal, each with their own freshness contract.
- **Triggered:** No new task. T-1857 doc update should explain the two-consumer model (audit = daily WARN, Watchtower = live badge).

### 2026-05-17 — Playwright race on `page.click()` + `page.url` read

- **What changed:** First click-test attempt used `with page.expect_navigation()` then `assert "status=closed" in page.url`. Still failed — the navigation event fired but the URL read happened before the URL property updated. Switched to `page.wait_for_url("**/arcs?status=closed", timeout=10_000)` — Playwright's idiomatic pattern for "wait until URL matches", separating intent from timing.
- **Plan impact:** None. Test pattern lock — future click-based Playwright tests in this codebase should prefer `wait_for_url` over `expect_navigation + page.url`.
- **Triggered:** No new task. Captured here so the next render-surface slice (T-1857-ish?) reuses the pattern.

## Decisions

### 2026-05-17 — server-side query-param filter (`?status=...`) vs client-side hide/show

- **Chose:** Server-side filter. Each tab is a plain `<a href="/arcs?status=X">` — the request returns only the matching arcs.
- **Why:** Watchtower has a session-cookie + SSR-only architecture; client-side JS state is intentionally rare. Server-side filter is grep-able in router code, debuggable from curl, and shareable via URL (the operator can bookmark `/arcs?status=closed`). Counter badges still reflect the full state count, not the filtered count.
- **Rejected:** Client-side hide/show via JS — would require Alpine/HTMX or an inline script, both alien to this codebase. Plus client-side filtering hides the URL-as-state pattern operators have come to expect on `/tasks`.

### 2026-05-17 — synthetic "all" tab as the 5th label

- **Chose:** Add an `all` tab at the right end of the strip — pass through `_filter_arcs` unchanged.
- **Why:** A 4-state lifecycle without an "all" escape hatch hides the corpus-wide view. Adding `all` is one extra label in a list (`_LIFECYCLE_STATES + ("all",)`) and one extra entry in `_state_counts` — trivial cost, big UX win for "show me everything regardless of state."
- **Rejected:** Default to "in-progress" only, hide all-view behind a "more" affordance — adds clicks for a non-edge use case.

### 2026-05-17 — first-1KB regex scan instead of yaml.safe_load per task

- **Chose:** `head = fh.read(1024)` + line-regex extraction of `id:`, `arc_id:`, `tags:` from task frontmatter. No yaml-parse for the batched scan.
- **Why:** Task frontmatter is *guaranteed* to live in the first ~512 bytes by template convention. Yaml parse over 1841 files cost ~10s; regex over the same files costs ~30ms. The regex doesn't validate YAML — but we don't need validation in a presentation-layer task-count, only field extraction. If a task frontmatter is malformed it doesn't show up under any arc — which is correct degraded behaviour.
- **Rejected:** ijson / streaming yaml-parser (over-engineered for frontmatter); read-once full-file + cache (memory bloat for 1841 markdown files); precompute index at watchtower startup (staleness within the same process).

### 2026-05-17 — sort order: in-progress → draft → closed → abandoned

- **Chose:** `status_rank = {"in-progress": 0, "draft": 1, "closed": 2, "abandoned": 3}`
- **Why:** Operator scanning the "all" tab sees active work first, then unstarted work (draft), then archived (closed/abandoned). Matches the order on the filter strip — predictable cognitive flow.
- **Rejected:** Alphabetical (`abandoned < closed < draft < in-progress` — wrong-end-first); recency-only (loses lifecycle grouping).

## Recommendation

**Recommendation:** GO

**Rationale:** T-1853 (T-NEW-5b) ships the operator-facing lifecycle view: `/arcs` now renders the full T-1852 four-state strip (draft, in-progress, closed, abandoned + "all") with counter badges and absorbs T-1855's stale signal as an inline orange badge. The arc-grooming arc closes the loop from CLI (T-1852/T-1854) to operator-visible status taxonomy on Watchtower.

All 6 Agent ACs satisfied + the perf incident discovered mid-slice has been remediated structurally:
- 6/6 Playwright tests (`test_arcs_lifecycle_tabs.py`) pass against the live Watchtower instance — DOM-content assertions per T-1575, not element-presence grep.
- Page renders cold 420ms / warm 27ms (down from 10s — 370× speedup) via batched membership scan replacing per-arc `_scan_tasks_by_tag`.
- Stale badge wire-traced live: `FW_STALE_ARC_DAYS=0` forces 5 in-progress arcs stale → 5 `badge-warn` spans render; revert to default 30 → 0 spans.

The slice absorbs T-1855's deferred AC #4 (stale badge on Watchtower) and unblocks T-1854's "Recently abandoned" surfacing (audit log file `.context/audits/arc-abandon.jsonl` is ready for a follow-up tab when needed).

**Evidence:**
- `web/blueprints/arcs.py` — `_LIFECYCLE_STATES`, `_filter_arcs`, `_state_counts`, `_arc_is_stale`, `_scan_tasks_by_arc_membership`, `_recent_task_paths` + perf cache wrappers.
- `web/templates/arcs_index.html` — `<ul class="arc-tabs" role="tablist">` + counter spans + per-state badge variants + stale-badge.
- `tests/playwright/test_arcs_lifecycle_tabs.py` → 6/6 PASSED in 12-17s wall.
- Live: `curl http://localhost:3000/arcs?status=draft | grep -c 'data-filter='` → 5 (4 lifecycle + "all" tab); same for `in-progress`, `closed`, `abandoned`, `all`. `?status=unknown` clamps to default in-progress.
- Perf: `time curl /arcs` → 0.42s cold, 0.027s warm.

**Follow-up (arc-grooming arc — final slice):**
- T-1857 (T-NEW-9) `012-ArcSystem.md` + `FRAMEWORK.md` updates: document the four-state lifecycle, `fw arc start|abandon` verbs, and the two-consumer freshness model (audit daily, Watchtower live). All structural prerequisites now shipped.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T14:53:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1853-watchtower-arcs-lifecycle-filter-tabs-t-.md
- **Context:** Initial task creation

### 2026-05-16T22:05:30Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ab64ffcd
- **Timestamp:** 2026-06-02T15:00:02Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Human)** — [REVIEW] Filter strip + stale badge fit Watchtower's visual rhythm and the operator finds the new surface intuitive
  - **review-link-homework** (partial, heuristic) — `homework-pattern='URL from `bin/fw watchtower url`'`
### 2026-05-16T22:26:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
