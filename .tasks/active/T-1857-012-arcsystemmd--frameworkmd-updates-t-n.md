---
id: T-1857
name: "012-ArcSystem.md + FRAMEWORK.md updates (T-NEW-9)"
description: >
  Write 012-ArcSystem.md at repo root mirroring 010-TaskSystem.md structure: Overview, Arc Structure (file format + lifecycle), Arc Fields Reference, Statuses (draft/in-progress/closed/abandoned), fw arc CLI, Relation to Tasks, Relation to Other Concepts (Inception, Horizon, Learnings, Directives, Component Fabric), D-Immutability. Update FRAMEWORK.md: glossary Arc entry, Quick Reference rows for fw arc create/abandon/close/focus/show, Arc System section paralleling Task System. Deps: T-NEW-1.5, T-NEW-2, T-NEW-3, T-NEW-5*, T-NEW-6 (doc describes post-refactor state).

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [build, arc:arc-grooming, documentation, canonical, T-NEW-9]
components: []
related_tasks: [T-1846, T-1847, T-1653]
created: 2026-05-15T14:53:22Z
last_update: 2026-05-15T14:53:22Z
date_finished: null
---

# T-1857: 012-ArcSystem.md + FRAMEWORK.md updates (T-NEW-9)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [ ] `012-ArcSystem.md` exists at repo root with sections: Overview, Arc Structure (file format + lifecycle), Arc Fields Reference, Statuses (draft/in-progress/closed/abandoned), `fw arc` CLI, Relation to Tasks, Relation to Other Concepts (Inception, Horizon, Learnings, Directives, Component Fabric), D-Immutability (full description of the invariant)
- [ ] `FRAMEWORK.md` glossary contains an `Arc` entry
- [ ] `FRAMEWORK.md` Quick Reference contains rows for: `fw arc create`, `fw arc abandon`, `fw arc close`, `fw arc focus`, `fw arc show`
- [ ] `FRAMEWORK.md` has Arc System section paralleling Task System (or links out to `012-ArcSystem.md` from a stub section)
- [ ] `grep -c -i 'arc' FRAMEWORK.md` returns > 5 (sanity check: doc density indicates first-class treatment)
- [ ] Content describes the post-refactor state (sequential IDs, four-state lifecycle, fw arc abandon, stale + anchor-task audit checks, arc_id task field with Tier-1 block)

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

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T14:53:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1857-012-arcsystemmd--frameworkmd-updates-t-n.md
- **Context:** Initial task creation
