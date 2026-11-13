#!/bin/bash
# grant-file-guard.sh — T-5031 (ring20-dashboard a14cb4c1, HIGH; G-129).
#
# Refuses a commit that changes policy/access-grants.yaml while the commit runs under agent
# control. The grant file decides which outside paths an agent may read or write, and it is
# read from HEAD only: a commit is what makes a grant count, so the commit is where the agent
# is stopped. The agent cannot write the file either (check-project-boundary.sh, T-4988,
# T-5034); this closes the git routes that end in a commit — commit of a staged copy,
# `commit -a` of an operator's uncommitted edit, checkout/restore/apply then commit, and a
# merge commit (pre-merge-commit runs this too).
#
# "Agent control" is CLAUDECODE=1, which Claude Code sets for every command an agent runs
# and which `claude -p` workers inherit. The operator's runme runs in the operator's own
# shell, without it, and is not affected.
#
# NOT covered (same boundary as every client-side hook): git commit --no-verify (labelled
# HOOK BYPASS by the Tier 0 gate), and git verbs that run no pre-commit hook (cherry-pick,
# rebase, am). The grant audit's provenance check is the backstop for those.
#
# Usage (from a hook): bash grant-file-guard.sh   → exit 0 allow, 1 refuse
GRANT_FILE="policy/access-grants.yaml"

[ "${CLAUDECODE:-}" = "1" ] || exit 0

# --no-renames: a rename away from the grant file is a deletion of it, and must show.
changed=$(git diff --cached --no-renames --name-only -- "$GRANT_FILE" 2>/dev/null) || {
    echo "grant-file-guard: cannot read the staged changes — refusing (fail closed, T-5031)" >&2
    exit 1
}
[ -z "$changed" ] && exit 0

cat >&2 <<'MSG'

  ACCESS GRANTS — this commit changes policy/access-grants.yaml (T-5031).

  The grant file is the operator's: it decides which outside paths an agent may reach,
  and a commit is what makes it count. A commit under agent control (CLAUDECODE=1) may
  not change it.

  Ask the operator to make the change and commit it themselves with the trailer
  'Grants-Change: operator' (from their own shell or a runme they start).
  To drop the file from THIS commit:  git restore --staged policy/access-grants.yaml

MSG
exit 1
