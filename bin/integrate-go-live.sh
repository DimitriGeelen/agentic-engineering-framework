#!/usr/bin/env bash
# integrate-go-live.sh — safe zone-3 host go-live (T-2483; OBS-086).
#
# Make MAIN's running framework code match a remote ref (default origin/master)
# WITHOUT merging two divergent busy checkouts.
#
# Going live = MAIN's CODE (lib/ agents/ bin/) matches master. The DATA
# (.context/*) must stay MAIN's — it carries accumulators (feedback-stream,
# gate-bypass-log, decisions, inbox, metrics-history) that diverge legitimately
# per host and must never be clobbered. So we do a surgical code-only sync:
#
#   git checkout <remote-ref> -- <code dirs>   # bring master's code, only code
#   git commit -m "T-XXX: ..."                 # commit only the staged code
#
# This touches ZERO .context/ data, so it cannot conflict on accumulators and
# cannot race a busy checkout's data writers (single quick index op).
#
# WHY NOT MERGE (the v1 mistake, T-2482): committing MAIN's transients then
# `git merge origin/master` conflicts on EVERY data file both sides touched (18
# in the live failure, not the 1 a pre-checkpoint `merge-tree` predicted), and a
# concurrent git writer grabbed .git/index.lock mid-resolution, crashing the
# script half-merged. Merge is the wrong model here. See OBS-086.
#
# Dry-run by default (no mutations). Pass --apply to execute.
#
# Usage:
#   bin/integrate-go-live.sh                       # preview (dry-run)
#   bin/integrate-go-live.sh --apply               # go live
#   bin/integrate-go-live.sh --repo /p --remote-ref origin/master --task T-1 \
#                            --code-dirs "lib agents bin"
#
set -euo pipefail

REPO="/opt/999-Agentic-Engineering-Framework"
REMOTE_REF="origin/master"
TASK_REF="T-2481"          # commit needs a task ref (P-002, commit-msg hook).
CODE_DIRS="lib agents bin" # code only — NEVER add .context/ here.
APPLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)       APPLY=1 ;;
    --repo)        REPO="${2:?--repo needs a path}"; shift ;;
    --remote-ref)  REMOTE_REF="${2:?--remote-ref needs a ref}"; shift ;;
    --task)        TASK_REF="${2:?--task needs T-XXX}"; shift ;;
    --code-dirs)   CODE_DIRS="${2:?--code-dirs needs a space-separated list}"; shift ;;
    -h|--help)     sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; s/^set -euo.*//'; exit 0 ;;
    *) echo "unknown arg: $1 (try -h)" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }

cd "$REPO"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: $REPO is not a git repo" >&2; exit 2; }

# Guard: refuse if code dirs already have STAGED changes we'd be mixing with.
if [ -n "$(git diff --cached --name-only -- $CODE_DIRS 2>/dev/null)" ]; then
  echo "ERROR: code dirs already have staged changes; resolve those first." >&2
  exit 2
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
say "── integrate go-live (code-only sync) ──"
say "Repo:       $REPO"
say "Branch:     $branch"
say "Sync ref:   $REMOTE_REF"
say "Code dirs:  $CODE_DIRS"
say "Mode:       $([ "$APPLY" -eq 1 ] && echo APPLY || echo 'DRY-RUN (no changes)')"
say ""

[ "$APPLY" -eq 1 ] && git fetch origin --quiet || say "    (dry-run) would: git fetch origin"

# Preview the code delta WITHOUT mutating: diff working tree vs remote ref, code dirs only.
say "Code files that differ from $REMOTE_REF:"
delta="$(git diff --name-only "$REMOTE_REF" -- $CODE_DIRS 2>/dev/null || true)"
if [ -z "$delta" ]; then
  say "    (none — already in sync)"
  say ""
  say "✓ already live — nothing to do."
  exit 0
fi
say "$delta" | sed 's/^/    /'
say ""

if [ "$APPLY" -eq 0 ]; then
  say "✓ preview done — re-run with --apply to go live (code-only; .context/ data untouched)."
  exit 0
fi

# Execute: stage master's code, commit only that.
git checkout "$REMOTE_REF" -- $CODE_DIRS
staged="$(git diff --cached --name-only -- $CODE_DIRS | wc -l | tr -d ' ')"
say "staged $staged code file(s) from $REMOTE_REF"
git commit -q -m "$TASK_REF: go live — sync code ($CODE_DIRS) to $REMOTE_REF"
say ""
say "✓ go-live complete — MAIN ($branch) code now matches $REMOTE_REF. .context/ data untouched."
say "  (optional) refresh vendored copies for consumers: bin/fw vendor self"
