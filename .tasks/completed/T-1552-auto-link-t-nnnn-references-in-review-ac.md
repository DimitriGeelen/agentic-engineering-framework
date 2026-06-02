---
id: T-1552
name: "Auto-link T-NNNN references in /review AC steps to /tasks/T-NNNN"
description: >
  Auto-link T-NNNN references in /review AC steps to /tasks/T-NNNN

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-27T16:10:45Z
last_update: 2026-04-27T16:12:40Z
date_finished: 2026-04-27T16:12:40Z
---

# T-1552: Auto-link T-NNNN references in /review AC steps to /tasks/T-NNNN

## Context

T-1551 made Markdown render in /review/T-XXX AC steps. Existing 26 backlogged Human ACs don't have explicit Markdown links — they reference task IDs as plain text (`T-1448`). Auto-link those references to `/tasks/T-NNNN` so humans can click between related tasks without rewriting historical ACs.

## Acceptance Criteria

### Agent
- [x] `_auto_link_task_refs(text)` helper in `web/blueprints/tasks.py` rewrites bare `T-NNNN` tokens to Markdown links `[T-NNNN](/tasks/T-NNNN)`
- [x] Helper runs BEFORE markdown rendering (so the output goes through markdown2 normally)
- [x] Already-linked references are NOT double-linked (`[T-1448](xyz)` stays unchanged)
- [x] Tokens inside inline code (\`T-1448\`) are NOT linked (preserve developer intent)
- [x] Helper handles task IDs from T-1 to T-99999 (4–5 digit range covers full corpus)
- [x] Pytest unit tests in `tests/unit/test_review_markdown_render.py` cover: bare T-NNNN linkified; already-linked unchanged; inline-code unchanged; non-existent T-9999999 (too many digits) unchanged
- [x] All existing tests still pass

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
python3 -m pytest tests/unit/test_review_markdown_render.py -q
grep -q "_auto_link_task_refs" web/blueprints/tasks.py

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

### 2026-04-27T16:10:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1552-auto-link-t-nnnn-references-in-review-ac.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c40e6e83
- **Timestamp:** 2026-06-02T14:58:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T16:12:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
