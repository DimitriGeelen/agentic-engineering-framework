---
id: T-1817
name: "Watchtower /arcs detail page misses tag-anchored tasks — _resolve_constituents
  has no tag-based fallback (T-1813 web-sibling)"
description: >
  Watchtower /arcs detail page misses tag-anchored tasks — _resolve_constituents has
  no tag-based fallback (T-1813 web-sibling)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: ["bug", "watchtower", "data-source-drift"]
components: [tests/unit/test_arcs_routes.py, web/blueprints/arcs.py]
related_tasks: ["T-1813", "T-1816"]
arc_id: dispatch-safety
created: 2026-05-13T20:46:24Z
last_update: '2026-08-16T22:24:45Z'
date_finished: 2026-05-13T20:52:36Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1817: Watchtower /arcs detail page misses tag-anchored tasks — _resolve_constituents has no tag-based fallback (T-1813 web-sibling)

## Context

Sibling fix to T-1813 (audit) and T-1816 (closure UI). Watchtower `/arcs/dispatch-safety` rendered 0 constituents in the Constituents table despite 10 tasks tagged `arc:dispatch-safety` (T-1805..T-1810, T-1812, T-1813, T-1815, T-1816). The arc YAML's `constituent_tasks: []` was the page's only source. Same data-source drift class T-1813 fixed in `agents/audit/audit.sh`: the source of truth for arc constituents is the `arc:<id>` tag scan, not the YAML's `constituent_tasks` field.

This is dispatch-safety arc closure-readiness sustainment: T-1816 made the page *reachable*; T-1817 makes the page *correct* so the human can see what they're closing.

## Acceptance Criteria

### Agent
- [x] `_resolve_constituents()` in `web/blueprints/arcs.py` merges YAML `constituent_tasks` ∪ tag-based scan (tasks tagged `arc:<arc_id>`) and dedupes by task id
- [x] `_list_arcs()` task_count reflects the merged count (not just `len(constituent_tasks)`)
- [x] Live `/arcs/dispatch-safety` page lists all 10 substrate tasks tagged `arc:dispatch-safety` (T-1805..T-1810, T-1812, T-1813, T-1815, T-1816) — pre-fix it showed 0 because `constituent_tasks: []` in the arc YAML
- [x] New unit tests `test_resolve_constituents_merges_tag_scan` + `test_list_arcs_task_count_uses_merged_source` in `tests/unit/test_arcs_routes.py` pin the merge behaviour
- [x] Existing `_list_arcs` and `_resolve_constituents` tests still pass (pytest -q)
- [x] Reviewer verdict on T-1817 returns PASS

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Unit test pins merge behaviour (python3 -m for sys.path = CWD)
python3 -m pytest -q tests/unit/test_arcs_routes.py
# Live page renders all tag-anchored substrate tasks
curl -sf "$(bin/fw watchtower url)/arcs/dispatch-safety" -o /tmp/t1817-detail.html
python3 -c "import re,sys; html=open('/tmp/t1817-detail.html').read(); tids=set(re.findall(r'/tasks/(T-\\d{3,5})', html)); needed={'T-1805','T-1806','T-1807','T-1808','T-1809','T-1810','T-1812','T-1813','T-1815','T-1816'}; missing=needed-tids; sys.exit(0 if not missing else (print(f'missing: {missing}'), 1)[1])"
# Page still reachable (T-1816 closure UI invariant)
curl -sf -o /dev/null -w "%{http_code}" "$(bin/fw watchtower url)/arcs/dispatch-safety" | grep -q "^200$"
# Bash + python syntax sanity
python3 -c "import ast; ast.parse(open('web/blueprints/arcs.py').read())"
# Reviewer verdict PASS
bin/fw reviewer T-1817 2>&1 | grep -q "Overall:.*PASS"

## RCA

**Symptom:** `/arcs/dispatch-safety` rendered 0 constituent tasks in the Constituents table despite 10 tasks being tagged `arc:dispatch-safety` (T-1805..T-1810, T-1812, T-1813, T-1815, T-1816). The page still appeared "populated" because the body text referenced T-1668 and T-1671 (in description/headline_mechanic), which masked the empty constituents table. Human about to close the arc would see no substrate evidence and either think the arc was empty or rely on out-of-band reasoning (audit output, task list).

**Root cause:** `_resolve_constituents()` (web/blueprints/arcs.py:141) reads exclusively from the YAML's `constituent_tasks` field. `_list_arcs()` (line 88) computes `task_count` from the same field. For this arc the field was empty (`constituent_tasks: []`) because the arc was filed *anchor-only* — tasks were added by `fw arc tag` over time, which should append to `constituent_tasks`, but on the dispatch-safety arc that append step was either skipped or rolled back. The canonical source for arc constituency is the `arc:<id>` tag scan (`lib/arc.sh:_arc_tasks_with_tag`) — `constituent_tasks` is a denormalised cache that becomes stale whenever tag-add bypasses the formal arc_tag verb.

**Why structurally allowed:** T-1813 fixed the same data-source drift in `agents/audit/audit.sh` (which previously also used `constituent_tasks` only). Three months later T-1816 restored the closure-UI but did not check whether the page's *contents* were correct, only that it loaded. Class L-329 sibling: one surface fixed, others left blind. No cross-surface parity test exists for arc-data-source resolution.

**Prevention:**
1. **Fix:** merge `constituent_tasks` ∪ tag-scan, dedupe by id, preserve legacy-first order.
2. **Test pin:** `test_resolve_constituents_merges_tag_scan` exercises a project where `constituent_tasks` and tag-scan disagree.
3. **Future cross-surface guard:** noted in Evolution — class-level parity test would compare audit, web detail, `fw arc show`, and CLI `_arc_tasks_with_tag` outputs for a given arc. Out of scope for this slice (one bug = one task).

## Evolution

### 2026-05-13 — discovered while flagging closure handoff

- **What changed:** Originally noted as "may render empty constituent list" in /resume suggestion. Live check confirmed worse: page renders 0/10 substrate tasks. Initial RCA-draft assumed 2/11 from legacy `constituent_tasks` (T-1668, T-1671) — fact-check during implementation showed `constituent_tasks: []` and the T-1668/T-1671 strings on the page were body-text references (in description/headline_mechanic), not table rows. The Constituents *table* was simply empty.
- **Plan impact:** None — same fix-class as T-1813 audit. Promoted from speculative to confirmed bug.
- **Triggered:** Class-level cross-surface parity test for arc data-source resolution noted as RCA Prevention #3. NOT filed as sibling — one-bug-one-task; recurrence (3rd surface) would justify it.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

- **Recommendation:** GO
- **Rationale:** Sibling fix to T-1813/T-1816 closes the last data-correctness gap in the dispatch-safety arc closure UI. Before this fix, `/arcs/dispatch-safety` showed 0 constituent tasks despite 10 being tagged — the human about to close the arc would have seen no substrate evidence. After this fix, all 10 substrate tasks (plus T-1817 itself = 11) appear in the constituents table and the index page count agrees.
- **Evidence:**
  - `pytest -q tests/unit/test_arcs_routes.py` → 11 passed (3 new tests added: merge, dedup, list-arcs count)
  - Live `/arcs/dispatch-safety` page now lists T-1805..T-1810, T-1812, T-1813, T-1815, T-1816, T-1817 (verified by regex extraction of `/tasks/T-NNNN` hrefs)
  - Live `/arcs` index shows "11 constituent" for dispatch-safety (was "0 constituent" pre-fix per `constituent_tasks: []`)
  - Watchtower `/arcs/dispatch-safety` returns HTTP 200 (T-1816 closure-UI invariant preserved)
  - Reviewer T-1817 verdict: **PASS**, no findings, needs_human=no
  - Same-class fix as T-1813 (audit data-source drift) — pattern is established framework practice

## Updates

### 2026-05-13T20:46:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1817-watchtower-arcs-detail-page-misses-tag-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-61a9ad5e
- **Timestamp:** 2026-06-02T14:59:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 7
     - evidence: `curl -sf -o /dev/null -w "%{http_code}" "$(bin/fw watchtower url)/arcs/dispatch-safety" | grep -q "^200$"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 11
     - evidence: `bin/fw reviewer T-1817 2>&1 | grep -q "Overall:.*PASS"`
### 2026-05-13T20:52:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
