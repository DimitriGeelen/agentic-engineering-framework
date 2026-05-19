---
id: T-1920
name: "BVP T-NEW-5: fw bvp weight + fw bvp driver mutating verbs + weight history audit log (§ACD agent-gate)"
description: >
  Mutating CLI surface for BVP: change weights and add/remove free drivers. §ACD agent-gate (refuses under $CLAUDECODE=1, requires --rationale ≥30 chars). Reactive — weight changes re-rank live (D9). Add-one-drop-one rule (M1) enforced; protected D1-D4 cannot be removed.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-5, cli, acd-gate]
components: [lib/bvp.sh, .context/bvp-weight-history.yaml]
related_tasks: [T-1915, T-1916, T-1917, T-1919, T-1668, T-1671]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1920: BVP T-NEW-5 — `fw bvp weight` + `fw bvp driver` mutating verbs

## Context

Mutating BVP CLI. The §ACD gate shape from `fw arc close` (lib/arc.sh:430-468, T-1671 closure-decision agent-gate) is reused here.

**Source:** Handoff §7 T-NEW-5; artefact §6 row 4; §7 M1 (add-one-drop-one), M6 (§ACD gate), M7 (CLI surface).

**Q1 default applied:** Weight-change is how campaigns are expressed (no separate campaign-scope mechanism).

**R6 mitigation lands here:** ≥30-char rationale prevents thin weight-history entries.

## Acceptance Criteria

### Agent
- [ ] `fw bvp weight --set Dn=N --rationale "..."` writes append-only entry to `.context/bvp-weight-history.yaml` with timestamp, who, from-weight, to-weight, rationale
- [ ] `fw bvp weight` refuses (exit ≠0, actionable error) without `--rationale` flag
- [ ] `fw bvp weight` refuses rationale text under 30 characters
- [ ] `fw bvp weight` refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (§ACD)
- [ ] `fw bvp driver --add "name" --weight N` appends to `free_drivers:` in policy/value-drivers.yaml
- [ ] `fw bvp driver --add` refuses (with actionable error) when total drivers (4 protected + free) >= 9 unless `--drop <id>` is provided (M1)
- [ ] `fw bvp driver --remove D1` refuses (protected); same for D2/D3/D4
- [ ] Weight change is reactive: subsequent `fw bvp` reflects new weights immediately (D9)

## Verification

bin/fw bvp weight --set D2=8 2>&1 | grep -qi "rationale"  # refuses no rationale
bin/fw bvp weight --set D2=8 --rationale "too short" 2>&1 | grep -qi "30"  # refuses <30 chars
CLAUDECODE=1 bin/fw bvp weight --set D2=8 --rationale "test reason long enough to be valid for gate" 2>&1 | grep -qiE "i-am-human|from-watchtower"
bin/fw bvp driver --remove D1 2>&1 | grep -qi "protected"

## Decisions

## Updates
