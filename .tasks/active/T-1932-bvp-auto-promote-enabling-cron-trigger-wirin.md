---
id: T-1932
name: "BVP T-NEW-14b: auto-promote enabling + cron/trigger wiring (split parent T-NEW-14)"
description: >
  Enabling-path via `fw bvp auto-promote --enable --rationale "..."` (§ACD-gated, per D8 sovereignty-at-policy-edit-time). Cron trigger registered. 30-day review reminder pre-staged per R7 mitigation.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-14b, cli, acd-gate, cron]
components: [lib/bvp.sh, .context/cron-registry.yaml]
related_tasks: [T-1915, T-1916, T-1931]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T13:54:43Z
date_finished: null
---

# T-1932: BVP T-NEW-14b — auto-promote enabling + cron wiring

## Context

Second split-child of T-NEW-14. Depends on T-1931 (logic + log must exist with default-off behavior proven).

**Source:** Handoff §7 T-NEW-14; artefact §6 row 16; §4 D8 (sovereignty at policy-edit); §2 R7 (escalation drift mitigation — 30-day review reminder).

## Acceptance Criteria

### Agent
- [ ] `fw bvp auto-promote --enable --rationale "..."` flips `auto_promote.enabled: true` in `policy/value-drivers.yaml` AND writes an enabling entry to `.context/bvp-auto-promote-log.yaml` (separate "enabling event" vs "promotion event" schema)
- [ ] Refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (D8 enabling is a sovereignty act, §ACD-gated)
- [ ] Refuses without `--rationale ≥30 chars`
- [ ] `fw bvp auto-promote --disable` symmetrically flips back to false (no rationale required — disabling is always safe)
- [ ] Cron entry registered in `.context/cron-registry.yaml` to invoke the auto-promote pass periodically (default: every hour)
- [ ] On `--enable`, a follow-up review task is auto-filed with `revisit_at: <today+30d>` (R7 mitigation — 30-day review reminder)
- [ ] `fw doctor` reports cron-registry-in-sync after the change

## Verification

grep -q "bvp.*auto-promote\|auto_promote" .context/cron-registry.yaml
bin/fw doctor 2>&1 | grep -q "Cron registry in sync"

## Decisions

## Updates

### 2026-05-19T13:54:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
