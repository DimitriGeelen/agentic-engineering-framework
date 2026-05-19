---
id: T-1917
name: "BVP T-NEW-2: policy/value-drivers.yaml schema + initial content (D1-D4 weights 9/7/5/3, free-driver section, auto_promote off)"
description: >
  Create policy/ directory and policy/value-drivers.yaml with protected D1-D4 (weights 9/7/5/3), free_drivers: [], and auto_promote disabled by default. First slice of arc-006 BVP build (T-NEW-2 from HANDOFF-value-prioritisation-2026-05-15).

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-2, policy]
components: [policy/, policy/value-drivers.yaml]
related_tasks: [T-1915, T-1916]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1917: BVP T-NEW-2 — `policy/value-drivers.yaml` schema + initial content

## Context

First build slice of arc-006 (value-prioritisation). Creates the policy-as-code surface that subsequent slices (T-1918 schema, T-1920 mutating CLI, T-1931 auto-promote) all read from.

**Source:** `.context/handoffs/HANDOFF-value-prioritisation-2026-05-15.md` §7 T-NEW-2; `docs/reports/T-1915-bvp-inception.md` §6 row 1; §7 M1 (driver cap), M5 (auto-promote thresholds).

**Q1 default applied:** Free drivers globally visible (no campaign-scope mechanism); temporal scoping handled via weight-change pattern (D9).

## Acceptance Criteria

### Agent
- [ ] `policy/` directory exists at repo root
- [ ] `policy/value-drivers.yaml` exists with 4 protected entries: id=D1 weight=9 name=Antifragility, id=D2 weight=7 name=Reliability, id=D3 weight=5 name=Usability, id=D4 weight=3 name=Portability
- [ ] Each protected entry has a `protected: true` field (refuses `fw bvp driver --remove`)
- [ ] `free_drivers: []` with inline comment documenting cap=5 and weight-range 0-9 and "add-one-drop-one" behavior (M1)
- [ ] `auto_promote:` block with `enabled: false`, `bvp_norm_min: 0.85`, `cost_max: 1`, `max_concurrent: 1` (M5)
- [ ] Inline comment at top of file references this task, the handoff path, and the artefact path
- [ ] `fw audit` passes after the file is added (verifies A2 — audit YAML-parse accepts the new policy file)

## Verification

test -f policy/value-drivers.yaml
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); ids=sorted(p['id'] for p in d['protected_drivers']); assert ids==['D1','D2','D3','D4'], ids"
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); ws={p['id']:p['weight'] for p in d['protected_drivers']}; assert ws=={'D1':9,'D2':7,'D3':5,'D4':3}, ws"
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); ap=d['auto_promote']; assert ap['enabled'] is False and ap['bvp_norm_min']==0.85 and ap['cost_max']==1 and ap['max_concurrent']==1"
bin/fw audit 2>&1 | grep -E "FAIL.*value-drivers" && exit 1 || true

## Decisions

## Updates
