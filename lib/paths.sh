#!/bin/bash
# lib/paths.sh — Centralized path resolution for the Agentic Engineering Framework
#
# Provides FRAMEWORK_ROOT, PROJECT_ROOT, and common directory variables.
# Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern
# duplicated across 25+ agent scripts.
#
# Usage (from any agent script):
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/paths.sh"
#
# Or if FRAMEWORK_ROOT is already known:
#   source "$FRAMEWORK_ROOT/lib/paths.sh"
#
# After sourcing, these variables are set:
#   FRAMEWORK_ROOT — Absolute path to the framework repo root
#   PROJECT_ROOT   — Absolute path to the project root (may differ in shared-tooling mode)
#   TASKS_DIR      — $PROJECT_ROOT/.tasks
#   CONTEXT_DIR    — $PROJECT_ROOT/.context
#
# Also sources lib/compat.sh for cross-platform helpers (_sed_i).

# Guard against double-sourcing
[[ -n "${_FW_PATHS_LOADED:-}" ]] && return 0
_FW_PATHS_LOADED=1

# Resolve FRAMEWORK_ROOT from this file's location (lib/paths.sh → repo root)
if [[ -z "${FRAMEWORK_ROOT:-}" ]]; then
    FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Resolve PROJECT_ROOT from git toplevel — framework/ is typically a subdirectory,
# not the project root. Fall back to FRAMEWORK_ROOT for standalone installs.
#
# T-1822: vendored .agentic-framework/ has its own .git after `fw vendor` clones
# from upstream, so `git -C $FRAMEWORK_ROOT rev-parse --show-toplevel` returns
# the vendored copy itself, not the consumer root. Detect the vendored case
# (basename .agentic-framework AND parent has .framework.yaml) and prefer the
# outer consumer root.
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    if [[ "$(basename "$FRAMEWORK_ROOT")" = ".agentic-framework" ]] \
       && [[ -f "$(dirname "$FRAMEWORK_ROOT")/.framework.yaml" ]]; then
        PROJECT_ROOT="$(dirname "$FRAMEWORK_ROOT")"
    else
        PROJECT_ROOT="$(git -C "$FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$FRAMEWORK_ROOT")"
    fi
fi

# T-2289 (OBS-053 3-incident class): re-derive TASKS_DIR/CONTEXT_DIR when
# they were inherited from a different PROJECT_ROOT. Symptom: shell A exports
# TASKS_DIR=/project-A/.tasks via `fw context init`; a subprocess in project B
# with `PROJECT_ROOT=/project-B fw …` inherits the stale /project-A/.tasks and
# writes go to the wrong project. The `:-` default below silently keeps the
# inherited value when non-empty.
#
# Fix: the `_FW_PATHS_DERIVED_BY` sentinel records the PROJECT_ROOT that
# originally derived the path vars. When it's present AND differs from the
# current PROJECT_ROOT, the inherited paths are stale — unset them so the
# `:-` defaults below re-derive from PROJECT_ROOT.
#
# Test-fixture invariant: when `TASKS_DIR` is set in the SAME shell as
# `PROJECT_ROOT` with no prior derivation, `_FW_PATHS_DERIVED_BY` is empty,
# the unset block is skipped, and the explicit `TASKS_DIR` survives intact
# (this is what tests/unit/create_task.bats:18 relies on).
if [[ -n "${_FW_PATHS_DERIVED_BY:-}" ]] && [[ "$_FW_PATHS_DERIVED_BY" != "$PROJECT_ROOT" ]]; then
    unset TASKS_DIR CONTEXT_DIR
fi

# Common directories
TASKS_DIR="${TASKS_DIR:-$PROJECT_ROOT/.tasks}"
CONTEXT_DIR="${CONTEXT_DIR:-$PROJECT_ROOT/.context}"

# T-2289: record which PROJECT_ROOT derived the path vars, so subprocess
# invocations under a different PROJECT_ROOT can detect the env-leak above.
_FW_PATHS_DERIVED_BY="$PROJECT_ROOT"
export _FW_PATHS_DERIVED_BY

# fw_reanchor_from_cwd <cwd> — re-anchor PROJECT_ROOT + path vars to the project
# root that <cwd> resolves to (walking up for .framework.yaml / .tasks), when it
# differs from the current PROJECT_ROOT. Always returns 0 (no-op cases included).
#
# T-2465 (generalizes T-2463 / OBS-080): a framework hook can execute a `bin/fw`
# other than the one belonging to the tree the tool actually ran in, so it reads the
# wrong focus.yaml / tasks / context.
#
# T-2709 UPDATE — the original wording here said "every framework hook is wired into
# settings.json by MAIN's absolute path (`<main>/bin/fw hook …`)". That premise is now
# FALSE: both generators emit `${CLAUDE_PROJECT_DIR}/bin/fw hook …`, which Claude Code
# expands to the session's project root. In a worktree session that resolves to the
# WORKTREE root, so the worktree's own bin/fw executes — the opposite of main-anchoring.
# The mismatch this function corrects therefore has two possible shapes now:
#   (a) legacy settings.json still carrying main's baked absolute path  → main's fw runs
#   (b) placeholder form                                                → worktree's fw runs
# In (b) the anchoring is usually already correct and this function degrades to a no-op
# (it compares against the resolved root and returns unchanged on a match). Note a
# worktree may carry a different framework VERSION than main, so under (b) the executing
# fw can differ in behaviour from main's — directionally an improvement (the tool runs
# the code of the tree it acted on), but worth knowing when debugging.
#
# Either way, bin/fw may still resolve PROJECT_ROOT from the hook's process cwd /
# inherited env rather than from the tree the tool ran in — which is what this fixes.
# Claude Code passes the authoritative per-call working dir as top-level `cwd` on
# the hook's stdin JSON ("working directory when the event fired"); this re-anchors
# to it. Per-call stdin cwd is FRESH (not inherited), so it is immune to the
# T-2446 daemon-poison class that limits CLAUDE_PROJECT_DIR trust.
#
# No-op when <cwd> is empty, not a dir, resolves to no project root, or already
# == PROJECT_ROOT — so normal (non-worktree) sessions are unaffected. Keeps
# _FW_PATHS_DERIVED_BY consistent (T-2289). Callers that cache their own
# PROJECT_ROOT-derived paths (FOCUS_FILE, STATUS_FILE, …) must recompute after.
fw_reanchor_from_cwd() {
    local cwd="$1"
    [ -n "$cwd" ] && [ -d "$cwd" ] || return 0
    local root="" d
    d="$(cd "$cwd" 2>/dev/null && pwd -P)" || return 0
    while [ -n "$d" ] && [ "$d" != "/" ]; do
        if [ -f "$d/.framework.yaml" ] || [ -d "$d/.tasks" ]; then
            root="$d"; break
        fi
        d="$(dirname "$d")"
    done
    [ -n "$root" ] && [ "$root" != "${PROJECT_ROOT:-}" ] || return 0
    PROJECT_ROOT="$root"
    TASKS_DIR="$PROJECT_ROOT/.tasks"
    CONTEXT_DIR="$PROJECT_ROOT/.context"
    _FW_PATHS_DERIVED_BY="$PROJECT_ROOT"
    export PROJECT_ROOT TASKS_DIR CONTEXT_DIR _FW_PATHS_DERIVED_BY
    return 0
}

# fw_reanchor_from_hook_stdin <input_json> — convenience wrapper for hooks:
# extract the top-level `cwd` from a Claude Code hook stdin payload and re-anchor
# via fw_reanchor_from_cwd. One call replaces the per-hook inline block. (T-2465)
fw_reanchor_from_hook_stdin() {
    local cwd
    cwd=$(printf '%s' "$1" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('cwd', '') or '')
except Exception:
    print('')
" 2>/dev/null)
    fw_reanchor_from_cwd "$cwd"
}

# T-3038 (OBS-291): resolve the focus file for THIS session.
#
# Focus was per-project global state: one `.context/working/focus.yaml` shared by
# the parent session and every worker it dispatches. That is an unavoidable
# converging write that no task declares as a component, so `fw write-set check`
# returns rc=2 (undecidable) for every pair — the disjointness check cannot see it.
#
# The failure is not a lost write, it is a LOCKOUT. `fw context focus` stamps
# `focus_session` alongside `current_task`, and check-active-task.sh:448 blocks
# when that stamp does not match the running session. So a dispatched worker
# calling `fw work-on` flips the shared file to its own task and its own session
# id, and the PARENT is then refused on every Write AND every Bash — including
# read-only ls/cat/grep (the G-078 class). The parent is locked out of its own
# unrelated work by a worker it spawned. Recovery (`fw context focus T-PARENT`)
# is racy: the next `fw work-on` in any worker re-hijacks it.
#
# The fix is to give workers their own file. When FW_SESSION_SCOPED_FOCUS=1, focus
# reads and writes go to `focus.<key>.yaml` and the shared file is never touched,
# so the parent's task and session stamp survive untouched.
#
# The key must be stable for the worker's whole lifetime and distinct per worker.
# Preference order, first non-empty wins:
#   FW_FOCUS_SESSION_KEY  explicit override; what `fw termlink dispatch` exports
#                         (the worker name, which is unique per dispatch)
#   TERMLINK_SESSION      set by TermLink itself when a session owns the shell
#   PPID                  last-resort fallback — correct per-process, but not
#                         stable if the parent shell is replaced, hence last
#
# Default (unset/0) returns the shared path verbatim: existing single-session
# behaviour is unchanged, which is what keeps this safe to land without migration.
#
# Usage: focus_file=$(fw_focus_file "$PROJECT_ROOT")
fw_focus_file() {
    local root="${1:-$PROJECT_ROOT}"
    local dir="$root/.context/working"

    if [ "${FW_SESSION_SCOPED_FOCUS:-0}" != "1" ]; then
        printf '%s\n' "$dir/focus.yaml"
        return 0
    fi

    local key="${FW_FOCUS_SESSION_KEY:-${TERMLINK_SESSION:-$PPID}}"
    # Sanitize: the key lands in a filename and worker names are free-form
    # (--name is caller-supplied). Dropping '/' alone would already contain the
    # path, but '.' is excluded too so a key like '../x' cannot produce a
    # filename containing '..' — there is no reason to carry traversal-shaped
    # text into a path, even a contained one.
    key=$(printf '%s' "$key" | tr -c 'a-zA-Z0-9_-' '-')
    printf '%s\n' "$dir/focus.$key.yaml"
}

# T-2375: Claude Code transcript project-dir-name sanitizer.
# Claude Code encodes a session's cwd into ~/.claude/projects/<name> by replacing
# EVERY non-alphanumeric character with '-' (so both '/' and '.' become '-').
# The budget detector previously reconstructed this with `${path//\//-}`, which
# replaces only '/' and leaves '.' intact — so in any path containing a dot
# (notably git worktrees under `.claude/worktrees/`, the framework's own
# isolation model) the computed name (`-…-.claude-worktrees-…`) did NOT match
# Claude Code's actual dir (`-…--claude-worktrees-…`). find_transcript() then
# looked in a non-existent dir → "no transcript" → the token budget gauge was
# BLIND in every worktree session. This helper matches Claude Code's encoding.
# Usage: name=$(fw_claude_project_dir_name "/abs/path")
fw_claude_project_dir_name() {
    printf '%s' "$1" | tr -c 'a-zA-Z0-9' '-'
}

# Emit the candidate Claude Code transcript *project dirs* for the current
# session, one per line (existing dirs only, de-duplicated). Callers must pick
# the globally-newest *.jsonl across them.
#
# T-2392: Claude Code keys the transcript projects dir on the session's LAUNCH
# cwd. In a git worktree (the framework's own isolation model) that launch cwd is
# the MAIN repo, not PROJECT_ROOT (the worktree). So reconstructing the dir from
# PROJECT_ROOT alone searched a stale/empty sibling and the budget gauge went
# blind → the continuous loop never armed. We therefore emit BOTH:
#   1. the PROJECT_ROOT-keyed dir, and
#   2. the primary-worktree (main-repo) keyed dir — found via
#      `git rev-parse --git-common-dir` (→ <main>/.git) → its parent.
# In a non-worktree session the two collapse to one (deduped). Graceful when the
# root is not a git repo (only candidate 1 is emitted).
# Usage: while IFS= read -r d; do ...; done < <(fw_claude_project_dirs)
fw_claude_project_dirs() {
    local base="${HOME}/.claude/projects"
    local root="${PROJECT_ROOT:-${FRAMEWORK_ROOT:-$PWD}}"
    local -a roots=("$root")

    # Primary worktree (main repo): git-common-dir is <main>/.git; its parent is
    # the main-repo root that Claude Code was launched from.
    local common_dir main_root
    common_dir=$(git -C "$root" rev-parse --git-common-dir 2>/dev/null) || common_dir=""
    if [ -n "$common_dir" ]; then
        # Absolute-ize a relative common-dir (the main-repo case returns ".git").
        case "$common_dir" in
            /*) ;;
            *) common_dir="$root/$common_dir" ;;
        esac
        main_root=$(cd "$common_dir/.." 2>/dev/null && pwd -P) || main_root=""
        [ -n "$main_root" ] && roots+=("$main_root")
    fi

    local seen="" r name dir
    for r in "${roots[@]}"; do
        [ -n "$r" ] || continue
        name=$(fw_claude_project_dir_name "$r")
        dir="$base/$name"
        case "$seen" in *"|$dir|"*) continue ;; esac
        seen="$seen|$dir|"
        [ -d "$dir" ] && printf '%s\n' "$dir"
    done
}

# fw_is_linked_worktree — defined in lib/worktree-identity.sh (T-3111).
#
# It moved out of this file because bin/fw needs the same predicate BEFORE any
# path is resolved (the R7 leg-L2 redirect decides which binary runs), and
# sourcing THIS file that early is not possible: paths.sh resolves and exports
# FRAMEWORK_ROOT/PROJECT_ROOT/TASKS_DIR as a side effect of being sourced.
# Sourced here so every existing caller keeps the function unchanged.
# Resolved relative to this file rather than $FRAMEWORK_ROOT — same reason
# lib/hook-parity.sh does: in a replica, FRAMEWORK_ROOT names the replica.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/worktree-identity.sh"


# fw_task_view_dirs — enumerate every `.tasks/` VIEW of the task corpus (T-3104).
#
# A git worktree checks out its own snapshot of `.tasks/`, possibly behind (or
# ahead of) the main checkout. So "the task corpus" is not one directory — it is
# the UNION of every worktree's `.tasks/`. Any consumer that reasons about the
# corpus as a whole (ID allocation, duplicate-ID detection) must scan all views,
# or it will be blind to whatever the other views hold.
#
# WHY THIS EXISTS — split-view ID collision (L-506 leg 2, origin T-100202,
# 2026-07-21): an allocator computing max+1 over ONE view reads a stale max and
# mints an ID another view already used. That is not hypothetical — T-2505,
# T-2506 and T-2428 were each minted twice on 2026-07-01 across two worktrees.
#
# CONTRACT:
#   - Emits one absolute `.tasks/` path per line.
#   - Worktrees with no `.tasks/` directory are skipped (nothing to scan).
#   - `$TASKS_DIR` (the local view) is ALWAYS emitted, even when it is not a
#     directory and even when it does not appear in `git worktree list`. This is
#     the load-bearing guarantee: a symlinked or otherwise non-matching local
#     path must never fall out of the corpus.
#   - Non-git fallback: when `$TASKS_DIR`'s parent is not inside a git repo
#     (test harnesses, non-git consumers), the local view alone is returned —
#     no crash, no stderr.
#   - Output is DE-DUPLICATED, first-occurrence order preserved. Pre-lift the
#     local view was emitted twice (once from `git worktree list`, once from the
#     trailing append); the sole consumer piped through `sort -u`, so this
#     changes the multiset, never the SET — see docs/reports/T-3104-*.md.
#
# NOT THE SAME QUESTION AS `_wt_is_ignorable_path` (lib/worktree.sh). That
# predicate classifies `.tasks/` as a DELIVERABLE — a worktree whose only change
# is under `.tasks/` has real work that must land before teardown. Here `.tasks/`
# is CORPUS — a view to read IDs out of. Two callers, two correct answers. Do not
# "unify" them; they would produce a bug in whichever direction you collapsed.
fw_task_view_dirs() {
    local base wt v seen
    local -a views=()

    base="$(cd "$(dirname "$TASKS_DIR")" 2>/dev/null && pwd)"
    if [ -n "$base" ] && git -C "$base" rev-parse --git-dir >/dev/null 2>&1; then
        while IFS= read -r wt; do
            [ -d "$wt/.tasks" ] && views+=("$wt/.tasks")
        done < <(git -C "$base" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
    fi
    # Unconditional — the local view is in the corpus whether or not git named it.
    views+=("$TASKS_DIR")

    seen=$'\n'
    for v in "${views[@]}"; do
        case "$seen" in *$'\n'"$v"$'\n'*) continue ;; esac
        seen="${seen}${v}"$'\n'
        printf '%s\n' "$v"
    done
}

# Context-aware fw command path (T-1102/T-1143)
# Returns the right form for copy-pasteable commands shown to users:
#   - Framework repo: bin/fw
#   - Consumer with shim: fw
#   - Consumer without shim: .agentic-framework/bin/fw
_fw_cmd() {
    if [ "$PROJECT_ROOT" = "$FRAMEWORK_ROOT" ]; then
        echo "bin/fw"
    elif command -v fw &>/dev/null; then
        echo "fw"
    else
        echo ".agentic-framework/bin/fw"
    fi
}

# Emit a full copy-pasteable command with cd prefix (T-609/T-1102)
# Usage: _emit_user_command "inception decide T-XXX go"
_emit_user_command() {
    echo "cd $PROJECT_ROOT && $(_fw_cmd) $1"
}

# Export for subprocesses
export FRAMEWORK_ROOT PROJECT_ROOT TASKS_DIR CONTEXT_DIR

# Source cross-platform compat helpers (_sed_i)
source "$FRAMEWORK_ROOT/lib/compat.sh" 2>/dev/null || {
    # Inline fallback if compat.sh is missing (should not happen in normal installs)
    _sed_i() {
        local expr="$1" file="$2"
        local tmp
        tmp=$(mktemp "${file}.XXXXXX") && sed "$expr" "$file" > "$tmp" && mv "$tmp" "$file"
    }
}

# Source error output helpers (die, warn, error, info, success, block)
source "$FRAMEWORK_ROOT/lib/errors.sh" 2>/dev/null || true

# Source task lookup helpers (find_task_file, task_exists, get_task_name)
source "$FRAMEWORK_ROOT/lib/tasks.sh" 2>/dev/null || true

# Source YAML field extraction (get_yaml_field)
source "$FRAMEWORK_ROOT/lib/yaml.sh" 2>/dev/null || true
