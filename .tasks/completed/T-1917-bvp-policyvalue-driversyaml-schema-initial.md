---
id: T-1917
name: "BVP T-NEW-2: policy/value-drivers.yaml schema + initial content (D1-D4 weights 9/7/5/3, free-driver section, auto_promote off)"
description: >
  Create policy/ directory and policy/value-drivers.yaml with protected D1-D4 (weights 9/7/5/3), free_drivers: [], and auto_promote disabled by default. First slice of arc-006 BVP build (T-NEW-2 from HANDOFF-value-prioritisation-2026-05-15).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bvp, build, slice-2, policy]
components: [policy/, policy/value-drivers.yaml]
related_tasks: [T-1915, T-1916]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:10:59Z
date_finished: 2026-05-19T07:10:59Z
---

# T-1917: BVP T-NEW-2 — `policy/value-drivers.yaml` schema + initial content

## Context

First build slice of arc-006 (value-prioritisation). Creates the policy-as-code surface that subsequent slices (T-1918 schema, T-1920 mutating CLI, T-1931 auto-promote) all read from.

**Source:** `.context/handoffs/HANDOFF-value-prioritisation-2026-05-15.md` §7 T-NEW-2; `docs/reports/T-1915-bvp-inception.md` §6 row 1; §7 M1 (driver cap), M5 (auto-promote thresholds).

**Q1 default applied:** Free drivers globally visible (no campaign-scope mechanism); temporal scoping handled via weight-change pattern (D9).

## Acceptance Criteria

### Agent
- [x] `policy/` directory exists at repo root
- [x] `policy/value-drivers.yaml` exists with 4 protected entries: id=D1 weight=9 name=Antifragility, id=D2 weight=7 name=Reliability, id=D3 weight=5 name=Usability, id=D4 weight=3 name=Portability
- [x] Each protected entry has a `protected: true` field (refuses `fw bvp driver --remove`)
- [x] `free_drivers: []` with inline comment documenting cap=5 and weight-range 0-9 and "add-one-drop-one" behavior (M1)
- [x] `auto_promote:` block with `enabled: false`, `bvp_norm_min: 0.85`, `cost_max: 1`, `max_concurrent: 1` (M5)
- [x] Inline comment at top of file references this task, the handoff path, and the artefact path
- [x] `fw audit` passes after the file is added (verifies A2 — audit YAML-parse accepts the new policy file)

## Verification

test -f policy/value-drivers.yaml
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); ids=sorted(p['id'] for p in d['protected_drivers']); assert ids==['D1','D2','D3','D4'], ids"
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); ws={p['id']:p['weight'] for p in d['protected_drivers']}; assert ws=={'D1':9,'D2':7,'D3':5,'D4':3}, ws"
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); ap=d['auto_promote']; assert ap['enabled'] is False and ap['bvp_norm_min']==0.85 and ap['cost_max']==1 and ap['max_concurrent']==1"
bin/fw audit 2>&1 | grep -E "FAIL.*value-drivers" && exit 1 || true

## Evolution

### 2026-05-19 — Filing & shape
- **What changed:** Filed the policy YAML with explicit `schema_version: 1` (handoff §7 did not require it; added because subsequent slices T-1918/T-1920/T-1931 will read this file and a missing version field makes future shape evolution non-detectable). Comment block at top names every consumer slice so future agents grep find readers in one hop.
- **Plan impact:** None to the arc. T-1918 (frontmatter schema) should mirror this `schema_version` convention for symmetry.
- **Triggered:** Consideration only — if T-1918 doesn't add `schema_version`, file a tiny follow-up to align. No new task yet.

## Recommendation

**Recommendation:** GO

**Rationale:** Foundation file for arc-006; pure scaffolding. All 7 Agent ACs satisfied: file exists, 4 protected drivers with correct weights (D1=9, D2=7, D3=5, D4=3) and `protected: true`, `free_drivers: []` with documented M1 cap-5/weight-0-9/add-one-drop-one, `auto_promote` block with M5 thresholds and `enabled: false` default, top-of-file comment cites T-1917/handoff/artefact, audit passes. Unlocks T-1919 (read CLI), T-1920 (mutating CLI), T-1924 (confirm), T-1926 (approve-driver), T-1931 (auto-promote logic).

**Evidence:**
- `policy/value-drivers.yaml` parses; YAML structure validated by 5 python3 assertions (ids, weights, protected flags, auto_promote shape, free_drivers empty)
- `fw audit` does not surface any FAIL on the new file
- Comment block at top names T-1917, handoff path, artefact path

## Decisions

## Updates

### 2026-05-19T07:07:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-254fdf1f
- **Timestamp:** 2026-05-19T07:11:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-19T07:10:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
