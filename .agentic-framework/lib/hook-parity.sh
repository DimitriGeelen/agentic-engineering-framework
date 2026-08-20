#!/usr/bin/env bash
# lib/hook-parity.sh — the enforcement-baseline comparison predicate (T-3112, R7 leg 3)
#
# ONE PREDICATE, MANY SURFACES (the T-3101 shape).
#
# "Does this replica carry the hooks the authority carries?" is asked of two
# different subjects that used to have nothing in common:
#
#   1. CONSUMER PROJECTS — a vendored `.agentic-framework/` tree with its own
#      `.claude/settings.json`. Audited by `fw doctor` since T-616.
#   2. LINKED WORKTREES  — a git worktree with its own `.claude/settings.json`,
#      its own `bin/fw`, and its own copy of the enforcement code that is
#      supposed to constrain it. Audited by nobody until this file existed.
#
# Subject (2) is the R7 discovery: rules are enforced by code, code is tracked
# content, therefore the replica supplies the code meant to constrain the
# replica. Measured in the `t100199-close` worktree on 2026-08-20:
# `check-worktree-governance-write.sh` absent, `CLAUDE_PROJECT_DIR` 0 refs,
# `bin/fw` dated 6 July. See `docs/design/task-corpus-concurrency-model.md` §R7.
#
# The predicate lived inline inside `bin/fw`'s Consumer Projects loop as a
# heredoc'd python block. Adding the worktree surface by copying that block
# would have made two copies that drift independently — which is the same class
# of bug the worktree audit is being added to catch. So it moved here, and
# `bin/fw` now holds zero copies. `tests/unit/t3112_worktree_hook_parity.bats`
# pins the zero.
#
# WHAT "MISSING" MEANS. The delta is one-directional: hooks the AUTHORITY has
# that the REPLICA lacks. A replica carrying *extra* hooks is not reported —
# a consumer or worktree may legitimately add project-local hooks, and flagging
# those would make the check noisy enough to be ignored, which is how a check
# stops being read. Under-enforcement is the failure mode with teeth.
#
# Sourceable and side-effect free. No `set -e`, no output on source.

# ── fw_hook_parity_delta <authority_settings.json> <replica_settings.json> ────
#
# Prints exactly one line, always exits 0 (the verdict is the string, so that
# callers can render it without branching on an exit code they'd then have to
# map back to a string anyway):
#
#   ok N/M                      replica has every authority hook; N of M present
#   missing K: name1, name2     replica lacks K of the authority's hooks
#   absent                      replica has no settings.json at all
#   parse-error                 one of the files exists but did not parse
#
# `absent` is deliberately NOT `missing <all>`: a worktree created before the
# hook set existed and a worktree whose settings were emptied are different
# stories with different remedies, and collapsing them loses the one that
# matters (see the T-3105 set-reporting rule — state what you actually saw).
fw_hook_parity_delta() {
    local authority="$1" replica="$2"

    [ -f "$authority" ] || { printf 'parse-error\n'; return 0; }
    [ -f "$replica" ]   || { printf 'absent\n'; return 0; }

    # The predicate itself lives in lib/hook_parity.py — see its module docstring
    # for why it is python and not inlined here. Resolved relative to THIS file,
    # not $FRAMEWORK_ROOT: in a linked worktree FRAMEWORK_ROOT points at the
    # replica, which is precisely the checkout whose code we must not trust.
    local _self_dir
    _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    python3 "$_self_dir/hook_parity.py" delta "$authority" "$replica" 2>/dev/null \
        || printf 'parse-error\n'
}

# ── fw_hook_parity_authority_root [dir] ──────────────────────────────────────
#
# The main checkout — the one directory in a worktree set whose settings are
# authoritative. `--git-common-dir` is <main>/.git from the main checkout AND
# from every linked worktree, so its parent is the authority from anywhere.
# Same resolution as agents/git/lib/worktree-corpus-guard.sh; deliberately NOT
# $FRAMEWORK_ROOT, which in a linked worktree points at the replica.
fw_hook_parity_authority_root() {
    local dir="${1:-${PROJECT_ROOT:-$PWD}}" gcd
    gcd=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
    case "$gcd" in
        /*) ;;
        *) gcd="$dir/$gcd" ;;
    esac
    (cd "$gcd/.." 2>/dev/null && pwd -P) || return 1
}

# ── fw_hook_parity_linked_worktrees [dir] ────────────────────────────────────
#
# Absolute paths of the LINKED worktrees, one per line — the main checkout is
# excluded (it is the authority, not a replica; comparing it to itself would
# manufacture a guaranteed OK and inflate the examined-set count).
#
# Exit 1 when the set is UNENUMERABLE (not a git repo, or `git worktree list`
# failed). Callers must distinguish that from an empty set: T-3105 — an
# unenumerable candidate set is a WARN, never a PASS.
fw_hook_parity_linked_worktrees() {
    local dir="${1:-${PROJECT_ROOT:-$PWD}}" authority listing wt
    git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || return 1
    authority=$(fw_hook_parity_authority_root "$dir") || return 1
    listing=$(git -C "$dir" worktree list --porcelain 2>/dev/null) || return 1

    while IFS= read -r wt; do
        [ -n "$wt" ] || continue
        [ "$wt" = "$authority" ] && continue
        printf '%s\n' "$wt"
    done < <(printf '%s\n' "$listing" | sed -n 's/^worktree //p')
    return 0
}
