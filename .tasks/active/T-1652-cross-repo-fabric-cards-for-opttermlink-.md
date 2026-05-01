---
id: T-1652
name: "Cross-repo fabric cards for /opt/termlink orchestrator modules"
description: >
  W10 #8 — Component Fabric (483 cards, none for /opt/termlink orchestrator/router/fallback/governance-frame). Decide in this task: extend fabric to register cross-repo components (with a 'project: termlink' field) OR document explicitly that Fabric coverage stops at the framework boundary and provide an alternative pointer for orchestrator-arc components. Files to register if option A: termlink-orchestrator-router.yaml, -fallback.yaml, -governance-frame.yaml, -bypass-registry.yaml, -circuit-breaker.yaml. Origin: docs/reports/T-1641-worker-07-cross-arc.md + W10 item #8.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [from-T-1641, t-1061-followup, fabric, cross-repo]
components: []
related_tasks: [T-1641, T-1644, T-1064, T-1065, T-1066]
created: 2026-05-01T12:20:27Z
last_update: 2026-05-01T12:20:27Z
date_finished: null
---

# T-1648: Cross-repo fabric cards for /opt/termlink orchestrator modules

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
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

## Updates

### 2026-05-01T12:20:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1648-cross-repo-fabric-cards-for-opttermlink-.md
- **Context:** Initial task creation
