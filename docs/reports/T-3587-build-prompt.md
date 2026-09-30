You are building T-3587 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). You have your own session-scoped focus (FW_SESSION_SCOPED_FOCUS=1); run `bin/fw work-on T-3587`. Follow CLAUDE.md.

Read .tasks/active/T-3587-*.md: its Context (the operator's words) and ### Agent criteria are the spec. The code:
- web/shared.py: render_markdown_safe, _auto_link_files, _build_artefact_path_re, VIEWABLE_DIR_PREFIXES, ROOT_FILES;
- web/blueprints/docs.py: the /file/<path> route and its allowlist 404, plus the /file template;
- web/blueprints/review.py, and every blueprint that renders Recommendation or Evidence;
- lib/review.sh (fw task review), for the URLs printed outside Watchtower.

Read the long T-3368 comments before touching _auto_link_files: the tag/text partitioning and the anchor-depth counter exist because of real bugs.

Another worker is building T-3586 in parallel, in the same checkout. It touches agents/task-create/update-task.sh, policy/review-backends.yaml, lib/review_cost*, agents/audit/audit.sh and CLAUDE.md. Do not edit those files. If you must touch CLAUDE.md, append a short paragraph and retry on conflict. If a git commit fails on index.lock, wait a few seconds and retry.

Rules:
- Stage by name only; commit messages start "T-3587: ".
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags. If a gate refuses, stop and report.
- After web/ edits: `bin/fw watchtower restart`, then `bin/fw watchtower current`. Then `bin/fw vendor self`, commit the vendored copies by name, and run `--check`.
- Measure live /review/T-3581 before and after (count linked vs unlinked path-shaped refs) and record it in the task.
- Tick each Agent criterion only when proven, EXCEPT the last (the independent render review, done by the parent). Leave the task in started-work.

Print only: commits, per criterion met or not (with the proving test), before/after counts, and anything unresolved.
