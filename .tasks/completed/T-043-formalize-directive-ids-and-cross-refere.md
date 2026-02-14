---
id: T-043
name: Formalize directive IDs and cross-references
description: >
  Create directives.yaml with formal D1-D4 IDs and last_reviewed dates. Add IDs (AD-001 through AD-012) to architectural decisions in 005-DesignDirectives.md. Add directives_served field to all entries in decisions.yaml. Design authority: 025-ArtifactDiscovery.md. Relevant sections: Q3 decision stores, Missing Cross-References, Directive IDs.
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T11:33:46Z
last_update: 2026-02-14T12:27:34Z
date_finished: 2026-02-14T12:27:34Z
---

# T-043: Formalize directive IDs and cross-references

## Design Record

**Design authority:** [025-ArtifactDiscovery.md](../../025-ArtifactDiscovery.md)
**Relevant sections:** Q3 Decision Stores, Missing Cross-References, Directive IDs

**Key decisions:**
- Directives get formal IDs in structured YAML (D1-D4) with `last_reviewed` field
- Architectural decisions in 005 get IDs (AD-001 through AD-012)
- Operational decisions in decisions.yaml get `directives_served` field
- No changelog for directives — git history suffices
- Web UI renders both stores as unified view with type labels

## Specification Record

### Acceptance Criteria
- [ ] `directives.yaml` created at `.context/project/directives.yaml` with D1-D4
- [ ] Each directive has: id, name, statement, last_reviewed
- [ ] 12 architectural decisions in 005-DesignDirectives.md have IDs (AD-001 through AD-012)
- [ ] All 8 entries in decisions.yaml have `directives_served: [D1, ...]` field
- [ ] Existing cross-references (episodic tags, practices derived_from) still work
- [ ] `fw audit` passes after changes

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T11:33:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-043-formalize-directive-ids-and-cross-refere.md
- **Context:** Initial task creation

### 2026-02-14T12:27:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-14T12:27:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
