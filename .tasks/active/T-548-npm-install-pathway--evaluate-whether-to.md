---
id: T-548
name: "npm install pathway — evaluate whether to build npm-based framework installation"
description: >
  Inception: npm install pathway — evaluate whether to build npm-based framework installation

status: started-work
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T11:10:41Z
last_update: 2026-03-27T17:34:07Z
date_finished: null
---

# T-548: npm install pathway — evaluate whether to build npm-based framework installation

## Problem Statement

Should the framework offer `npm install` as an installation pathway? The framework is bash + Python, not JavaScript, but T-586 GO on TypeScript adoption raises the question. Research artifact: `docs/reports/T-548-npm-install-pathway.md`.

## Assumptions

- A1: Node.js developers would benefit from npm-based installation (NOT VALIDATED — no user requests, no Node.js consumer projects)
- A2: npm packaging would be straightforward for a bash framework (INVALID — requires runtime dependency, complex packaging)
- A3: Dual install paths are maintainable (INVALID — two upgrade paths, two bug surfaces)

## Exploration Plan

1. Audit current installation methods (done — 4 methods exist)
2. Analyze npm packaging for non-JS CLI tools (done — wrong distribution channel)
3. Check user demand evidence (done — zero requests)

## Technical Constraints

- Framework is bash + Python, not JavaScript
- npm would add Node.js as a runtime dependency
- bin entries pointing to shell scripts require platform-specific handling

## Scope Fence

**IN:** Whether to add npm as an install pathway.
**OUT:** Changing existing install methods, npm for TermLink only.

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested (3 assumptions — 1 not validated, 2 invalid)
- [x] Go/No-Go decision made (NO-GO recommended)

## Go/No-Go Criteria

**GO if:** User demand exists AND Node.js runtime is already required AND dual-path maintenance is justified

**NO-GO if:** No user demand, framework is not JavaScript, runtime dependency is incoherent (all true)

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

### 2026-03-27T17:34:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next
