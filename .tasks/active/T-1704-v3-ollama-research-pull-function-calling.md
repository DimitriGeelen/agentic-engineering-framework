---
id: T-1704
name: "v3 ollama-research: pull function-calling-tuned model (hermes-3:8b OR xlam:7b) and re-probe"
description: >
  T-1703 disproved that catalogue restriction rescues tool-use on generalist 8-10B models (0/18 across gemma4:8b, qwen3.5:9.7B). Failure mode is structural — models emit prose/code instead of tool_use JSON. v3: pull a function-calling-tuned model (hermes-3:8b or xlam:7b, both ≤5GB), add litellm alias, re-run tools/t1703-probe-matrix.sh with the new alias substituted in CELLS array. If ≥90% on simple-read: update ollama-research.yaml + T-1700 Recommendation. If not: file v4 inception (claude-code-router OR accept text-only narrow workflow). Predecessors: T-1700 (substrate), T-1703 (catalogue probe + L-347).

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [v3-prep]
components: []
related_tasks: []
created: 2026-05-03T19:58:50Z
last_update: 2026-05-03T19:59:02Z
date_finished: null
---

# T-1704: v3 ollama-research: pull function-calling-tuned model (hermes-3:8b OR xlam:7b) and re-probe

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

### 2026-05-03T19:58:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1704-v3-ollama-research-pull-function-calling.md
- **Context:** Initial task creation

### 2026-05-03T19:59:02Z — status-update [task-update-agent]
- **Change:** tags: +v3-prep
