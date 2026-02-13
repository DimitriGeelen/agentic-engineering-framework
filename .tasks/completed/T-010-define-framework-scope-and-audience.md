---
id: T-010
name: Define framework scope and audience
description: >
  Answer: Who is this framework for? Individual developer? Team? Enterprise? The answer changes what success looks like. Document target users and use cases.
status: work-completed
workflow_type: specification
owner: human
priority: medium
tags: [meta, vision, scope]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T18:19:22Z
last_update: 2026-02-13T21:58:00Z
date_finished: null
---

# T-010: Define framework scope and audience

## Design Record

**Approach:** Define by analyzing what was actually built and who would benefit.

The framework emerged from solving a specific problem: Claude Code sessions losing context and repeating mistakes. This points toward a primary audience.

**Decision:** Start with narrowest viable audience and expand intentionally.

## Specification Record

Acceptance criteria:
- [x] Primary audience defined with clear persona
- [x] Secondary audiences identified with adaptation notes
- [x] Out-of-scope audiences explicitly named
- [x] Success criteria linked to audience needs
- [x] Use cases documented for primary audience

---

## Target Audience

### Primary: Individual Developer Using AI Agents

**Persona:** Solo developer or small team member who uses Claude Code (or similar AI coding assistants) for software development. Works on one project at a time. Needs to preserve context across sessions.

**Pain points:**
- AI sessions start fresh — same mistakes repeated
- No accountability for what AI did or why
- Hard to pick up where yesterday's session left off
- Learnings don't accumulate

**What they need:**
- Lightweight task tracking (not enterprise project management)
- Session handover that actually helps
- Git traceability without excessive ceremony
- A place for learnings to live

**Success looks like:**
- New session picks up context in < 1 minute
- Repeated mistakes captured and avoided
- Audit shows what happened and why
- Framework is faster than not using it

---

### Secondary: Small Team Sharing a Codebase

**Persona:** 2-5 developers working on shared repository, each using AI agents. Need to coordinate without heavy process.

**Adaptation notes:**
- Task ownership becomes important (who's working on what)
- Handovers serve human-to-human handoff, not just session continuity
- Patterns/learnings become team knowledge
- Git hooks enforce team standards, not just personal discipline

**What changes:**
- Task assignment matters
- Handover documents serve multiple readers
- Project memory is shared knowledge base

---

### Tertiary: Enterprise/Compliance Contexts

**Persona:** Organization needing audit trails for AI-assisted development. Regulatory requirements for traceability.

**Adaptation notes:**
- Enforcement tier model becomes critical
- Bypass logging serves compliance needs
- Audit agent serves external reviewers
- May need integration with enterprise tools (Jira, etc.)

**What changes:**
- Read-only audit access
- Export formats for compliance
- Stricter enforcement tiers
- Integration adapters

---

### Out of Scope

The framework is **NOT** designed for:

1. **Non-AI development workflows** — The overhead isn't justified without AI agent context loss
2. **Enterprise project management** — This isn't Jira. Use proper PPM tools for that.
3. **Multi-repo orchestration** — One repo, one framework instance
4. **Non-technical users** — Assumes command line comfort, git familiarity
5. **Real-time collaboration** — Not a multiplayer tool; turn-based by design

---

## Use Cases (Primary Audience)

### UC-1: Start New Session
**Actor:** Developer opening Claude Code
**Goal:** Pick up where last session left off
**Steps:**
1. Read `.context/handovers/LATEST.md`
2. Run `./agents/context/context.sh init`
3. Set focus: `./agents/context/context.sh focus T-XXX`
4. Begin work with full context

### UC-2: Create Task for New Work
**Actor:** Developer starting new feature/fix
**Goal:** Have work tracked and traceable
**Steps:**
1. Run `./agents/task-create/create-task.sh`
2. Fill in name, description, type
3. Optionally set status to started-work
4. Commit references task ID

### UC-3: Encounter and Resolve Error
**Actor:** Developer whose task hits issues
**Goal:** Fix issue and capture learning
**Steps:**
1. Set task status to `issues`
2. Run `./agents/healing/healing.sh diagnose T-XXX`
3. Apply suggested mitigation
4. Run `./agents/healing/healing.sh resolve T-XXX --mitigation "..."`
5. Task status back to `started-work` or `work-completed`

### UC-4: End Session Properly
**Actor:** Developer finishing work for the day
**Goal:** Next session can continue seamlessly
**Steps:**
1. Run `./agents/session-capture/AGENT.md` checklist
2. Run `./agents/handover/handover.sh --commit`
3. Verify handover document captures state

### UC-5: Check Framework Health
**Actor:** Developer wanting to verify compliance
**Goal:** Confirm everything is in order
**Steps:**
1. Run `./agents/audit/audit.sh`
2. Run `./metrics.sh`
3. Address any warnings

---

## Success Criteria by Audience

| Audience | Success Metric | Target |
|----------|---------------|--------|
| Individual | Time to resume session | < 1 minute |
| Individual | Repeated failures with same root cause | Decreasing |
| Individual | Git traceability | > 90% |
| Team | Handover comprehension (can another dev continue?) | Yes |
| Team | Shared pattern library growth | Increasing |
| Enterprise | Audit pass rate | 100% |
| Enterprise | Bypass rate with proper logging | < 5% |

---

## Test Files

N/A - this is a specification task

## Updates

### 2026-02-13T18:19:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-010-define-framework-scope-and-audience.md
- **Context:** Initial task creation

### 2026-02-13T21:58:00Z — scope-defined [claude-code]
- **Action:** Defined primary, secondary, tertiary audiences with clear personas
- **Output:** Primary (individual developer with AI agents), secondary (small team), tertiary (enterprise)
- **Key decision:** Start with narrowest viable audience, expand intentionally
- **Insight:** Framework overhead only justified when AI context loss is the problem
- **Context:** 5 use cases documented for primary audience
