#!/bin/bash
# T-3110 — L1 of R7: task-corpus commit guard for the SHARED pre-commit hook.
#
# WHY THIS EXISTS, AND WHY IT IS NOT JUST ANOTHER SCANNER
# ------------------------------------------------------
# R1-R6 of docs/design/task-corpus-concurrency-model.md are enforced by code.
# That code is TRACKED CONTENT, so it forks with the branch: a linked worktree
# supplies the very code meant to constrain the linked worktree. Measured in
# this repo — the `t100199-close` worktree has no check-worktree-governance-write.sh,
# zero union-scan in its allocator, and a `bin/fw` dated 6 July. Every fix in
# that document is absent from the replica it was designed to constrain.
#
# `.git/hooks` is the one anchor that does NOT fork: it resolves to the shared
# common dir from the main checkout and from every linked worktree alike, and
# core.hooksPath is set explicitly rather than merely defaulted. A hook installed
# once at the authority therefore runs in every replica REGARDLESS OF THAT
# REPLICA'S FRAMEWORK VERSION — the only leg that reaches a worktree created
# before the fix existed.
#
# That property is load-bearing and easy to destroy. This file is resolved by
# the hook from the AUTHORITY (via `git rev-parse --git-common-dir`), never from
# the committing worktree's own checkout. If it were resolved the way every other
# pre-commit scanner is — off `git rev-parse --show-toplevel`, which in a worktree
# is the worktree — a stale replica would supply a stale (or absent) guard and the
# whole leg would evaporate exactly where it is needed. Do not "simplify" the
# resolution in agents/git/lib/hooks.sh to match its siblings.
#
# SCOPE — `.tasks/` ONLY
# ----------------------
# Source commits from a worktree are the normal, supported flow: `fw worktree
# create` -> build -> `fw integrate run master --push`. They are untouched. Only
# the task corpus is guarded, because only the task corpus is a registry with
# global invariants (IDs unique across all space and time) that cannot fork and
# merge. See the design doc's "The mismatch".
#
# HONEST LIMITS (design doc, "The honest limits")
#   - commit-time, not write-time: an uncommitted duplicate still exists on disk.
#     R2 (check-worktree-governance-write.sh) is the write-time leg; it is
#     stronger but version-dependent, which is what this leg is not.
#   - assumes core.hooksPath is not overridden to a per-worktree path.
#   - `git commit --no-verify` skips it, like every other pre-commit gate.
#
# BYPASS — env var, not a flag (L-399 / T-1890 producer-consumer parity)
#   FW_ALLOW_WORKTREE_CORPUS_COMMIT=1
# `git commit` rejects unknown options, so a flag contract could not be honoured
# by the downstream consumer and the agent would route around the gate instead.
# Every bypass writes a Tier-2 entry to the AUTHORITY's
# .context/working/.gate-bypass-log.yaml — the authority's, because that is the
# single register R1 designates, and because the worktree's copy is itself a fork.
#
# USAGE
#   As a library (fw doctor / audit — AC #2, the T-3101 one-predicate-many-surfaces
#   shape):
#       source agents/git/lib/worktree-corpus-guard.sh
#       fw_worktree_corpus_commit_refused "$dir" && echo "would refuse"
#       fw_worktree_corpus_staged_paths   "$dir"
#       fw_worktree_corpus_authority_root "$dir"
#   As a script (the pre-commit hook):
#       PROJECT_ROOT=<committing worktree> bash worktree-corpus-guard.sh scan-staged
#         exit 0 — allowed (main checkout, no staged .tasks/, bypass, non-git)
#         exit 1 — refused (block message on stderr)
#         exit 2 — usage error

# Sourced or executed? Decided once, up front, because both entry points are
# real: fw doctor / audit source this for the predicate (AC #2), the pre-commit
# hook executes it. `return` outside a function is an error in the executed case,
# so the double-source guard below cannot be the usual bare `return 0`.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    _FW_WCG_SOURCED=0
else
    _FW_WCG_SOURCED=1
    # Guard against double-sourcing (fw doctor may pull this in alongside others).
    if [ -n "${_FW_WORKTREE_CORPUS_GUARD_LOADED:-}" ]; then
        return 0
    fi
fi
_FW_WORKTREE_CORPUS_GUARD_LOADED=1

# ── fw_worktree_corpus_authority_root [dir] ───────────────────────────────────
# Echo the absolute path of the AUTHORITY checkout (the main checkout) for DIR.
# In a linked worktree, --git-common-dir is <main>/.git, so its parent is <main>.
# In the main checkout the two collapse and this returns the toplevel itself.
# Echoes nothing and returns 1 when DIR is not a git repo.
fw_worktree_corpus_authority_root() {
    local dir="${1:-${PROJECT_ROOT:-$PWD}}"
    local gcd
    gcd=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
    [ -n "$gcd" ] || return 1
    case "$gcd" in /*) ;; *) gcd="$dir/$gcd" ;; esac
    ( cd "$(dirname "$gcd")" 2>/dev/null && pwd ) || return 1
}

# ── fw_worktree_corpus_staged_paths [dir] ─────────────────────────────────────
# Echo every `.tasks/` path staged for the next commit in DIR, one per line.
#
# `git diff --cached` (staged CHANGES), never `git ls-files --cached` (the whole
# index): the latter lists every tracked task file on every commit and would
# refuse literally every worktree commit, source-only ones included.
#
# --no-renames is deliberate. With rename detection on, `--name-only` prints only
# the destination, so moving a file OUT of .tasks/ would hide the .tasks/ source
# side. Split into delete+add and both sides are visible; a guard should see more,
# not less.
fw_worktree_corpus_staged_paths() {
    local dir="${1:-${PROJECT_ROOT:-$PWD}}"
    local top
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 1
    if git -C "$top" rev-parse -q --verify HEAD >/dev/null 2>&1; then
        git -C "$top" diff --cached --no-renames --name-only -- '.tasks' 2>/dev/null
    else
        # No HEAD yet (initial commit): everything in the index is staged-new,
        # and `git diff --cached` has no commit to diff against.
        git -C "$top" ls-files --cached -- '.tasks' 2>/dev/null
    fi
}

# ── fw_worktree_corpus_commit_refused [dir] ───────────────────────────────────
# THE PREDICATE (AC #1 / AC #2). Exit 0 when a commit from DIR must be refused:
# DIR is a LINKED WORKTREE (git-dir != git-common-dir) AND the commit stages at
# least one path under `.tasks/`. Exit 1 otherwise — main checkout, non-git dir,
# or a commit that touches no task file.
#
# Detection delegates to lib/paths.sh:fw_is_linked_worktree. It is NEVER a
# substring test for ".claude/worktrees" — that is a naming convention, not an
# invariant — and it is never re-implemented here, because re-implementing the
# primitive is the exact producer/consumer split (L-399) this whole defect class
# is about. Same call the T-3098 write-time sibling makes.
fw_worktree_corpus_commit_refused() {
    local dir="${1:-${PROJECT_ROOT:-$PWD}}"
    fw_is_linked_worktree "$dir" || return 1
    local staged
    staged=$(fw_worktree_corpus_staged_paths "$dir") || return 1
    [ -n "$staged" ]
}

# ══ script mode ══════════════════════════════════════════════════════════════
# Everything below is DEFINED always but RUN only when executed (see _FW_WCG_SOURCED).

_fw_wcg_main() {
    local mode="${1:-scan-staged}"
    case "$mode" in
        scan-staged) ;;
        -h|--help)
            sed -n '2,60p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            return 0
            ;;
        *)
            echo "worktree-corpus-guard: unknown mode '$mode' (use scan-staged)" >&2
            return 2
            ;;
    esac

    local wt
    wt="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    [ -d "$wt" ] || return 0

    # fw_is_linked_worktree lives in lib/paths.sh. Resolve it relative to THIS
    # file (…/agents/git/lib/ -> repo root), which the hook has already resolved
    # from the authority — so we get the authority's primitive, not a replica's.
    local _self_root
    _self_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd) || return 0
    if [ -f "$_self_root/lib/paths.sh" ]; then
        # Pre-set both roots so paths.sh does no discovery of its own: under a
        # pre-commit hook the cwd is the WORKTREE, and letting paths.sh derive
        # PROJECT_ROOT from it would silently re-point the bypass log at the
        # replica (T-2463/T-2465 class).
        FRAMEWORK_ROOT="$_self_root"
        PROJECT_ROOT="$_self_root"
        source "$_self_root/lib/paths.sh" 2>/dev/null || return 0
    fi
    # Degrade to ALLOW, never crash: a guard that fails closed on its own
    # missing dependency would block every commit in the repo.
    declare -F fw_is_linked_worktree >/dev/null 2>&1 || return 0

    fw_worktree_corpus_commit_refused "$wt" || return 0

    local staged authority rel_list
    staged=$(fw_worktree_corpus_staged_paths "$wt")
    authority="${FW_AUTHORITY_ROOT:-$(fw_worktree_corpus_authority_root "$wt")}"
    [ -n "$authority" ] || authority="<main checkout>"
    rel_list=$(printf '%s\n' "$staged" | sed 's/^/    /')

    # ── Bypass (AC #4 / AC #5) ────────────────────────────────────────────────
    # Logged only when it bypassed a refusal that would really have fired, so the
    # register answers "does a real workflow need corpus commits from a worktree?"
    # with data rather than noise. Entry names the staged paths, per AC #5.
    if [ "${FW_ALLOW_WORKTREE_CORPUS_COMMIT:-0}" = "1" ]; then
        local log_dir="$authority/.context/working"
        mkdir -p "$log_dir" 2>/dev/null || true
        # L-392: double embedded single quotes for YAML single-quoted-scalar safety.
        _wcg_esc() { printf '%s' "${1//\'/\'\'}"; }
        {
            echo "- timestamp: '$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
            echo "  task: '$(_wcg_esc "${FW_TASK_ID:-unknown}")'"
            echo "  flag: 'FW_ALLOW_WORKTREE_CORPUS_COMMIT'"
            echo "  caller: 'worktree-corpus-guard'"
            echo "  worktree: '$(_wcg_esc "$wt")'"
            echo "  main_checkout: '$(_wcg_esc "$authority")'"
            echo "  staged_paths:"
            printf '%s\n' "$staged" | while IFS= read -r _p; do
                [ -n "$_p" ] && echo "    - '$(_wcg_esc "$_p")'"
            done
        } >> "$log_dir/.gate-bypass-log.yaml" 2>/dev/null || true
        echo "NOTE: task-corpus commit from linked worktree $wt allowed via FW_ALLOW_WORKTREE_CORPUS_COMMIT=1 — logged Tier-2 to $log_dir/.gate-bypass-log.yaml" >&2
        return 0
    fi

    # ── Block message (AC #3) — written for the AGENT that trips it (T-2139/T-2143):
    # names the authority path, the staged paths, and the bypass, so it can unblock
    # itself without asking the operator.
    {
        echo ""
        echo "══════════════════════════════════════════════════════════"
        echo "  TASK-CORPUS COMMIT FROM A LINKED WORKTREE — refused (T-3110)"
        echo "══════════════════════════════════════════════════════════"
        echo ""
        echo "  Worktree (replica): $wt"
        echo "  Authority (main):   $authority"
        echo ""
        echo "  Staged .tasks/ paths in this commit:"
        echo "$rel_list"
        echo ""
        echo "  Why: .tasks/ is not source. It is a REGISTRY with global"
        echo "  invariants — IDs unique across all space and time, one"
        echo "  authoritative status per task. A registry cannot fork and merge:"
        echo "  there is no resolution for \"we both minted T-2505 for different"
        echo "  work\", because the information needed to resolve it was destroyed"
        echo "  at allocation time. T-2505, T-2506 and T-2428 were each minted"
        echo "  twice on 2026-07-01 across two worktrees and stayed invisible for"
        echo "  seven weeks. See docs/design/task-corpus-concurrency-model.md."
        echo ""
        echo "  The correct move — unstage the corpus, keep your source commit:"
        echo ""
        echo "    git restore --staged .tasks && git commit -m \"...\""
        echo ""
        echo "  Then make the corpus change at the authority, where it belongs:"
        echo ""
        echo "    cd $authority && bin/fw task update T-XXX --status <status>"
        echo ""
        echo "  Source commits from this worktree are unaffected — build here and"
        echo "  land with \`fw integrate run master --push\` from the main checkout."
        echo "  Only .tasks/ is guarded."
        echo ""
        echo "  DISPATCH WORKERS: agents/dispatch/preamble.md (L-419) tells you to"
        echo "  \`git add .tasks/active/T-XXX-*.md\` after a work-completed"
        echo "  transition. In a worktree, do NOT — leave the frontmatter delta"
        echo "  uncommitted and say so in your final message; the parent sweeps it"
        echo "  at the authority. That protocol predates this gate."
        echo ""
        echo "  If this commit genuinely belongs here, bypass with the env var"
        echo "  (\`git commit\` rejects unknown options, so it cannot be a flag):"
        echo ""
        echo "    FW_ALLOW_WORKTREE_CORPUS_COMMIT=1 git commit -m \"...\""
        echo ""
        echo "  Every bypass is logged Tier-2 with the staged paths to"
        echo "  $authority/.context/working/.gate-bypass-log.yaml — on purpose."
        echo "  Use it if you need it; do not route around it."
        echo ""
    } >&2
    return 1
}

if [ "$_FW_WCG_SOURCED" = "0" ]; then
    _fw_wcg_main "$@"
    exit $?
fi
