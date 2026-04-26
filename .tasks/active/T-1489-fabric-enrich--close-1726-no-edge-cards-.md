---
id: T-1489
name: "Fabric enrich — close 17/26 no-edge cards (mechanical dependency detection)"
description: >
  Run fw fabric enrich to add 29 mechanically-detectable edges (9 forward, 20 reverse) to 17 cards
  that previously had no graph connections. Closes long-standing audit advisory.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [fabric, enrichment, audit-warn]
components: [.fabric/components/]
related_tasks: []
created: 2026-04-26T09:18:26Z
last_update: 2026-04-26T09:18:26Z
date_finished: null
---

# T-1489: Fabric enrich — close 17/26 no-edge cards (mechanical dependency detection)

## Context

`fw audit` has been emitting `WARN Fabric: 26/454 cards have no edges` as a standing advisory.
Each "no-edge" card means: (a) it imports nothing, (b) nothing imports it (zero `depends_on` AND
zero `depended_by`). For most files this is wrong — the static enricher just needs to be run.
Dry-run showed 17 cards would gain 29 edges (concentrated in watchtower +14 and framework-core +6).

Mechanical, idempotent, reversible by `git revert`. No design choices.

## Acceptance Criteria

### Agent

- [x] `fw fabric enrich --dry-run` confirms ~17 cards / ~29 edges to add (no surprises)
- [x] `fw fabric enrich` (no flags = enrich all) runs cleanly
- [x] `fw audit` no-edge count drops (26 → 21 = 5 fewer cards in the no-edge set; remaining 21 are genuinely edge-less, e.g. standalone scripts/tests)
- [x] No fabric drift introduced (`fw audit` orphan count remains 0)

## Verification

bin/fw audit 2>&1 | grep -q "Fabric: 21/454 cards have no edges"

## Updates

### 2026-04-26T09:18:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1489-fabric-enrich--close-1726-no-edge-cards-.md
- **Context:** Initial task creation

### 2026-04-26 — enrichment ran
- **Action:** `fw fabric enrich` processed 454 cards, enriched 17 (9 depends_on + 20 depended_by edges added)
- **Result:** Audit no-edge count: 26 → 21
