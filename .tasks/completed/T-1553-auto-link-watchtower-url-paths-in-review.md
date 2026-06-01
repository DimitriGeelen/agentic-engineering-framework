---
id: T-1553
name: "Auto-link Watchtower URL paths in /review AC steps (/approvals, /review/T-XXX, etc.)"
description: >
  Auto-link Watchtower URL paths in /review AC steps (/approvals, /review/T-XXX, etc.)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-27T16:16:20Z
last_update: 2026-04-27T16:18:44Z
date_finished: 2026-04-27T16:18:44Z
---

# T-1553: Auto-link Watchtower URL paths in /review AC steps (/approvals, /review/T-XXX, etc.)

## Context

Closes the auto-link loop alongside T-1552 (T-NNNN refs). AC steps that mention Watchtower paths (`/approvals`, `/review/T-1448`, `/inception`, etc.) should become clickable in /review/T-XXX without rewriting historical ACs. Whitelist of known blueprint routes — never auto-link arbitrary paths (would generate broken links).

## Acceptance Criteria

### Agent
- [x] `_auto_link_watchtower_paths(text)` helper in `web/blueprints/tasks.py` rewrites bare `/<blueprint>` and `/<blueprint>/<segment>` paths to Markdown links, where blueprint ∈ known set (approvals, review, tasks, inception, cron, fabric, discoveries, metrics, costs, gaps, reviewer, sessions, docs, audit, audits, fleet, enforcement, pending, prompts, quality, risks, settings, terminal, timeline, config, cockpit)
- [x] Helper runs before markdown rendering, after `_auto_link_task_refs`
- [x] Skips inline-code spans and already-linked paths (same skip rules as T-1552)
- [x] Pytest unit tests cover: bare `/approvals` linkified; `/review/T-1448` linkified (matches both `/review` and the trailing `/T-1448` task ref interaction); already-linked `[/approvals](xyz)` unchanged; inline-code `\`/approvals\`` unchanged; unknown path `/foobar` unchanged
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
grep -q "_auto_link_watchtower_paths" web/blueprints/tasks.py

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

### 2026-04-27T16:16:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1553-auto-link-watchtower-url-paths-in-review.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-2f7564ac
- **Timestamp:** 2026-04-27T16:18:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-27T16:18:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
