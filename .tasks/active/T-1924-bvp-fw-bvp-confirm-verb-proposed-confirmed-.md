---
id: T-1924
name: "BVP T-NEW-8: fw bvp confirm verb — bvp_scores_proposed → bvp_scores (Sovereignty boundary, §ACD gated)"
description: >
  Moves estimator's proposed scores into confirmed bvp_scores with `confirmed_by:`/`confirmed_at:`. After confirm, estimator must never overwrite (M3 v2-delta semantics). §ACD agent-gate refuses under $CLAUDECODE=1.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-8, cli, sovereignty, acd-gate]
components: [lib/bvp.sh]
related_tasks: [T-1915, T-1916, T-1922, T-1671]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1924: BVP T-NEW-8 — `fw bvp confirm`

## Context

Sovereignty boundary (F7) — confirmation is the human's act. Once confirmed, scores are sticky; estimator never overwrites.

**Source:** Handoff §7 T-NEW-8; artefact §6 row 8; §4 D8 (sovereignty at policy/confirm time); §7 M3 (v2-delta), M6 (§ACD gate), M7 (CLI surface).

## Acceptance Criteria

### Agent
- [ ] `fw bvp confirm T-<id>` copies `bvp_scores_proposed:` into `bvp_scores:` with `confirmed_by:`, `confirmed_at:` fields
- [ ] `fw bvp confirm T-<id> --override D2=4` accepts proposed but overrides D2 to 4 in the confirmed write
- [ ] After confirm, running T-1922 worker on the same task does NOT overwrite `bvp_scores:` (verifies M3 sticky semantics)
- [ ] Refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (F7 + M6 — confirmation is Sovereignty)
- [ ] `bvp_scores_proposed:` block is cleared after confirm (next sweep can re-populate per M3)

## Verification

bin/fw bvp confirm --help 2>&1 | grep -q override
CLAUDECODE=1 bin/fw bvp confirm T-99999 2>&1 | grep -qiE "i-am-human|from-watchtower"

## Decisions

## Updates
