#!/usr/bin/env bash
# integrate-go-live.sh — safe zone-3 host go-live (T-2482; OBS-086 prototype).
#
# `fw integrate run` makes the worktree->master land smooth, but going LIVE on
# MAIN's busy checkout (zone 3) is left as a bare `git merge` that aborts the
# moment MAIN has any dirty transient — which is always. This script does what
# the land tool already does for the worktree side, against the host checkout:
#
#   1. clear untracked files that are tracked on the merge ref (e.g. a stale
#      vendored .agentic-framework/lib/integrate.py) — they block the merge.
#   2. checkpoint MAIN's tracked working state as a recoverable commit.
#   3. merge the remote ref (default origin/master).
#   4. auto-resolve ONLY whitelisted regenerable conflicts (handovers, working
#      memory, audits, VERSION) by taking the merged-in side; ABORT on anything
#      else — real conflicts need human judgment.
#   5. refresh vendored .agentic-framework/.
#
# Dry-run by default (no mutations). Pass --apply to execute.
#
# Usage:
#   bin/integrate-go-live.sh                 # preview (dry-run)
#   bin/integrate-go-live.sh --apply         # go live
#   bin/integrate-go-live.sh --repo /path --remote-ref origin/master --task T-123
#
set -euo pipefail

REPO="/opt/999-Agentic-Engineering-Framework"
REMOTE_REF="origin/master"
TASK_REF="T-2481"   # checkpoint commit needs a task ref (P-002); merge commits are hook-exempt.
APPLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)       APPLY=1 ;;
    --repo)        REPO="${2:?--repo needs a path}"; shift ;;
    --remote-ref)  REMOTE_REF="${2:?--remote-ref needs a ref}"; shift ;;
    --task)        TASK_REF="${2:?--task needs T-XXX}"; shift ;;
    -h|--help)     sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; s/^set -euo.*//'; exit 0 ;;
    *) echo "unknown arg: $1 (try -h)" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }
do_or_echo() {            # echo the command; run it only under --apply
  say "    \$ $*"
  if [ "$APPLY" -eq 1 ]; then "$@"; fi
}

# Conflict paths safe to auto-resolve to the merged-in (theirs) side.
is_regenerable() {
  case "$1" in
    .context/handovers/*|.context/working/*|.context/audits/*|VERSION) return 0 ;;
    *) return 1 ;;
  esac
}

cd "$REPO"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: $REPO is not a git repo" >&2; exit 2; }

branch="$(git rev-parse --abbrev-ref HEAD)"
say "── integrate go-live ──"
say "Repo:       $REPO"
say "Branch:     $branch"
say "Merge ref:  $REMOTE_REF"
say "Mode:       $([ "$APPLY" -eq 1 ] && echo APPLY || echo 'DRY-RUN (no changes)')"
say ""

do_or_echo git fetch origin --quiet

# Already live?
if git merge-base --is-ancestor "$REMOTE_REF" HEAD 2>/dev/null; then
  say "Already live: $REMOTE_REF is an ancestor of $branch. Nothing to do."
  exit 0
fi

# [1/5] untracked blockers (tracked on the merge ref) ---------------------------
say "[1/5] clearing untracked files that would block the merge…"
blockers=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if git cat-file -e "$REMOTE_REF:$f" 2>/dev/null; then blockers+=("$f"); fi
done < <(git status --porcelain 2>/dev/null | awk '$1=="??"{print $2}')
if [ "${#blockers[@]}" -eq 0 ]; then
  say "    (none)"
else
  for f in "${blockers[@]}"; do do_or_echo rm -f "$f"; done
fi

# [2/5] checkpoint MAIN tracked working state -----------------------------------
say "[2/5] checkpointing MAIN tracked working state…"
if [ -n "$(git diff --name-only)" ]; then
  do_or_echo git add -u
  do_or_echo git commit -q -m "$TASK_REF: integrate go-live — checkpoint MAIN state pre-merge"
else
  say "    (clean — nothing to checkpoint)"
fi

# [3/5] merge -------------------------------------------------------------------
say "[3/5] merging $REMOTE_REF…"
if [ "$APPLY" -eq 0 ]; then
  say "    (dry-run) predicted conflicts:"
  pred="$(git merge-tree --write-tree --name-only "$REMOTE_REF" HEAD 2>/dev/null | tail -n +2 || true)"
  if [ -n "$pred" ]; then say "$pred" | sed 's/^/      /'; else say "      (none — clean merge)"; fi
  say ""
  say "✓ preview done — re-run with --apply to go live."
  exit 0
fi

if git merge --no-edit "$REMOTE_REF"; then
  say "    merged cleanly."
else
  # [4/5] resolve whitelisted conflicts only -----------------------------------
  say "[4/5] resolving regenerable conflicts…"
  bad=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if is_regenerable "$f"; then
      say "    regenerable → take theirs: $f"
      git checkout --theirs -- "$f"
      git add -- "$f"
    else
      say "    UNEXPECTED conflict (needs human judgment): $f"
      bad=1
    fi
  done < <(git diff --name-only --diff-filter=U)
  if [ "$bad" -eq 1 ]; then
    say ""
    say "ABORTING — unexpected conflict(s) above. MAIN restored to pre-merge state."
    git merge --abort
    exit 1
  fi
  git commit --no-edit -q   # MERGE_HEAD present → commit-msg hook exempts this
  say "    resolved + committed."
fi

# [5/5] refresh vendored --------------------------------------------------------
say "[5/5] refreshing vendored .agentic-framework/…"
do_or_echo bin/fw vendor self

say ""
say "✓ go-live complete — MAIN ($branch) now carries $REMOTE_REF."
