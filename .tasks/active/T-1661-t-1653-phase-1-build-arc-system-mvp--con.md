---
id: T-1661
name: "T-1653 Phase 1 build: Arc system MVP — .context/arcs/<id>.yaml + bin/fw arc {create,focus,list,show,close,tag} + handover injection + Watchtower landing-page section + /tasks?arc= filter chip + migrate orchestrator-rethink arc"
description: >
  T-1653 GO'd Phase 1 (Watchtower 19:09:02). MVP scope per Recommendation: 1) data model .context/arcs/<id>.yaml with id/name/description/status/anchor_task/constituent_tasks/created/closed_at/decision; 2) bin/fw arc CLI 7 verbs (create/focus/list/show/close/tag); 3) tag namespace arc:<id> canonical, legacy from-T-XXXX as alias one release; 4) handover.sh adds Current Arc line, SessionStart resume picks up; 5) Watchtower landing-page Arcs in flight section + /tasks?arc=<id> filter chip; 6) migration: auto-create orchestrator-rethink arc from T-1641, seed constituent_tasks. ~4h. Out of scope: dedicated /arcs page (Phase 2), arc-specific CLAUDE.md snippets, multi-arc focus stack. Full design: docs/reports/T-1653-arcs-as-first-class.md.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [orchestrator, arc:orchestrator-rethink]
components: []
related_tasks: []
created: 2026-05-01T17:19:00Z
last_update: 2026-05-01T17:19:21Z
date_finished: null
---

# T-1661: T-1653 Phase 1 build: Arc system MVP — .context/arcs/<id>.yaml + bin/fw arc {create,focus,list,show,close,tag} + handover injection + Watchtower landing-page section + /tasks?arc= filter chip + migrate orchestrator-rethink arc

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

### 2026-05-01T17:19:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1661-t-1653-phase-1-build-arc-system-mvp--con.md
- **Context:** Initial task creation

### 2026-05-01T17:19:21Z — status-update [task-update-agent]
- **Change:** horizon: now → now
- **Change:** tags: +orchestrator,arc:orchestrator-rethink
