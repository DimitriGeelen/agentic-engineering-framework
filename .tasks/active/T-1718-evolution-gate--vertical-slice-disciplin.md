---
id: T-1718
name: "Evolution-gate + vertical-slice discipline for inception → build transitions"
description: >
  Structural mechanism that makes spec-vs-build drift visible during build. Surfaced from T-1717 Phase 3 grill (Q4) — 'understanding of what we need and want evolves with the process of materialisation'. Adds (a) mandatory ## Evolution section in build tasks populated at slice boundaries; (b) update-task.sh gate refusing slice-progress with empty Evolution log (same shape as T-1550 RCA gate); (c) vertical-slice discipline — smallest end-to-end deliverable before parallel streams; (d) fw inception revise affordance for mid-build pivots without abandoning the task. Prerequisite for T-1717 GO if approved. Sibling structural fix surfaced from T-1717 grill, not part of T-1717 scope.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [arc:embeddings-strategy, structural-gate, T-1716-family, dogfood-prerequisite, §ACD-prevention]
components: []
related_tasks: [T-1717, T-1550, T-1716, T-1671, T-1259, T-1260, G-062, G-066]
created: 2026-05-04T14:50:48Z
last_update: 2026-05-04T15:03:14Z
date_finished: null
---

# T-1718: Evolution-gate + vertical-slice discipline for inception → build transitions

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

### 2026-05-04T14:50:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1718-evolution-gate--vertical-slice-disciplin.md
- **Context:** Initial task creation

### 2026-05-04T15:03:14Z — status-update [task-update-agent]
- **Change:** tags: +arc:embeddings-strategy
