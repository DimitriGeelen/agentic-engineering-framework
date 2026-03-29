---
id: T-697
name: "Deep-dive: KCP (Knowledge Context Protocol) — Path C codebase ingestion"
description: >
  Path C deep-dive on github.com/Cantara/knowledge-context-protocol. T-487 researched the spec; this ingests the actual codebase under framework governance. Also serves as second Path C experiment validating the path-c-deep-dive.md template (T-696 GO).

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [path-c, deep-dive, external]
components: []
related_tasks: [T-487, T-477, T-696]
created: 2026-03-29T08:06:51Z
last_update: 2026-03-29T08:06:51Z
date_finished: null
---

# T-697: Deep-dive: KCP (Knowledge Context Protocol) — Path C codebase ingestion

## Problem Statement

T-487 researched the KCP spec (v0.10) and 289 CLI manifests as a document review. But we never ingested the actual codebase — the code structure, implementation patterns, test approach, and tooling decisions remain unexplored.

This deep-dive serves two purposes:
1. Extract value from the KCP codebase for the framework (T-477 governance declaration layer, manifest format patterns)
2. Validate the Path C template (T-696 GO) with a cold-start experiment on a real repo

**Source:** https://github.com/Cantara/knowledge-context-protocol
**Clone target:** /opt/052-KCP

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

- [ ] Verify TermLink installed: `fw termlink check`
- [ ] Clone target repo: `git clone https://github.com/Cantara/knowledge-context-protocol.git /opt/052-KCP`
- [ ] Spawn TermLink session: `termlink spawn --name kcp-dive --backend background --shell --wait --tags "path-c,deep-dive"`
- [ ] cd into target inside TermLink: `termlink interact kcp-dive "cd /opt/052-KCP && pwd" --json`
- [ ] Init framework governance: `termlink interact kcp-dive "bin/fw init --force" --json`
- [ ] Verify doctor passes: `termlink interact kcp-dive "bin/fw doctor" --json`
- [ ] Verify framework hooks in settings.json: `termlink interact kcp-dive "grep -c 'bin/fw hook' .claude/settings.json" --json`
- [ ] Confirm original hooks preserved: `termlink interact kcp-dive "ls -la .claude/settings.json.pre-fw" --json`
- [ ] Verify seed tasks created: `termlink interact kcp-dive "ls .tasks/active/" --json`

## Phase 2: Execute (INSIDE target project via TermLink)

- [ ] Dispatch worker or attach session inside target project
- [ ] Execute T-001: Orientation (read codebase, run doctor/audit)
- [ ] Execute T-002: First governed commit
- [ ] Execute T-003: Register key components in fabric
- [ ] Execute T-004: Complete task lifecycle (satisfied by T-001 through T-003)
- [ ] Execute T-005: Generate handover
- [ ] Execute T-006: Add project learning
- [ ] Run `fw doctor` — expect 0 failures
- [ ] Run `fw audit` — expect majority PASS

**Friction log:**

| # | Issue | Severity | Category | Notes |
|---|-------|----------|----------|-------|
| | | | | |

## Phase 3: Harvest (BACK in framework project)

- [ ] Read target project findings via TermLink
- [ ] Create research artifact: `docs/reports/T-697-kcp-deep-dive.md`
- [ ] Document architecture findings
- [ ] Document patterns worth extracting for T-477
- [ ] Create improvement tasks for friction points found
- [ ] Record learnings: `fw context add-learning "..." --task T-697`
- [ ] Cleanup TermLink session: `termlink signal kcp-dive SIGTERM && termlink clean`

## Acceptance Criteria

### Agent
- [ ] Phase 1 complete — framework governance initialized in KCP project
- [ ] Phase 2 complete — seed tasks executed, friction points logged
- [ ] Phase 3 complete — research artifact written, improvement tasks created
- [ ] Template validation — log where template helped vs. where it was insufficient
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review deep-dive findings and friction log
  **Steps:**
  1. Read `docs/reports/T-697-kcp-deep-dive.md`
  2. Evaluate friction points — are they framework issues or project-specific?
  3. Review improvement tasks created
  **Expected:** Findings are actionable, friction points are real, template worked cold
  **If not:** Note which findings need more investigation

## Go/No-Go Criteria

**GO if:**
- KCP codebase reveals patterns worth extracting (manifest format, CLI generation, federation)
- Framework onboarding worked end-to-end via template (seed tasks completed)
- Template was followable without tribal knowledge

**NO-GO if:**
- KCP codebase is too simple/thin to reveal useful patterns
- Framework governance incompatible with KCP project structure
- Template had major gaps requiring human intervention

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
