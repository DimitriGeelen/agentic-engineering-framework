You are an INDEPENDENT REVIEWER. You did not build this and owe its author nothing. EVALUATE, do not rubber-stamp. Verdicts: green (fine, say why) / amber (acceptable, name exactly what to improve) / red (not acceptable, what is needed) / escalate (a human must decide, why). Guidance is mandatory.

Repo: /opt/999-Agentic-Engineering-Framework. Read-only EXCEPT your one report file (below). Do not commit, do not run fw task verbs.

## What was built
Task T-3564 reshaped the arc detail page. Read the spec: .tasks/active/T-3564-arc-page-purpose-block-first-055-arc-007.md (## Context and ### Agent criteria), and the builder's notes: docs/reports/T-3564-build-notes.md. Code: web/templates/arc_detail.html, web/blueprints/arcs.py (helpers _arc_story, _task_overview, _arc_sections).

The operator's requirements, verbatim: the shape of 055's arc page, plus "I want a task overview more on the top. And I will add absolute tops quick links to the sections which should be anchors and I can quickly click through it."

## Evidence (open images with the Read tool)
- /tmp/playwright-mcp/review/arc-readme-top.png: our page, top (arc readme-first-run)
- /tmp/playwright-mcp/review/arc-readme-decisions.png: our page, scrolled to #decisions
- /tmp/playwright-mcp/review/arc-readme-bvp.png: our page, scrolled to #bvp-signals
- /tmp/playwright-mcp/review/ref-055-arc007-top.png: the reference page (055 arc-007), top
- Live pages: http://192.168.10.107:3002/arcs/readme-first-run (about 12s to load; a separate performance bug, T-3574, is filed and is NOT yours to judge) and the reference http://192.168.10.107:3050/arcs/arc-007
- Measured: 13 in-page links on our page, 0 dead.

## Judge
1. Is the quick-link bar at the very top, readable, and useful for jumping, as the operator asked?
2. Is the task overview near the top, and does it give a useful overview (not a wall)?
3. Does the Purpose block and the story section order read like 055's dossier in spirit (explains the arc to a cold reader), without copying its flaws (tasks low, no quick links)?
4. Anything that reads broken, duplicated, cluttered, or confusing (e.g. a duplicate link, empty sections, odd ordering)?
5. Does an arc WITHOUT story fields still render sensibly? Check http://192.168.10.107:3002/arcs/arc-grooming via curl (grep for the section ids).

Write your review to /opt/999-Agentic-Engineering-Framework/docs/reports/T-3564-render-review.md: VERDICT, WHAT I CHECKED, GUIDANCE (numbered, concrete, with the exact change). Then print only the verdict line and at most five guidance bullets.
