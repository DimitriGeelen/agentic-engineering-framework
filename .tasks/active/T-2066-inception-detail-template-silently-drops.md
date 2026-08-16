---
id: T-2066
name: "inception detail template silently drops Context/RCA/AC/Verification/Decisions
  sections"
description: >
  web/blueprints/inception.py lists Context, RCA, Acceptance Criteria,
  Verification, Decisions in KNOWN_SECTIONS (which excludes them from
  extra_sections rendering) — but never maps them into the `sections`
  dict that inception_detail.html consumes. Net effect: silent drop.
  Any inception authored with bug-class RCA headings renders effectively
  empty. User hit this on T-2062..T-2065 batch ("all inception are empty").
status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: [bug, watchtower, inception, template, silent-drop, render-fidelity]
components: [web/blueprints/inception.py, web/templates/inception_detail.html]
related_tasks: [T-2062, T-2063, T-2064, T-2065, T-1177, T-1391, T-1585]
arc_id: watchtower-redesign
created: 2026-05-28T13:38:00Z
last_update: '2026-08-16T22:24:05Z'
date_finished: 2026-05-28T18:00:17Z
cost_estimate_proposed:
  - ts: '2026-05-28T13:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-28T13:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 5
      D3: 3
      D4: 0
    rationale: D1=1 (body:fix-without-learning); D2=5 
      (body:silent-class-removed); D3=3 (body:component-discoverability); D4=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 5
      D3: 3
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=5 
      (body:silent-class-removed); D3=3 (body:component-discoverability); D4=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-2066: inception_detail.html silently drops Context/RCA/AC/Verification/Decisions

## Problem Statement

The Watchtower `/inception/<id>` page rendered effectively empty for 4 inceptions filed earlier this session (T-2062..T-2065). User asked "all inception are empty !!! how is this possible".

**Root cause** (read confirms it): `web/blueprints/inception.py:339-345` lists these as `KNOWN_SECTIONS`:

```python
KNOWN_SECTIONS = {
    "Problem Statement", "Assumptions", "Exploration Plan",
    "Technical Constraints", "Scope Fence", "Go/No-Go Criteria",
    "Recommendation", "Structural Upgrade", "Decision", "Updates",
    "Acceptance Criteria", "Verification", "Decisions", "Context",
    "RCA",
}
```

The `extra_sections` loop at lines 366-373 skips every heading in this set:

```python
for heading, content in all_raw_sections.items():
    if heading in KNOWN_SECTIONS:
        continue
    ...
    extra_sections.append(...)
```

But the `sections` dict at lines 351-362 only populates render slots for the legacy inception subset:

```python
sections = {
    "problem": _md(all_raw_sections.get("Problem Statement", "")),
    "assumptions_text": _md(all_raw_sections.get("Assumptions", "")),
    "exploration": _md(all_raw_sections.get("Exploration Plan", "")),
    "constraints": _md(all_raw_sections.get("Technical Constraints", "")),
    "scope": _md(all_raw_sections.get("Scope Fence", "")),
    "criteria": _md(all_raw_sections.get("Go/No-Go Criteria", "")),
    "recommendation": _md(all_raw_sections.get("Recommendation", "")),
    "structural_upgrade": _md(all_raw_sections.get("Structural Upgrade", "")),
    "decision": _md(all_raw_sections.get("Decision", "")),
    "updates": _md(all_raw_sections.get("Updates", "")),
}
```

`Acceptance Criteria`, `Verification`, `Decisions`, `Context`, `RCA` are **listed as known but never assigned to a render slot**. They are trapped in dead code — recognised by the dedup filter, ignored by the renderer.

`inception_detail.html` references `sections.problem|assumptions_text|exploration|constraints|scope|criteria|recommendation|structural_upgrade|decision|updates` plus the `extra_sections` loop. Any inception body that uses Context/RCA/AC/Verification/Decisions headings renders only `## Updates`.

## Assumptions

- A1: The 5 trapped headings were added to KNOWN_SECTIONS in different commits — likely to suppress noise from generic-section rendering when an author included these headings under a different intent. The fix should not regress whatever that intent was. **To verify:** `git log -p` on `web/blueprints/inception.py` around the lines that added each heading.
- A2: The fix can be a one-screen change in `inception.py` — add render-slot mappings for the 5 dropped sections OR remove them from KNOWN_SECTIONS so they fall through to `extra_sections`. **Evidence:** the code surface is contained; no template changes required if we go the "fall through" route.
- A3: No regression in `inception_detail.html` rendering — the existing render slots for problem/exploration/scope/recommendation continue to work. **To verify:** existing T-1850-era inceptions still render correctly after fix.

## Exploration Plan

1. **Git-archaeology** (10 min) — `git log -p web/blueprints/inception.py | grep -A 5 'KNOWN_SECTIONS'` to identify when each of the 5 dropped headings was added and why.
2. **Decide the shape** (5 min) — pick between (a) add 5 render slots + 5 Jinja blocks, or (b) drop from KNOWN_SECTIONS so they fall through to `extra_sections`.
3. **Implement** (10 min) — write the chosen change.
4. **Regression case** (10 min) — pytest fixture that loads a known inception with Context/RCA/AC and asserts those sections appear in the rendered HTML.
5. **Re-render T-2062..T-2065 verification** — confirm the original bug-class bodies (if restored) would also render correctly.

## Technical Constraints

- The template `inception_detail.html` is shared across inceptions and is a public Watchtower surface — render changes are visible immediately to the user.
- The KNOWN_SECTIONS filter is also referenced by Reviewer Verdict block parsing (`startswith("Reviewer Verdict")` check) — must not break that.
- Render-surface gate P-013 applies (UI change → [REVIEW] Human AC).

## Scope Fence

**IN scope:**
- `web/blueprints/inception.py` KNOWN_SECTIONS + `sections` dict + `extra_sections` filter.
- `web/templates/inception_detail.html` Jinja blocks (if option (a) chosen).
- Pytest regression case in `tests/unit/` or `tests/integration/` pinning Context/RCA/AC presence.

**OUT of scope:**
- The author-side choice of which template to use when filing an inception (the immediate refile of T-2062..T-2065 already happened — bdf5ace5).
- The bug-class RCA template at `.tasks/templates/` (those are valid for `workflow_type: build|test|refactor` tasks).
- The `/tasks/T-XXX` view, which uses a different renderer.

## Acceptance Criteria

### Agent
- [x] Problem statement validated — read `web/blueprints/inception.py:339-373` confirms KNOWN_SECTIONS filter excludes 5 headings from `extra_sections` without mapping them into the `sections` dict; user hit it on T-2062..T-2065.
- [x] Assumptions enumerated — A1 (KNOWN_SECTIONS additions had original intent worth preserving), A2 (fix is one-file change), A3 (no regression on existing inceptions).
- [x] Candidates enumerated — (a) add render slots + Jinja blocks, (b) drop from KNOWN_SECTIONS so they fall through to `extra_sections`.
- [x] Recommendation written with evidence — GO option (a), rationale grounded in matching existing structural-render pattern (T-1177/T-1391/T-1585) over inconsistent bottom-of-page placement.

### Human
- [ ] [REVIEW] After fix, `/inception/T-2062` (and any inception with mixed-heading body) renders all populated sections — Context, RCA, Acceptance Criteria, Verification, Decisions show up if present.
  **Steps:**
  1. Open <http://192.168.10.107:3000/inception/T-2062> — confirm Problem Statement, Exploration Plan, Scope Fence, Recommendation all render (already true after bdf5ace5 refile).
  2. After T-2066 ships: revert one task to bug-class headings as a test, reload — confirm Context/RCA still render.
  3. Cross-check `/inception/<id>` of a pre-existing inception (e.g. T-1850, T-1442) — still renders correctly.
  **Expected:** All populated sections visible regardless of heading shape.
  **If not:** Note which sections are still missing and file sibling.

## Go/No-Go Criteria

**GO if:**
- Fix is contained to one file (`inception.py`) plus optional template changes.
- Regression case is a single pytest function.
- Cost-vs-benefit clear: removes a class of silent-drop bugs that confused a user in the wild.

**NO-GO if:**
- Git-archaeology reveals KNOWN_SECTIONS was load-bearing for a reason that conflicts with the obvious fix (then re-scope to preserve original intent).

**DEFER if:**
- The legacy inception template (Problem Statement / Exploration Plan / etc.) is the canonical shape and authors should never mix headings — then fix becomes "lint at filing time, render unchanged". Less invasive but more author-side friction.

## Verification

# Reproduce the silent-drop with a synthetic body (no fix shipped yet):
# curl -s http://192.168.10.107:3000/inception/T-2062 | grep -c "Context\|RCA\|Acceptance Criteria"
# After fix: expect >0 hits.

## Recommendation

**Recommendation:** GO — option (a) add render slots for Context / RCA / Acceptance Criteria / Verification / Decisions, plus matching Jinja blocks.

**Rationale:** The filter set (KNOWN_SECTIONS) exists to prevent generic-section duplication when the renderer has structural rendering of its own — e.g. Reviewer Verdict (T-1585) is rendered via a dedicated extractor + block. Adding the 5 dropped sections as proper render slots matches that pattern (deliberate placement in the page flow, not at the bottom under `extra_sections`). Option (b) — letting them fall through to `extra_sections` — works but yields inconsistent layout (RCA appearing as a generic card at the bottom instead of near the Problem Statement, where the user's eye expects it).

**Evidence:**
- The fix surface is bounded — one Python file, one template.
- Author-side friction observed in this very session: I filed 4 inceptions with bug-class headings because the RCA shape matched the user's request ("RCA + remediate"). The render-side accommodation closes the gap structurally instead of asking every author to remember the schema mismatch.
- Adjacent precedent: T-1177 / T-1391 / T-1585 each added structural rendering for specific section classes; T-2066 continues that pattern for the 5 dropped headings.

## Decisions

<!-- Filled when GO/NO-GO/DEFER chosen. -->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — option (a) add render slots for Context / RCA / Acceptance Criteria / Verification / Decisions, plus matching Jinja blocks.

Rationale: The filter set (KNOWN_SECTIONS) exists to prevent generic-section duplication when the renderer has structural rendering of its own — e.g. Reviewer Verdict (T-1585) is rendered via a dedicated extractor + block. Adding the 5 dropped sections as proper render slots matches that pattern (deliberate placement in the page flow, not at the bottom under `extra_sections`). Option (b) — letting them fall through to `extra_sections` — works but yields inconsistent layout (RCA appearing as a generic card at the bottom instead of near the Problem Statement, where the user's eye expects it).

Evidence:
- The fix surface is bounded — one Python file, one template.
- Author-side friction observed in this very session: I filed 4 inceptions with bug-class headings because the RCA shape matched the user's request ("RCA + remediate"). The render-side accommodation closes the gap structurally instead of asking every author to remember the schema mismatch.
- Adjacent precedent: T-1177 / T-1391 / T-1585 each added structural rendering for specific section classes; T-2066 continues that pattern for the 5 dropped headings.

**Date**: 2026-05-28T18:00:23Z

## Updates

### 2026-05-28T13:38:00Z — task-created
- **Action:** Filed via `fw inception start` after T-2062..T-2065 refile (bdf5ace5).
- **Trigger:** User reported "all inception are empty !!! how is this possible" — diagnosis traced silent drop to KNOWN_SECTIONS filter + missing render-slot mappings in `web/blueprints/inception.py`.
- **Sibling:** bdf5ace5 (T-2062..T-2065 author-side refile under canonical inception schema). This task is the structural fix so the silent-drop class can't recur.

### 2026-05-28T18:00:16Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — option (a) add render slots for Context / RCA / Acceptance Criteria / Verification / Decisions, plus matching Jinja blocks.

Rationale: The filter set (KNOWN_SECTIONS) exists to prevent generic-section duplication when the renderer has structural rendering of its own — e.g. Reviewer Verdict (T-1585) is rendered via a dedicated extractor + block. Adding the 5 dropped sections as proper render slots matches that pattern (deliberate placement in the page flow, not at the bottom under `extra_sections`). Option (b) — letting them fall through to `extra_sections` — works but yields inconsistent layout (RCA appearing as a generic card at the bottom instead of near the Problem Statement, where the user's eye expects it).

Evidence:
- The fix surface is bounded — one Python file, one template.
- Author-side friction observed in this very session: I filed 4 inceptions with bug-class headings because the RCA shape matched the user's request ("RCA + remediate"). The render-side accommodation closes the gap structurally instead of asking every author to remember the schema mismatch.
- Adjacent precedent: T-1177 / T-1391 / T-1585 each added structural rendering for specific section classes; T-2066 continues that pattern for the 5 dropped headings.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3e6c0d48
- **Timestamp:** 2026-05-28T18:00:17Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Problem statement validated — read `web/blueprints/inception.py:339-373` confirms KNOWN_SECTIONS filter excludes 5 headings from `extra_sections` without mapping them into the `sections` dict; user hi
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/inception.py in: Problem statement validated — read `web/blueprints/inception.py:339-373` confirms KNOWN_SECTIONS filter excludes 5 headings from `extra_sections` with`

### 2026-05-28T18:00:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-05-28T18:00:23Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — option (a) add render slots for Context / RCA / Acceptance Criteria / Verification / Decisions, plus matching Jinja blocks.

Rationale: The filter set (KNOWN_SECTIONS) exists to prevent generic-section duplication when the renderer has structural rendering of its own — e.g. Reviewer Verdict (T-1585) is rendered via a dedicated extractor + block. Adding the 5 dropped sections as proper render slots matches that pattern (deliberate placement in the page flow, not at the bottom under `extra_sections`). Option (b) — letting them fall through to `extra_sections` — works but yields inconsistent layout (RCA appearing as a generic card at the bottom instead of near the Problem Statement, where the user's eye expects it).

Evidence:
- The fix surface is bounded — one Python file, one template.
- Author-side friction observed in this very session: I filed 4 inceptions with bug-class headings because the RCA shape matched the user's request ("RCA + remediate"). The render-side accommodation closes the gap structurally instead of asking every author to remember the schema mismatch.
- Adjacent precedent: T-1177 / T-1391 / T-1585 each added structural rendering for specific section classes; T-2066 continues that pattern for the 5 dropped headings.
