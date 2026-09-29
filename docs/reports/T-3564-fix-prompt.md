You are continuing task T-3564 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree; focus is T-3564, status started-work). An independent reviewer returned AMBER on the arc page you (a previous worker) built. Read docs/reports/T-3564-render-review.md and apply GUIDANCE items 1 to 6 exactly as written:

1. Task overview: work-completed tasks still in active/ are "awaiting review", listed separately; open tasks = captured/started-work/issues, sorted issues, started-work, captured. Add the test it describes.
2. Cap both lists at 10 with a "+N more — full table" line.
3. Quick-link bar: choose option (a) sticky bar (with scroll-margin-top so headings do not land under it) and add the "Jump to:" label and contrasting background.
4. Linkify .tasks/(active|completed)/T-NNNN- source refs to /tasks/T-NNNN; add the test.
5. Anchor the scoped-drivers h3 (id="scoped-drivers") and add it to _arc_sections when scoped drivers exist.
6. Promote purpose as a headline (blockquote/strong), objective below as normal text.

Rules: match the surrounding idiom; the quick links and sections must still come from the ONE ordered list in the blueprint; in-page anchors get no hx-* attributes. Run tests/web/test_t3564_arc_page_layout.py plus the existing arc tests (test_arcs_routes, test_arc_display_helper, test_arcs_membership_cached, test_approvals_blocked_arcs). Stage by name, commit messages start "T-3564: ". No --no-verify, --force, FW_ALLOW_* or --skip-*. Then `bin/fw watchtower restart`, `bin/fw watchtower current`, `bin/fw vendor self`, `bin/fw vendor self --check`. Append a short "## Round 2" section to docs/reports/T-3564-build-notes.md (what changed, test counts) and commit it. Do NOT set the task to work-completed and do not tick the render-review AC.

Print only: commits, test pass/fail counts, anything unresolved.
