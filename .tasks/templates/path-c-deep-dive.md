---
id: T-XXX
name: "Deep-dive: {PROJECT_NAME} — external codebase ingestion and analysis"
description: >
  Path C deep-dive: Analyze {PROJECT_NAME} under framework governance.
  Clone, init, execute seed tasks, harvest findings.

status: captured
workflow_type: inception
owner: human
horizon: now
tags: [path-c, deep-dive]
components: []
related_tasks: []
created:
last_update:
date_finished: null
---

# T-XXX: Deep-dive: {PROJECT_NAME}

## Problem Statement

Analyze {PROJECT_NAME} under framework governance to:
- Understand architecture and patterns
- Extract reusable value for the framework
- Test framework onboarding on a real external codebase
- Identify friction points in the ingestion workflow

**Source:** {REPO_URL}
**Clone target:** /opt/{NNN}-{ProjectName}

### Directory numbering

Projects live in `/opt/NNN-ProjectName`. To find the next available number:
```bash
ls -d /opt/0*/ 2>/dev/null | sort
```
Pick the next unused number in the sequence.

## Key Rules

1. **Never cd into the target from framework session** — boundary hook blocks it (correctly)
2. **Never analyze target code from framework session** — pollutes context
3. **Always use TermLink for cross-project commands** — isolation by design
4. **TermLink session cd's INTO the consumer project** — that's the whole point
5. **Keep original project hooks** as `.pre-fw` — they're analysis artifacts
6. **Framework hooks must be applied** — governance even for analysis
7. **Human must approve** before any writes to external project (L-117 exception)
8. **Friction points become framework tasks** — the onboarding IS the test

## Phase 1: Setup (FROM framework project)

**Context:** Run these steps from within the framework project. Human approval required before any writes to external project.

- [ ] Pick next directory number: `ls -d /opt/0*/ 2>/dev/null | sort`
- [ ] Verify clone target doesn't exist: `test ! -d /opt/{NNN}-{ProjectName} && echo "OK"`
- [ ] Verify TermLink installed: `fw termlink check`
- [ ] Clone target repo: `git clone {REPO_URL} /opt/{NNN}-{ProjectName}`
- [ ] Spawn TermLink session: `termlink spawn --name {project}-dive --backend background --shell --wait --tags "path-c,deep-dive"`
- [ ] cd into target inside TermLink: `termlink interact {project}-dive "cd /opt/{NNN}-{ProjectName} && pwd" --json`
- [ ] Init framework governance: `termlink interact {project}-dive "bin/fw init --force" --json`
- [ ] Verify doctor passes: `termlink interact {project}-dive "bin/fw doctor" --json`
- [ ] Verify framework hooks in settings.json: `termlink interact {project}-dive "grep -c 'bin/fw hook' .claude/settings.json" --json`
- [ ] Confirm original hooks preserved: `termlink interact {project}-dive "ls -la .claude/settings.json.pre-fw" --json`
- [ ] Verify seed tasks created: `termlink interact {project}-dive "ls .tasks/active/" --json`

**Expected:** 6 seed tasks (T-001 through T-006), doctor shows 0 failures, framework hooks active.

## Phase 2: Execute (INSIDE target project via TermLink)

**Context:** Dispatch a Claude Code worker or use interactive TermLink session. The worker operates inside the target project — NOT from the framework.

- [ ] Dispatch worker or attach session inside target project
- [ ] Start mirror terminal for human observation: `termlink spawn --name {project}-mirror --backend tmux --shell --wait && termlink pty inject {project}-mirror "termlink attach {project}-worker" --enter` — human attaches via `termlink attach {project}-mirror`
- [ ] Execute T-001: Orientation (read codebase, run doctor/audit)
- [ ] Execute T-002: First governed commit
- [ ] Execute T-003: Register key components in fabric
- [ ] Execute T-004: Complete task lifecycle (satisfied by T-001 through T-003)
- [ ] Execute T-005: Generate handover
- [ ] Execute T-006: Add project learning
- [ ] Run `fw doctor` — expect 0 failures
- [ ] Run `fw audit` — expect majority PASS (warnings OK for fresh project)

**Friction log:** Record every issue encountered during seed task execution.

| # | Issue | Severity | Category | Notes |
|---|-------|----------|----------|-------|
| | | | | |

## Phase 3: Harvest (BACK in framework project)

**Context:** Return to the framework project. Read results via TermLink or bus.

- [ ] Read target project findings: `termlink interact {project}-dive "cat .context/handovers/LATEST.md" --json`
- [ ] Create research artifact: `docs/reports/T-XXX-{project}-deep-dive.md`
- [ ] Document architecture findings
- [ ] Document patterns worth extracting
- [ ] Create improvement tasks for friction points found
- [ ] Record learnings: `fw context add-learning "..." --task T-XXX`
- [ ] Cleanup TermLink session: `termlink signal {project}-dive SIGTERM && termlink clean`

## Acceptance Criteria

### Agent
- [ ] Phase 1 complete — framework governance initialized in target project
- [ ] Phase 2 complete — seed tasks executed, friction points logged
- [ ] Phase 3 complete — research artifact written, improvement tasks created
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review deep-dive findings and friction log
  **Steps:**
  1. Read `docs/reports/T-XXX-{project}-deep-dive.md`
  2. Evaluate friction points — are they framework issues or project-specific?
  3. Review improvement tasks created
  **Expected:** Findings are actionable, friction points are real, improvement tasks are well-scoped
  **If not:** Note which findings need more investigation

## Go/No-Go Criteria

**GO if:**
- Architecture findings are non-trivial (reveal patterns worth extracting)
- Friction points are documented and actionable
- Framework onboarding worked end-to-end (seed tasks completed)

**NO-GO if:**
- Target project is too simple to reveal useful patterns
- Framework governance fundamentally incompatible with target structure
- TermLink communication breaks down during execution

## Verification

# Phase 1 verification (run from framework project via TermLink)
# termlink interact {project}-dive "bin/fw doctor | tail -1" --json

## Decisions

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates
