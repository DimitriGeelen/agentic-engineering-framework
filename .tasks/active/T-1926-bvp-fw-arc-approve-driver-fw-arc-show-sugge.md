---
id: T-1926
name: "BVP T-NEW-10: fw arc approve-driver + fw arc show-suggestions verbs (§ACD-gated, flips draft→in-progress, weight cap ≤6)"
description: >
  Two new arc verbs. approve-driver appends to scoped_drivers: (cap 3, M2 weight ≤6); on first approval flips draft→in-progress. --none --justification "..." also flips (≥30 char). §ACD agent-gate. show-suggestions renders proposed_scoped_drivers history per D7.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-10, cli, arc, acd-gate]
components: [lib/arc.sh, bin/fw, .context/audits/arc-scoped-driver-bypass.jsonl]
related_tasks: [T-1915, T-1916, T-1918, T-1925, T-1668, T-1671]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1926: BVP T-NEW-10 — `fw arc approve-driver` + `fw arc show-suggestions`

## Context

The driver-decision gate that flips arc draft→in-progress. §ACD shape from `fw arc close` reused (M6). Once this ships and human approves at least one driver (or `--none`), arc-006 itself can finally flip to in-progress.

**Source:** Handoff §7 T-NEW-10; artefact §6 row 10; §4 D5/D6/D7-reframe; §7 M2 (weight ≤6), M6 (§ACD gate), M7 (CLI surface).

## Acceptance Criteria

### Agent
- [ ] `fw arc approve-driver <arc> "<name>" [--weight N]` appends to `scoped_drivers:` (cap 3); on first approval also flips `status: draft → in-progress`
- [ ] Refuses (actionable error) when `scoped_drivers:` already has 3 entries
- [ ] Refuses `--weight N` for N > 6 (M2 scoped-driver weight cap)
- [ ] `fw arc approve-driver <arc> --none --justification "<≥30 chars>"` also flips status to in-progress AND writes to `.context/audits/arc-scoped-driver-bypass.jsonl` (arc_id, justification, ts)
- [ ] Refuses `--none` without `--justification` or with justification under 30 chars
- [ ] Refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (M6, §ACD)
- [ ] `fw arc show-suggestions <arc>` renders all entries in `proposed_scoped_drivers:` grouped by suggestion event timestamp (D7 — read-only, no mutations)

## Verification

bin/fw arc approve-driver --help 2>&1 | grep -q justification
bin/fw arc show-suggestions --help 2>&1 | grep -qi "proposed"
CLAUDECODE=1 bin/fw arc approve-driver test-arc-nonexistent "foo" 2>&1 | grep -qiE "i-am-human|from-watchtower"

## Decisions

## Updates
