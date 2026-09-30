You are continuing T-3587 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3587` (session-scoped focus). Follow CLAUDE.md.

The independent render review is AMBER: docs/reports/T-3587-render-review.md. Read it in full and fix GUIDANCE items 1 to 6:
1. MUST: source-viewer contrast. Pick the Pygments style by theme (light for light, github-dark for dark, scoped with [data-theme=...] .file-lines), or give `.file-lines pre` a matching background. Verify both themes.
2. MUST: no false "not found". Root files (001-Vision.md, 040-ValueDrivers.md, other numbered root docs) and dot-dir files (.claude/settings.json) that exist must resolve. The rule the operator cares about: a live ref must never look broken. When unsure, show plain text, never "dead". "Dead" only when you are certain the path does not exist.
3. SHOULD: generic filenames in template or explanatory prose (Cargo.toml, tsconfig.json, snake_case_name.md) must not be marked dead or linked to an unrelated file. Bare-filename resolution applies only to project-specific shapes (e.g. T-NNNN-*.md, or a unique basename in docs/reports/), not to generic toolchain names. Say in the task which rule you chose.
4. SHOULD: strip a leading `./`.
5. MINOR: no dead or ambiguous marks inside code (fenced blocks rendered as <p><code>, and inline code spans holding logs). Live links there are fine.
6. NOTE: add docs/adr/ and docs/runbooks/ to the shared allowlist if they exist.

Another worker (T-3586) runs in parallel. Do not edit agents/task-create/update-task.sh, policy/review-backends.yaml, lib/review_cost*, agents/audit/audit.sh or CLAUDE.md. Retry commits on index.lock.

Rules:
- Stage by name; commit messages start "T-3587: ".
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw watchtower restart`, then `current`; `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Add a test per item, with a control.
- Leave the render-review criterion unticked and the task in started-work.

Print only: commits, per item fixed or not, test counts.
