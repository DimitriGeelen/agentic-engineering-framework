---
id: T-1655
name: "G-062 mechanism #1: Codify Arc Completion Discipline in CLAUDE.md — three-question checklist before declaring arcs 'shipped'"
description: >
  G-062 (high, score 16) tracks the framework-blindness pattern where agents declare arcs 'shipped' based on code/test artifacts without (a) end-to-end behavioral verification on fresh substrate, (b) policy-defaults audit, (c) framework-side use evidence. Three documented incidents in 5 weeks: T-1626, T-1633, T-1641. Mechanism #1 from the gap: add CLAUDE.md §Arc Completion Discipline section with explicit three-question checklist + 'no symptom-conflation' reminder. Closes the behavioral half of G-062; mechanisms #2 (fw audit arc-completion check) and #3 (fw task review extra gate) deferred.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [orchestrator, arc-c, governance, claude-md, framework-blindness]
components: [CLAUDE.md]
related_tasks: [T-1641, T-1644, T-1626, T-1633, T-1654]
arc_id: orchestrator-rethink
created: 2026-05-01T16:35:45Z
last_update: 2026-05-01T16:38:08Z
date_finished: 2026-05-01T16:38:08Z
---

# T-1655: G-062 mechanism #1: Codify Arc Completion Discipline in CLAUDE.md — three-question checklist before declaring arcs 'shipped'

## Context

G-062 is a high-severity gap (score 16, 3 incidents in 5 weeks) tracking the recurring failure where agents declare arcs "shipped" based on code/test artifacts without behavioral verification. The closure_criteria explicitly names this CLAUDE.md addition as mechanism #1. Doc-only change; no code or tests affected.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md contains a new section `## Arc Completion Discipline` (or similar) with the three explicit questions
- [x] Each question references its evidence (T-1626, T-1633, T-1641) so future agents see the pattern
- [x] Section includes the "no symptom-conflation" reminder
- [x] Section cross-references G-062 + G-019 (related but distinct gap)
- [x] G-062 status updated `watching` → `partial-mitigation` with mechanism #1 listed; remaining mechanisms (#2, #3) explicitly deferred

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

grep -q "## Arc Completion Discipline" CLAUDE.md
grep -q "T-1626" CLAUDE.md
grep -q "T-1633" CLAUDE.md
grep -q "T-1641" CLAUDE.md
grep -q "G-062" CLAUDE.md
grep -q "no symptom-conflation\|symptom conflation\|symptom-conflation" CLAUDE.md
grep -q "G-062" .context/project/concerns.yaml && grep -A 30 "id: G-062" .context/project/concerns.yaml | grep -q "partial-mitigation\|mechanism #1"

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

### 2026-05-01T16:35:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1655-g-062-mechanism-1-codify-arc-completion-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-4bd81cee
- **Timestamp:** 2026-05-01T16:38:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-01T16:38:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
