---
id: T-047
name: Timeline page with session narrative
description: >
  Build the timeline page and add session narrative generation to the handover process. (1) Modify handover.sh to generate a session_narrative field: 2-3 paragraph prose summary of session arc, connecting tasks to each other and the bigger picture. Stored in handover frontmatter or as new section. (2) Build /timeline page: sessions collapsed by default showing date + task count. Expand session (htmx hx-get) shows session_narrative prose + task list with component tags. Expand task shows episodic summary (outcomes, decisions, challenges). (3) Fallback for pre-feature handovers: stitch existing fragments (Where We Are + episodic summaries). Timeline is read-only. Data source: handover files + episodic files, computed on-the-fly. Design authority: 025-ArtifactDiscovery.md. Relevant sections: Q2 Timeline format, Q5 Timeline freshness, Three levels of progressive disclosure. Depends on: T-045 (web foundation).
status: captured
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T11:34:22Z
last_update: 2026-02-14T11:34:22Z
date_finished: null
---

# T-047: Timeline page with session narrative

## Design Record

**Design authority:** [025-ArtifactDiscovery.md](../../025-ArtifactDiscovery.md)
**Relevant sections:** Q2 Timeline format, Q5 Timeline freshness, Three levels of progressive disclosure

**Key decisions:**
- Three levels: collapsed sessions → expanded (narrative + task list) → expanded task (episodic detail)
- Session narratives generated at session end by handover process (Approach B)
- Stored as `session_narrative` field in handover frontmatter or new section
- Fallback for pre-feature handovers: stitch "Where We Are" + episodic summaries
- htmx partial loading for expand/collapse
- Read-only page, data computed on-the-fly from handovers + episodics
- No trigger needed for freshness — write-once artifacts

**Dependencies:** T-045 (web foundation)

## Specification Record

### Acceptance Criteria
- [ ] handover.sh generates `session_narrative` field (2-3 paragraph prose)
- [ ] /timeline shows all sessions, collapsed by default (date + task count)
- [ ] Click session → htmx loads narrative prose + task list with component tags
- [ ] Click task → htmx loads episodic summary (outcomes, decisions, challenges)
- [ ] Pre-feature handovers render fallback (stitched fragments)
- [ ] Page loads in <2s for 14 sessions (on-the-fly parsing)

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T11:34:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-047-timeline-page-with-session-narrative.md
- **Context:** Initial task creation
