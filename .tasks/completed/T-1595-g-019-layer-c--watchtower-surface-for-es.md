---
id: T-1595
name: "G-019 Layer C — Watchtower surface for escalation drift findings"
description: >
  G-019 Layer C — Watchtower surface for escalation drift findings

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [web/blueprints/escalation.py, web/blueprints/__init__.py, 
      web/shared.py, web/templates/escalation_drift.html]
related_tasks: []
created: 2026-04-28T22:22:35Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-28T22:27:25Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1595: G-019 Layer C — Watchtower surface for escalation drift findings

## Context

G-019 Layer C — surface the escalation-drift scan findings in Watchtower so they are visible to humans (not just buried in a YAML file). T-1555 ships Layer B: the daily `escalation-drift-daily` cron writes machine-readable summary to `.context/working/escalation-drift-LATEST.yaml`. Currently nothing renders this. Layer C closes the gap: a read-only Watchtower page at `/escalation-drift` showing corpus totals, per-heuristic breakdowns (H1=no RCA, H2=repeat learnings, H3=no RCA + no learning), top repeating patterns, and the 30-day flagged sample with task links.

## Acceptance Criteria

### Agent
- [x] New blueprint `web/blueprints/escalation.py` with route `/escalation-drift` that loads `.context/working/escalation-drift-LATEST.yaml` and passes parsed dict to template
- [x] Template `web/templates/escalation_drift.html` renders: corpus totals, H1/H2/H3 counts + percentages, top-10 repeat patterns with task counts, recent_30d_flagged sample as clickable list to `/tasks/T-XXX`
- [x] Blueprint registered in `web/blueprints/__init__.py`
- [x] Page returns HTTP 200 with key panels visible — verified `curl /escalation-drift | grep "316"` shows H1 count
- [x] Handles missing YAML file gracefully (placeholder message, no 500) — pytest `test_escalation_drift_missing_yaml`
- [x] Empty/malformed YAML handled (placeholder, no 500) — pytest `test_escalation_drift_corrupt_yaml`
- [x] Navigation entry added to base navbar so the page is reachable — `Govern` group in `web/shared.py:NAV_GROUPS`
- [x] Component fabric registered for new files — `.fabric/components/web-blueprints-escalation.yaml` + `web-templates-escalation_drift.yaml`
- [x] All bats unit tests pass after change (existing safety net) — `test_mirror_sync.bats` 8/8

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

# Files exist
test -f web/blueprints/escalation.py
test -f web/templates/escalation_drift.html
# Blueprint registered
grep -q "escalation" web/blueprints/__init__.py
# Page returns 200 and contains the headline metrics
curl -sf "$(bin/fw watchtower url)/escalation-drift" | grep -q "Escalation Drift"
curl -sf "$(bin/fw watchtower url)/escalation-drift" | grep -qE "H1|Heuristic"
# Existing tests still pass
bash -c 'out=$(bin/fw test unit -- tests/unit/test_mirror_sync.bats 2>&1); ! echo "$out" | grep -q "^not ok" && [ "$(echo "$out" | grep -cE "^ok ")" -eq 8 ]'

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

**Rationale:** All 9 Agent ACs satisfied. G-019 escalation drift findings are now visible at `/escalation-drift` instead of buried in `.context/working/escalation-drift-LATEST.yaml`. The page renders the corpus totals (1487 scanned, 323 bug-class), per-heuristic breakdowns (H1 316/97%, H2 50, H3 262/81%), top-15 repeating learning IDs with task counts, and the recent flagged sample with clickable task links. Failure-mode tests cover both missing-YAML and corrupt-YAML cases — the page returns 200 with the placeholder panel either way. Closes Layer C of G-019. Layer D (real-time pre-completion prompt) remains.

**Evidence:**
- `curl http://localhost:3000/escalation-drift` → 200, all expected metrics rendered
- `curl http://localhost:3000/` | grep "Escalation Drift" → nav link present (Govern group)
- pytest `web/test_app.py -k escalation` → 4/4 pass (route 200 + missing + corrupt + module import)
- Fabric cards created for `web/blueprints/escalation.py` and `web/templates/escalation_drift.html`

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-28T22:22:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1595-g-019-layer-c--watchtower-surface-for-es.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b1cd78cc
- **Timestamp:** 2026-06-02T14:58:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 6

**Per-AC findings:**

- **AC#1 (Agent)** — New blueprint `web/blueprints/escalation.py` with route `/escalation-drift` that loads `.context/working/escalation-drift-LATEST.yaml` and passes parsed dict to template
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/working/escalation-drift-LATEST.yaml in: New blueprint `web/blueprints/escalation.py` with route `/escalation-drift` that loads `.context/working/escalation-drift-LATEST.yaml` and passes pars`
- **AC#7 (Agent)** — Navigation entry added to base navbar so the page is reachable — `Govern` group in `web/shared.py:NAV_GROUPS`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/shared.py in: Navigation entry added to base navbar so the page is reachable — `Govern` group in `web/shared.py:NAV_GROUPS``
- **AC#8 (Agent)** — Component fabric registered for new files — `.fabric/components/web-blueprints-escalation.yaml` + `web-templates-escalation_drift.yaml`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/web-blueprints-escalation.yaml in: Component fabric registered for new files — `.fabric/components/web-blueprints-escalation.yaml` + `web-templates-escalation_drift.yaml``

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 7
     - evidence: `curl -sf "$(bin/fw watchtower url)/escalation-drift" | grep -q "Escalation Drift"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `curl -sf "$(bin/fw watchtower url)/escalation-drift" | grep -qE "H1|Heuristic"`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `bash -c 'out=$(bin/fw test unit -- tests/unit/test_mirror_sync.bats 2>&1); ! echo "$out" | grep -q "^not ok" && [ "$(echo "$out" | grep -cE "^ok ")" -eq 8 ]'`
### 2026-04-28T22:27:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
