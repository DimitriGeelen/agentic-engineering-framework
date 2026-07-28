#!/bin/bash
# master-guard.sh — Master-as-merge-only pre-commit guard (T-2396, inception T-2394 G1)
#
# Refuses a DIRECT authored commit when HEAD is on master/main. Allows:
#   - merge commits    (MERGE_HEAD present)
#   - rebases          (rebase-merge / rebase-apply in progress)
#   - fast-forwards    (no commit object created → this hook never fires)
#   - feature branches (anything not master/main)
#   - protection off   (PROTECT_MASTER != 1)
#   - explicit bypass  (FW_ALLOW_MASTER_COMMIT=1)
#
# Enable:  fw config set PROTECT_MASTER 1     (or FW_PROTECT_MASTER=1 for a one-off)
# Bypass:  FW_ALLOW_MASTER_COMMIT=1 git commit ...   (Tier-2, WARN to stderr)
#      or: git commit --no-verify                     (Tier-0, skips all pre-commit hooks)
#
# Usage: master-guard.sh check     (exit 0 = allow, 1 = block, 2 = usage error)
#
# Origin: T-2394 — worktree isolation let parallel AEF agents commit straight to master
# with zero structural guard; "master is merge-only" was advisory only (L-405). This makes
# it structural. Consumer-safe by construction: default-off, opt-in per project.

set -uo pipefail

cmd="${1:-check}"
[ "$cmd" = "check" ] || { echo "usage: master-guard.sh check" >&2; exit 2; }

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$PROJECT_ROOT" ] || exit 0   # not a git repo → nothing to guard

# Resolve FRAMEWORK_ROOT (framework / consumer / vendored) for config.sh.
FRAMEWORK_ROOT="$PROJECT_ROOT"
if [ -f "$PROJECT_ROOT/.framework.yaml" ]; then
    _fw_path=$(grep "^framework_path:" "$PROJECT_ROOT/.framework.yaml" 2>/dev/null | sed 's/framework_path:[[:space:]]*//')
    [ -n "$_fw_path" ] && [ -d "$_fw_path" ] && FRAMEWORK_ROOT="$_fw_path"
fi
[ ! -f "$FRAMEWORK_ROOT/lib/config.sh" ] && [ -f "$PROJECT_ROOT/.agentic-framework/lib/config.sh" ] \
    && FRAMEWORK_ROOT="$PROJECT_ROOT/.agentic-framework"

# Resolve PROTECT_MASTER: FW_PROTECT_MASTER env wins; else fw_config; else 0.
# (fw_config itself honours FW_* > .framework.yaml > default, but reading the env
#  directly first keeps the guard testable without sourcing the whole config lib.)
_protect="0"
if [ -n "${FW_PROTECT_MASTER:-}" ]; then
    _protect="$FW_PROTECT_MASTER"
elif [ -f "$FRAMEWORK_ROOT/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$FRAMEWORK_ROOT/lib/config.sh" 2>/dev/null || true
    if command -v fw_config >/dev/null 2>&1; then
        _protect=$(fw_config "PROTECT_MASTER" 0 2>/dev/null || echo 0)
    fi
fi
[ "$_protect" = "1" ] || exit 0   # protection off → allow

# Explicit Tier-2 bypass: allow but WARN (visible in commit output).
if [ "${FW_ALLOW_MASTER_COMMIT:-0}" = "1" ]; then
    echo "WARN: master-guard bypassed via FW_ALLOW_MASTER_COMMIT=1 (Tier-2 — direct commit on a protected branch)" >&2
    exit 0
fi

# Only guard master/main. Detached HEAD (empty) and feature branches → allow.
_branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || echo "")
case "$_branch" in
    master|main) ;;
    *) exit 0 ;;
esac

# Allow merges and rebases — those are legitimate master advances.
if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then exit 0; fi
_rebase_merge=$(git rev-parse --git-path rebase-merge 2>/dev/null || echo "")
_rebase_apply=$(git rev-parse --git-path rebase-apply 2>/dev/null || echo "")
{ [ -n "$_rebase_merge" ] && [ -d "$_rebase_merge" ]; } && exit 0
{ [ -n "$_rebase_apply" ] && [ -d "$_rebase_apply" ]; } && exit 0

# Direct authored commit (including cherry-pick) on a protected branch → BLOCK.
cat >&2 <<MSG

BLOCKED: direct commit on '$_branch' — master is merge-only (T-2394 G1)

This repo enforces master-as-merge-only: master/main advances ONLY via a
fast-forward or merge of a reviewed branch — never a direct authored commit
(this includes cherry-pick). Worktree isolation let parallel agents write
master with no guard; this closes that gap (L-405).

Do this instead:
  git switch -c <feature-branch>     # move your staged work onto a branch
  git commit ...                     # commit there
  # then fast-forward / merge into master after review

Bypass (rare, deliberate deploy):
  FW_ALLOW_MASTER_COMMIT=1 git commit ...   # Tier-2 (logged WARN to stderr)
  git commit --no-verify                     # Tier-0 (skips all pre-commit hooks)

Disable repo-wide: fw config set PROTECT_MASTER 0
Origin: T-2394 (G1) — structural enforcement of the master-merge-only invariant.
MSG
exit 1
