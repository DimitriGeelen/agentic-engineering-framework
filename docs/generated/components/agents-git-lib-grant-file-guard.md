# grant-file-guard

> grant-file-guard.sh — T-5031 (ring20-dashboard a14cb4c1, HIGH; G-129).

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/grant-file-guard.sh`

## What It Does

grant-file-guard.sh — T-5031 (ring20-dashboard a14cb4c1, HIGH; G-129).
Refuses a commit that changes policy/access-grants.yaml while the commit runs under agent
control. The grant file decides which outside paths an agent may read or write, and it is
read from HEAD only: a commit is what makes a grant count, so the commit is where the agent
is stopped. The agent cannot write the file either (check-project-boundary.sh, T-4988,
T-5034); this closes the git routes that end in a commit — commit of a staged copy,
`commit -a` of an operator's uncommitted edit, checkout/restore/apply then commit, and a
merge commit (pre-merge-commit runs this too).
"Agent control" is CLAUDECODE=1, which Claude Code sets for every command an agent runs
and which `claude -p` workers inherit. The operator's runme runs in the operator's own

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-grant-file-guard.yaml`*
*Last verified: 2026-11-13*
