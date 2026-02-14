# Task System — Agentic Engineering Framework

## Overview

The task is the **gravitational center** of the framework. Every action,
observation, decision, and artifact traces back to a task. The task log
is the primary substrate for self-learning, self-healing, and context
management.

**Core principle: Nothing gets done without a task.**

This is enforced structurally by the framework, not by agent discipline.

---

## Task Structure

Tasks are stored as **Markdown files with YAML frontmatter** — human-readable,
machine-parseable, git-syncable.

### Location

```
.tasks/
  active/
    T-042-add-oauth-to-auth-service.md
    T-043-fix-dns-resolution-timeout.md
  completed/
    T-039-setup-docker-registry.md
    T-040-implement-health-checks.md
  templates/
    default.md
```

### File Format

```markdown
---
id: T-042
name: Add OAuth to auth service
description: >
  Implement OAuth 2.0 authorization code flow for the auth service,
  replacing the current session-based authentication.
status: started-work
workflow_type: build
owner: human
priority: high
tags: [auth, security, api]
agents:
  primary: coder-agent
  supporting: [test-agent, reviewer-agent]
created: 2026-02-13T10:00:00Z
last_update: 2026-02-13T15:10:00Z
date_finished: null
---

# T-042: Add OAuth to auth service

## Design Record

[Inline or reference to design artifact]
The existing session store can be reused for token storage.
See [ADR-007](../docs/decisions/adr-007-oauth.md) for rationale.

## Specification Record

[Inline or reference to specification artifact]
- Must support authorization code flow
- Must support PKCE for public clients
- Token expiry: 1 hour access, 30 day refresh

## Test Files

- `tests/auth/oauth/oauth_flow.test.js`
- `tests/auth/oauth/token_refresh.test.js`

## Updates

### 2026-02-13 14:30 — scaffold-module [coder-agent]
- **Action:** Created module skeleton at `src/auth/oauth/`
- **Output:** 4 files created (handler, config, types, tests)
- **Context snapshot:** Initial scaffolding, no dependencies resolved yet

### 2026-02-13 14:45 — run-tests [test-agent]
- **Action:** Baseline test run
- **Output:** 12 tests, 12 passing, 0 failing
- **Artifact:** [test-log](./artifacts/T-042/test-run-001.log)

### 2026-02-13 15:10 — status-change: Issues [framework]
- **Reason:** Session middleware intercepts before OAuth callback handler
- **Error ref:** ERR-2026-0213-001
- **Healing loop:** Activated — suggested middleware reordering
- **Resolution:** Pending human review
```

---

## Task Fields Reference

### Frontmatter (Machine-Readable)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | yes | Unique identifier (e.g., T-042) |
| name | string | yes | Human-readable short name |
| description | string | yes | What this task accomplishes |
| status | enum | yes | Current lifecycle state (captured, started-work, issues, work-completed) |
| workflow_type | enum | yes | What kind of work this is |
| owner | string | yes | Who is accountable (human name or "agent") |
| created | datetime | yes | When task was captured |
| last_update | datetime | yes | Last modification timestamp |
| date_finished | datetime | no | When task reached completed status |

### Body Sections (Human & LLM Readable)

| Section | Purpose |
|---------|---------|
| Context | Design docs, specs, predecessor tasks — scope proportional to task size |
| Updates | Chronological log of every action taken on this task |

---

## Task Statuses (Lifecycle)

Four statuses, validated transitions. Simplified from the original six-status
model after evidence from 50 tasks showed that `refined` (0 uses) and `blocked`
(0 uses, `issues` covered all cases) were unnecessary.

```
                    ┌──────────┐
                    │ Captured │  Task identified, minimal detail
                    └────┬─────┘
                         │
                 ┌───────▼────────┐
                 │ Started Work   │  Active execution
                 └──┬──────────┬──┘
                    │          │
                    │    ┌─────▼──┐
                    │    │ Issues │  Problem or dependency encountered
                    │    └─────┬──┘
                    │          │  (resolved)
                    │◄─────────┘
                    │
                 ┌──▼─────────────┐
                 │ Work Completed │  Done, verified
                 └────────────────┘
```

**Status transitions and framework behavior:**

| Transition | Trigger | Framework Action |
|------------|---------|-----------------|
| → Captured | Human or agent identifies work | Create task file, minimal fields required |
| Captured → Started Work | Work begins | Framework activates task context |
| Started Work → Issues | Error or dependency problem | **Healing loop activates.** Classifies failure, suggests recovery. |
| Issues → Started Work | Problem resolved | Resolution logged, healing loop records pattern for learning |
| Started Work → Work Completed | All acceptance criteria met | Framework archives to `completed/`, captures episodic summary |

**Validated transitions** — `fw task update` enforces these transitions. Invalid
transitions (e.g., `captured` → `work-completed`) are rejected with an error.

---

## Workflow Types

The workflow type determines which part of the engineering process this
task belongs to, influencing agent selection and context strategy.

| Workflow Type | Purpose | Primary IEOAR Phase | Typical Primary Agent |
|---------------|---------|--------------------|-----------------------|
| Specification | Define what needs to be built | Intent | Specification Agent |
| Design | Determine how to build it | Intent → Execute | Design Agent |
| Build | Create the implementation | Execute | Coder Agent |
| Test | Verify correctness | Observe | Test Agent |
| Refactor | Improve existing implementation | Reflect → Adapt | Coder Agent |
| Decommission | Remove what's no longer needed | Adapt | Deployment Agent |

---

## Enforcement: The Four Tiers

The framework enforces task traceability through a tiered system.

### Tier 0 — Unconditional (ALWAYS requires task)

Actions classified as **consequential** — they change production state,
destroy resources, or modify security configurations. No bypass possible.

If a human attempts to bypass, the framework offers quick task creation
rather than blocking entirely.

Examples: deploy-to-production, delete-resource, modify-firewall-rules

### Tier 1 — Strict Default (requires task)

All standard operations require an active task context.
This is the default for every command unless configured otherwise.

If no task context exists, the framework blocks and offers:
1. Create a new task
2. Attach to an existing task
3. Request human bypass (escalates to Tier 2)

### Tier 2 — Situational Bypass (human-granted, per-instance)

A human can authorize a specific action without task context.
The authorization is:
- **Single-use** (next action requires task context again)
- **Logged** with: who authorized, when, why, what action
- **Auditable** in the untracked actions log

The agent MAY request a Tier 2 bypass. The human DECIDES.
The framework LOGS regardless.

For emergency situations (ITIL Emergency Change equivalent),
the framework creates a retroactive placeholder task:
"Untracked action at [time], authorized by [human]. Retrospective
documentation required."

### Tier 3 — Pre-Approved Exceptions (configured)

Certain action categories are pre-approved to run without task context.
These are documented in framework configuration with:
- Category name and description
- Rationale for pre-approval
- Approved by (human)
- Review date (pre-approvals should be periodically re-evaluated)

Examples: health checks, status queries, read-only diagnostics,
log inspection, environment info retrieval.

```yaml
# .context/enforcement-config.yaml
pre_approved_categories:
  - name: read-only-diagnostics
    description: "Non-mutating system inspection commands"
    commands: [system-health-check, docker-ps, git-status, env-info]
    rationale: "No state change, no traceability risk"
    approved_by: "human"
    approved_date: 2026-02-13
    review_date: 2026-05-13
```

### Authority Model

```
Human    →  SOVEREIGNTY  →  Can override anything, is accountable
Framework →  AUTHORITY   →  Enforces rules, checks gates, logs everything
Agent    →  INITIATIVE   →  Can propose, request, suggest — never decides
```

---

## Task-to-Agent Relationship

A single task can engage multiple agents with clear structure:

```
Task T-042 (Build: Add OAuth)
  ├── Primary: Coder Agent     (owns lifecycle, makes key decisions)
  ├── Supporting: Test Agent   (contributes test writing and execution)
  ├── Supporting: Reviewer Agent (reviews implementation)
  └── All agents log to the same task update history
```

The task's **workflow type** guides which agents are relevant.
The **primary agent** owns the task lifecycle (status transitions).
**Supporting agents** contribute capabilities but don't drive the task.

---

## Sync Model

Tasks live locally as files in `.tasks/` and sync via git:

```
Local working copy (.tasks/)
    │
    ├── git add / commit  →  Local git history
    │
    └── git push          →  Central repository
                              (GitHub, GitLab, bare repo, etc.)
```

This gives us:
- **Offline capability**: Work continues without network
- **Full history**: Git log = task evolution over time
- **Branching**: Tasks can live on feature branches alongside code
- **Merge**: Task updates from multiple contributors merge naturally
- **Portability (D4)**: No proprietary sync mechanism

---

## Integration with Context Fabric

The task system feeds directly into the three memory types:

| Memory Type | What Tasks Provide |
|-------------|-------------------|
| Working Memory | The currently active task(s) — status, recent updates, pending actions |
| Project Memory | Accumulated patterns across all tasks — common failure modes, effective approaches |
| Episodic Memory | Completed task histories — what worked, what failed, full narrative |

When a task moves to "Work Completed," the framework generates an
**episodic summary** — a condensed version of the task's journey
optimized for future reference by agents working on similar tasks.
