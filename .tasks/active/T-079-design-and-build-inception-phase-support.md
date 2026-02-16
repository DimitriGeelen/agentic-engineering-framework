---
id: T-079
name: Design and build inception phase support
description: >
  Design and build inception phase support
status: started-work
workflow_type: specification
owner: agent
created: 2026-02-16T21:05:44Z
last_update: 2026-02-16T21:05:44Z
date_finished: null
---

# T-079: Design and build inception phase support

## Context

- Predecessor: T-072 audit identified lifecycle gaps
- Design reference: 030-WatchtowerDesign.md (Lifecycle Stages table, Stage 1: Inception)
- Cross-methodology research: Agile Inception Deck, Lean Canvas, Design Thinking, Shape Up, ADRs, Risk Storming, Spikes
- Framework archaeological analysis: T-001 through T-010 genesis, G-001 through G-006 gaps register

## Design Specification

### Problem Statement

The framework covers Planning through Evolution (stages 2-8) but has zero tooling for the Inception phase — the period where you identify what to build, surface assumptions, assess risks, and make go/no-go decisions. `fw init` creates folders but doesn't support the intellectual work of inception. Early tasks (T-001) pivoted mid-flight because assumptions were never made explicit. The gaps register (G-001-G-006) captures problems that should have been caught at inception.

### Five Universal Inception Concerns (from cross-methodology research)

1. **Problem Clarity** — What are we solving, for whom, and why now?
2. **Scope Fence** — What's explicitly in AND explicitly out?
3. **Risk/Assumption Awareness** — What could kill us? What do we believe but haven't tested?
4. **Trade-off Honesty** — What gives if we can't have everything?
5. **Transition Gate** — Are we ready to commit? Go/no-go decision point.

### Design Decisions

1. **`inception` = new workflow_type** — fits existing task lifecycle, no new statuses needed
2. **Assumptions in `.context/project/assumptions.yaml`** — separate from tasks, outlive inceptions
3. **No new agent** — template + CLI commands suffice
4. **Time-constrain inception** — template forces go/no-go criteria upfront
5. **No-go preserves learnings** — D1 Antifragility: abandoned projects are learning events

### CLI Architecture

```
fw inception start "Name"              # Create inception task + scaffold
fw inception status                    # Show active inception tasks
fw inception decide T-XXX go|no-go     # Record gate decision

fw assumption add "Statement" --task T  # Register assumption
fw assumption validate A-001            # Mark proven
fw assumption invalidate A-001          # Mark disproven
fw assumption list                      # Show by status
```

### New Files
- `.tasks/templates/inception.md` — inception task template
- `.context/project/assumptions.yaml` — assumptions register
- `lib/inception.sh` — inception CLI commands
- `lib/assumption.sh` — assumption CLI commands

### Modified Files
- `bin/fw` — routing for inception + assumption commands
- `agents/task-create/create-task.sh` — add inception to VALID_TYPES
- `agents/context/lib/episodic.sh` — inception-specific extraction
- `agents/handover/handover.sh` — inception summary section
- `CLAUDE.md` / `FRAMEWORK.md` — documentation

### Watchtower UI (future, not this task)
- Inception landing page (5-phase guided flow)
- Assumption tracker page under Knowledge nav
- Inception banner in ambient strip
- Decision gate UI
- Inception task cards (dashed border, purple badge)

### Acceptance Criteria
- [ ] `fw inception start "X"` creates inception task with proper template
- [ ] `fw inception status` lists active inception tasks
- [ ] `fw inception decide T-XXX go --rationale "..."` records decision and completes task
- [ ] `fw assumption add/validate/invalidate/list` full lifecycle works
- [ ] Episodic generation extracts inception decisions
- [ ] Handover shows pending inception tasks
- [ ] `fw audit` passes with no regressions
- [ ] `fw doctor` passes

## Updates

### 2026-02-16T21:05:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-079-design-and-build-inception-phase-support.md
- **Context:** Initial task creation
