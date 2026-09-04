# worker-commits

> TODO: describe what this component does

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/worker-commits.sh`

## What It Does

Git Agent - worker-commits subcommand (T-2917)
Answers "what did autonomy commit on my behalf this week" without the
operator needing to know the identity string or hand-roll a `git log
--author` incantation. Filters on the dispatch-worker email shape minted by
`lib/worker_identity.py:worker_git_env` / `lib/git-identity.sh:fw_worker_git_identity_env`
(dispatch+<8-char-id>@aef.local) — anything matching that pattern is, by
construction, a commit the operator did not type.

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | called_by | Git Agent - Structural Enforcement for Git Operations |
| [git_worker_commits](/docs/generated/tests-unit-git_worker_commits) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-worker-commits.yaml`*
*Last verified: 2026-09-03*
