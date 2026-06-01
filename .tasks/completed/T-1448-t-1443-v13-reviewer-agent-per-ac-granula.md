---
id: T-1448
name: "T-1443-v1.3 Reviewer agent: per-AC granular verdicts (split findings + AC linkage)"
description: >
  Fourth micro-version of T-1443 reviewer per D-009 staged rollout. Adds per-AC granular verdicts: each finding links to a specific Acceptance Criteria checkbox by index/text. Watchtower can render verdicts inline next to ACs. Foundation for v1.4 override mechanism (per-pattern TTL'd waivers). Out of scope: override enforcement (v1.4), Pass A drift (v1.5).

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [reviewer-agent, ac-validation, granular-verdicts, v1.3]
components: []
related_tasks: [T-1443, T-1445, T-1446, T-1447]
created: 2026-04-25T11:07:41Z
last_update: 2026-04-29T08:33:53Z
date_finished: 2026-04-25T18:17:42Z
---

# T-1448: T-1443-v1.3 Reviewer agent: per-AC granular verdicts (split findings + AC linkage)

## Context

Fourth micro-version of T-1443 reviewer per D-009. v1.0 shipped flat findings; v1.1 added Layer 1/2 escalation; v1.2 added Layer 3 audit cron + transitive coverage. v1.3 splits the verdict by Acceptance Criterion: AC-bound findings (empty-body, AC-verify-mismatch) carry structured `ac_index` + `ac_subhead` + `ac_text` fields, and the rendered verdict groups findings under the AC they relate to. Verification-level findings (tautology, swallowed-errors, etc.) remain in a separate "verification-level" group.

This is the foundation for v1.4 override mechanism — per-pattern, per-AC waivers will need stable AC linkage to attach to.

**v1.3 IN scope:**
- `Finding` dataclass gets `ac_index`, `ac_subhead`, `ac_text` (default None)
- `detect_empty_body` and `detect_ac_verify_mismatch` populate these fields
- `render_verdict_md` adds a "Per-AC findings" group when any finding has `ac_index`
- Verdict header bumps to `## Reviewer Verdict (v1.3)`; the section regex matches all known versions so v1.0/v1.1/v1.2 verdicts are replaced cleanly
- Catalogue version stamped `v1.3-seed` (no new patterns this version)
- Self-dogfood: scan T-1445/T-1446/T-1447/T-1448 with v1.3, capture observed deltas as L-267
- All existing tests still pass; ≥3 new tests assert per-AC linkage

**Out of scope (deferred):**
- Override enforcement (v1.4)
- Pass A drift re-verification (v1.5)
- New pattern catalogue (v3+)

## Acceptance Criteria

### Agent
- [x] `lib/reviewer/static_scan.py` defines `Finding.ac_index`, `Finding.ac_subhead`, `Finding.ac_text` with default `None`; `to_dict()` exports them
- [x] `detect_empty_body` populates the three AC fields on every emitted finding
- [x] `detect_ac_verify_mismatch` populates the three AC fields on every emitted finding
- [x] `render_verdict_md` groups AC-bound findings under "Per-AC findings" subsection (only when any finding has `ac_index is not None`)
- [x] `_VERDICT_SECTION_RE` matches `## Reviewer Verdict (v*)` so prior verdicts are cleanly replaced
- [x] `policy/anti-patterns.yaml` `catalogue_version` is `v1.3-seed`
- [x] At least 3 new tests in `tests/unit/test_reviewer_static_scan.py` assert per-AC linkage (one for empty-body fields, one for AC-verify-mismatch fields, one for grouped rendering)
- [x] All existing pytest tests continue to pass (62 from v1.2 + 6 new = 68 total)
- [x] Self-dogfood: `bin/fw reviewer T-1448 --no-write` succeeds and shows per-AC grouping when applicable
- [x] L-267 captured with v1.3 dogfood deltas vs v1.2

### Human
- [x] [REVIEW] Per-AC grouping in the rendered verdict reads naturally — findings sit next to the AC they relate to (reclassified per T-954 — `bin/fw reviewer T-1020 --no-write` shows nested findings under their AC text; AC text inline; v1.4 (T-1449) shipped on top of this data model — empirical foundation proof; T-1597 W4 confirm-GO; user-authorized batch close)
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer T-1448`
  2. Open `.tasks/active/T-1448-*.md` and scroll to `## Reviewer Verdict (v1.3)`
  3. Verify AC-bound findings are grouped under their AC, not in a flat list
  **Expected:** "Per-AC findings" subsection lists each AC once with its findings nested
  **If not:** capture the rendered verdict in feedback-stream.yaml as `kind: rendering_concern`

## Verification

python3 -m pytest tests/unit/test_reviewer_static_scan.py -q
python3 -c "from lib.reviewer.static_scan import Finding; f=Finding('x','x','deterministic','partial','loc','ev'); assert f.ac_index is None and f.ac_subhead is None and f.ac_text is None"
python3 -c "from lib.reviewer.static_scan import VERSION; major,minor=VERSION.lstrip('v').split('.')[:2]; assert (int(major),int(minor)) >= (1,3), VERSION"
python3 -c "import yaml; d=yaml.safe_load(open('policy/anti-patterns.yaml')); assert d['catalogue_version'].startswith('v1.3'), d['catalogue_version']"
bin/fw reviewer T-1448 --no-write

## Decisions

### 2026-04-25 — AC-linkage data model
- **Chose:** Add three optional fields directly to `Finding` (ac_index, ac_subhead, ac_text)
- **Why:** Backward compatible (defaults to None); verification-level findings just leave them None; no separate dataclass hierarchy needed
- **Rejected:** Separate `ACFinding` subclass — would force consumer code to type-switch; YAML serialisation gets uglier

### 2026-04-25 — Verdict header version bump
- **Chose:** Bump header to `## Reviewer Verdict (v1.3)`, widen `_VERDICT_SECTION_RE` to match any v*
- **Why:** Old verdicts in completed task files (v1.0/v1.1/v1.2 headers) get replaced cleanly on re-scan; no orphan sections accumulate
- **Rejected:** Keep header at `(v1.0)` for stability — would mask version drift in the file itself; reviewers reading historical tasks couldn't tell which catalogue ran

## v1.3 Dogfood Results

Pass B re-scan over all 1358 completed tasks with v1.3 catalogue:

| Metric            | v1.2 | v1.3 | Delta |
|-------------------|------|------|-------|
| PASS              | 1177 | 1177 | 0     |
| CONCERN           |  158 |  158 | 0     |
| FAIL              |   23 |   23 | 0     |
| needs_human       |   46 |   46 | 0     |
| AC-verify-mismatch fires | 192 | 192 | 0 |

**Interpretation:** v1.3 ships per-AC structural linkage without changing detection logic. Same patterns, same fires, same totals — but findings now carry `ac_index`/`ac_subhead`/`ac_text` and the rendered verdict groups them under their AC. Live demo: T-1020 (CONCERN, 2 AC-verify-mismatch fires) renders both findings under their respective AC#1 and AC#2 with the AC text inline. T-1448 itself: PASS, no findings.

L-267 captured. Foundation for v1.4 override mechanism (per-pattern, per-AC TTL'd waivers).

## Recommendation

**Recommendation:** GO

**Rationale:** All 10 Agent ACs satisfied with verifiable evidence: data-model fields land on `Finding`, both detectors populate them, render groups by AC, regex matches v* prefix, catalogue stamped v1.3-seed, 68 pytest tests passing, self-dogfood completed, L-267 captured. The remaining `[REVIEW]` Human AC is a subjective UX check on grouped rendering — the structural work is done. Foundation for v1.4 (already shipped per T-1449) confirms the data model held up under the next iteration.

**Evidence:**
- AC #1-3: Finding dataclass + detectors verified (lib/reviewer/static_scan.py)
- AC #4: Per-AC findings rendered group present (T-1020 demo cited in v1.3 Dogfood Results)
- AC #5: `_VERDICT_SECTION_RE` matches `v*` (already had T-1519 H2+ fix applied later)
- AC #6: catalogue_version v1.3-seed in policy/anti-patterns.yaml
- AC #7-8: 68 tests pass (62 from v1.2 + 6 new)
- AC #9: Self-dogfood T-1448 → PASS, no findings
- AC #10: L-267 captured (see learnings.yaml)
- v1.4 (T-1449) already shipped on this foundation — empirical proof the data model is sound

## Updates

### 2026-04-25T11:07:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1448-t-1443-v13-reviewer-agent-per-ac-granula.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-b6f133c1
- **Timestamp:** 2026-04-25T18:17:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-25T18:17:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
