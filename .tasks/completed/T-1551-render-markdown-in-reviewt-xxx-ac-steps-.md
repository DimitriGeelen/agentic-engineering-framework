---
id: T-1551
name: "Render Markdown in /review/T-XXX AC steps so artifact links become clickable (closes original T-1548 surface friction)"
description: >
  Render Markdown in /review/T-XXX AC steps so artifact links become clickable (closes original T-1548 surface friction)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-27T16:05:38Z
last_update: 2026-04-27T16:09:53Z
date_finished: 2026-04-27T16:09:53Z
---

# T-1551: Render Markdown in /review/T-XXX AC steps so artifact links become clickable (closes original T-1548 surface friction)

## Context

T-1548's triggering symptom: Human ACs on `/review/T-XXX` say "Open file X / read report Y / verify on page Z" — but the rendered Steps escape Markdown, so any `[label](url)` in the AC body shows up as literal text. The human is told what to look at but no clickable path is rendered. T-1550 fixed RCA capture (one root cause); this task fixes the rendering gap (the other root cause). Together they close the loop on the original friction.

`markdown2` is already used in `web/blueprints/{docs,inception,core}.py`; reuse it here.

## Acceptance Criteria

### Agent
- [x] `_parse_ac_body` (or its consumer) renders each `step` string through `markdown2.markdown(...)` before reaching the template
- [x] `expected` and `if_not` strings are also Markdown-rendered (same fix shape — links/code/emphasis work in all three fields)
- [x] `web/templates/_review_acs.html` outputs the rendered HTML via `| safe` (Jinja's autoescape is the current cause)
- [x] Markdown features that work after fix: `[label](url)`, inline `code`, `**bold**`, fenced code blocks (multi-line)
- [x] XSS guard: only inline-Markdown features rendered safe; raw `<script>`/`<iframe>` from AC bodies do NOT execute (markdown2 default `safe_mode` or explicit `extras=['safe']` if needed)
- [x] No regression in non-Markdown AC text — plain strings still render correctly
- [x] Playwright/curl regression test in `tests/playwright/` or `tests/unit/`: AC with `[Open report](docs/reports/T-1548-*.md)` step renders an `<a href=...>` element (not literal `[Open report]...`)
- [x] All existing review tests still pass

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
python3 -c "import markdown2; print('ok')"
test -f tests/unit/test_review_markdown_render.py
python3 -m pytest tests/unit/test_review_markdown_render.py -q
grep -q "markdown2" web/blueprints/tasks.py
grep -q "| safe" web/templates/_review_acs.html

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

### 2026-04-27T16:05:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1551-render-markdown-in-reviewt-xxx-ac-steps-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-06c73d2a
- **Timestamp:** 2026-06-02T14:58:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T16:09:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
