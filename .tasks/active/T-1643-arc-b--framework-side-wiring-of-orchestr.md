---
id: T-1643
name: "Arc B — Framework-side wiring of orchestrator substrate (T-1061 follow-up)"
description: >
  Make /opt/999 actually USE the substrate it built. W04 confirmed the framework has zero call-sites passing task_type or --model, builds no task-type:X tags, never reads model_used/fallback_used. Six discrete wirings: (1) fw termlink dispatch derives --task-type from active task workflow_type and tags worker; (2) tag long-lived specialist sessions task-type:X; (3) wire --model defaults via .framework.yaml + per-task-type overrides; (4) surface model_used/fallback_used in dispatch result manifest; (5) Watchtower /orchestrator panel subscribing to Governance frames 0x8; (6) update agents/dispatch/preamble.md. Co-arc with /opt/termlink-side hardening: gate the 71 ungated MCP mutators (W03), wire run_with_governance, ship best_model_for min-sample guard (Wilson lower-bound), add fw termlink route CLI verb, surface fallback/breaker state in route response, decide tenancy scope of route-cache, extend audit schema with route/breaker/governance fields. Blocked on Arc A (T-1642) policy decisions. Source: docs/reports/T-1641-worker-04-framework-usage.md, docs/reports/T-1641-worker-03-termlink-current-state.md.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [from-T-1641, t-1061-followup, wiring, orchestrator, termlink, framework-integration, arc:orchestrator-rethink]
components: []
related_tasks: [T-1641, T-1642, T-1063, T-1064, T-1065, T-1066]
created: 2026-05-01T11:54:52Z
last_update: 2026-05-01T18:57:17Z
date_finished: null
---

# T-1643: Arc B — Framework-side wiring of orchestrator substrate (T-1061 follow-up)

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

### 2026-05-01T11:54:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1643-arc-b--framework-side-wiring-of-orchestr.md
- **Context:** Initial task creation

### 2026-05-01T18:57:17Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
