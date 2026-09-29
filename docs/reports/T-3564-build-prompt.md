You are building task T-3564 in the Agentic Engineering Framework repo at /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout; NO worktree). Focus is already set to T-3564 (status started-work). Read the task file first: .tasks/active/T-3564-arc-page-purpose-block-first-055-arc-007.md. Its ## Context and ## Acceptance Criteria (### Agent) are your spec. Follow CLAUDE.md.

## What to build
Reshape the arc detail page (web/templates/arc_detail.html, served by web/blueprints/arcs.py) to this order:
1. Arc title (existing).
2. A QUICK-LINK BAR as the very first element under the title: one in-page `<a href="#id">` per rendered section; every target id must exist; no rendered section without a link. Compact, wraps on narrow screens.
3. PURPOSE block: `purpose` and `objective` from the arc YAML (T-3563 story fields; see .context/arcs/continuous-run.yaml, readme-first-run.yaml, orchestrator-rethink.yaml). Omit cleanly (no empty box, no heading, no quick link) when absent.
4. TASK OVERVIEW: counts by status (e.g. 14 done / 2 in progress / 1 captured) plus the OPEN tasks as a short linked list. Before any BVP/report section. The full constituent table stays lower with its own anchor.
5. Story sections, each only when present, each with a stable anchor id: success criteria, context, decisions (with status), open questions, non-goals, history, evidence. Read the YAML shapes from the three arcs above.
6. Existing sections unchanged in behaviour, each anchored and linked: BVP signals (incl. scoped/proposed drivers), reports & evidence, constituent tasks, §Arc Completion Discipline check, arc closed.

Reference layout (for order and feel, not copy): 055's page http://192.168.10.107:3050/arcs/arc-007 (curl it). It has a Purpose block then a numbered dossier; it lacks quick links and puts tasks low. Ours must have quick links at the very top and tasks near the top.

## Constraints
- Match surrounding template idiom (Pico CSS, existing classes, htmx attributes: in-page anchors must NOT get hx-* attributes; plain href="#x").
- Put data shaping in the blueprint (a helper that returns an ordered list of {id, title} sections actually rendered), so the quick-link bar and the sections come from ONE list and cannot drift.
- Tests: add tests/web/test_t3564_arc_page_layout.py using the Flask test client: (a) arc with story fields (continuous-run): quick links present, every href="#x" has a matching id, every section heading id is linked, Purpose appears before Task overview, Task overview appears before BVP; (b) arc without story fields: no Purpose block, no empty story headings, quick links still valid. Run existing arc page tests too (grep tests/web for arc_detail / /arcs/).
- Stage files by name only; never git add -A. Commit with messages starting "T-3564: ". Do not use --no-verify, --force, or any FW_ALLOW_* / --skip-* flag.
- When the build is done: run `bin/fw watchtower restart`, then `bin/fw watchtower current`; run `bin/fw vendor self` then `bin/fw vendor self --check`; add the matching lines to the task's ## Verification; tick each Agent AC you satisfied EXCEPT the last one (the independent render review; the parent session does that). Do NOT set the task to work-completed.
- Write a short summary of what you did to docs/reports/T-3564-build-notes.md (files changed, test results, anything you could not do) and commit it.

When done, print only: commits made, test pass/fail counts, and anything unresolved.
