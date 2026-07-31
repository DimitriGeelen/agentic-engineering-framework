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

# fw_is_linked_worktree [dir] — exit 0 if DIR (default PROJECT_ROOT/$PWD) is a *linked*
# git worktree (created via `git worktree add`), exit 1 if it's the main checkout or not a
# git repo. Discriminator: a linked worktree's git-dir (<main>/.git/worktrees/<name>)
# differs from its git-common-dir (<main>/.git); in the main checkout the two collapse to
# the same path. Used to suppress HOST-level drift checks (cron install state, self-vendor
# host snapshot) that are owned by the main checkout and false-FAIL in a transient worktree.
# Origin: T-2435 (OBS-077) — the pre-push audit false-FAILed on every worktree push.
fw_is_linked_worktree() {
    local dir="${1:-${PROJECT_ROOT:-$PWD}}"
    local gd gcd
    gd=$(git -C "$dir" rev-parse --git-dir 2>/dev/null) || return 1
    gcd=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
    # Absolute-ize relative forms (the main checkout returns ".git" for both → equal).
    case "$gd" in /*) ;; *) gd="$dir/$gd" ;; esac
    case "$gcd" in /*) ;; *) gcd="$dir/$gcd" ;; esac
    [ "$gd" != "$gcd" ]
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
