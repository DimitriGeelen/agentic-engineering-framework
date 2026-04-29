---
id: T-1600
name: "Playwright interaction suite for review surfaces — click flows, forced-500 toast, mobile viewports"
description: >
  Extends tests/playwright/ with real interaction tests that DOM-grep can't cover: click GO/DEFER buttons end-to-end, force a 500 to verify the htmx error toast (T-1582 closure), inception decide flow (open/fill rationale/submit/verify), mobile viewport snapshots for /cockpit /approvals /review. Surfaced by T-1597 sweep where W1-W5 used curl+grep — closes the [REVIEW] subjective gap that grep can't reach.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-04-29T07:47:05Z
last_update: 2026-04-29T07:51:18Z
date_finished: null
---

# T-1600: Playwright interaction suite for review surfaces — click flows, forced-500 toast, mobile viewports

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] `tests/playwright/test_review_interaction.py` exists with click-flow tests for `/review/<id>` GO/DEFER/NO-GO buttons — each clicks the button, verifies success toast appears, verifies task transitions to expected state via API readback
- [ ] `tests/playwright/test_inception_decide_flow.py` exists covering the full inception decide journey: open `/approvals` → click inception card → fill rationale textarea → submit → assert success toast + decision recorded in task body
- [ ] `tests/playwright/test_htmx_error_toast.py` exercises the forced-500 path that T-1582 Steps couldn't easily reproduce — uses `page.route()` to intercept and return 500, asserts red toast renders with `htmx:responseError` handler firing (closes the [REVIEW] gap that grep proved insufficient for)
- [ ] `tests/playwright/test_mobile_viewport.py` runs `/cockpit`, `/approvals`, `/review/<id>` at 375x667 viewport — assertions: no horizontal overflow, Action Required card visible, verdict badges still distinguishable
- [ ] All new tests pass: `fw test playwright -- tests/playwright/test_review_interaction.py tests/playwright/test_inception_decide_flow.py tests/playwright/test_htmx_error_toast.py tests/playwright/test_mobile_viewport.py` exits 0
- [ ] No regression in existing playwright suite: `fw test playwright` exits 0

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

### 2026-04-29T07:47:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1600-playwright-interaction-suite-for-review-.md
- **Context:** Initial task creation

### 2026-04-29T07:51:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)
