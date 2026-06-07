#!/bin/bash
# lib/render_surface.sh
#
# Render-surface predicate (T-1766, P-013). Decides whether a task touches
# the human-review rendering surface — surfaces where what the human sees
# depends on layout/CSS/template choices that no deterministic test can
# fully capture.
#
# Contract: a "render surface" file is one whose change affects what a
# human sees on a Watchtower review/task/inception/approvals page. The
# subjective question — "does this look right?" — must be answered by
# eyes, not by tests. Tasks touching these files must declare at least
# one [REVIEW] Human AC so the human review path catches the visual
# layer.
#
# Single source of truth: RENDER_SURFACE_PATTERNS. Other consumers
# (lint checks, audit, future CI) source this lib instead of duplicating
# the pattern list. Drift between consumers was the T-1764 root cause.
#
# Public API:
#
#   task_touches_render_surface <task_file>
#       Return 0 (yes) if task's frontmatter `components`, body file
#       references, or `## Verification` block mention any path matching
#       RENDER_SURFACE_PATTERNS. Return 1 (no) otherwise.
#
#   render_surface_files_in <task_file>
#       Print one matched render-surface path per line.

# Guard against double-sourcing
[[ -n "${_FW_RENDER_SURFACE_LOADED:-}" ]] && return 0
_FW_RENDER_SURFACE_LOADED=1

# Render-surface path patterns (glob-style, matched as bash extglob via
# `case` statements). Single source of truth for any consumer that needs
# to know "does this file affect the human-review render?"
#
# Adding a new pattern? Update the list AND extend
# tests/unit/test_render_surface_gate.bats with a fixture covering it.
RENDER_SURFACE_PATTERNS=(
    "web/templates/*.html"
    "web/templates/*.j2"
    "web/static/*.css"
    "web/static/*.js"
    "web/blueprints/*.py"
    "web/shared.py"
    "web/app.py"
    "web/embeddings.py"
    "web/search.py"
    "web/search_utils.py"
)


_render_surface_path_matches() {
    local path="$1"
    local pat
    for pat in "${RENDER_SURFACE_PATTERNS[@]}"; do
        # shellcheck disable=SC2053  # glob match intentional
        case "$path" in
            $pat) return 0 ;;
        esac
    done
    return 1
}


_render_surface_extract_task_id() {
    # Echo the task id (e.g. T-2056) from a task file's frontmatter or filename.
    local task_file="$1"
    local tid
    # Prefer frontmatter id: T-NNN
    tid=$(awk '/^---$/{n++; next} n==1 && /^id:[[:space:]]*T-[0-9]+/{print $2; exit}' "$task_file" 2>/dev/null)
    if [[ -z "$tid" ]]; then
        # Fall back to filename T-NNN-*.md
        tid=$(basename "$task_file" 2>/dev/null | grep -oE '^T-[0-9]+' | head -1)
    fi
    echo "$tid"
}

_render_surface_git_touched_paths() {
    # Echo (one per line) every file touched by any commit whose message
    # references the given task id. Searches all branches/reflog so we don't
    # miss commits made on side branches before merge. Returns empty when:
    #   - $1 is empty
    #   - git is unavailable or cwd is not a git tree
    #   - no commits reference the task id (brand-new task, first-close case)
    local task_id="$1"
    [[ -z "$task_id" ]] && return 0
    # --all sweeps every ref; --pretty=format: suppresses commit headers so
    # only file names print; -- . scopes to tracked paths.
    git log --all --pretty=format: --name-only --grep "$task_id" -- . 2>/dev/null \
        | awk 'NF' | sort -u
}

_render_surface_body_candidates() {
    # Fallback: body + components scan (the legacy primary signal).
    # Used only when git evidence is empty — preserves first-close and test
    # fixture behaviour. Body-text mentions on tasks WITH git history are
    # ignored to fix L-435 false-positive class (T-2061).
    local task_file="$1"
    python3 - "$task_file" <<'PY'
import re, sys, yaml
fp = sys.argv[1]
with open(fp) as f:
    text = f.read()

# Frontmatter components list
fm_match = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
components = []
if fm_match:
    try:
        fm = yaml.safe_load(fm_match.group(1)) or {}
        comps = fm.get("components", []) or []
        if isinstance(comps, list):
            components = [str(c).strip() for c in comps if c]
    except Exception:
        pass

# Body file references — any token matching a path-like shape.
# Conservative: only relative paths starting with a known repo dir.
body = text[fm_match.end():] if fm_match else text
body_paths = re.findall(
    r"(?:^|[\s`'\"\(])((?:web|lib|bin|agents|tests|tools|prompts|policy|deploy|docs|\.tasks|\.context|\.fabric)/[A-Za-z0-9_/.-]+\.(?:html|j2|css|js|py|md|yaml|yml|sh|bats|json|toml))",
    body
)
candidates = list(dict.fromkeys(components + body_paths))
print("\n".join(candidates))
PY
}

task_touches_render_surface() {
    local task_file="$1"
    [[ -f "$task_file" ]] || return 1

    # Primary signal: git history (T-2061, L-435 fix). The body-text scan
    # cannot distinguish "task modifies X" from "task discusses X" — a task
    # whose entire point is "X is intentionally untouched" still trips the
    # gate because the path token appears in prose. Commits are authoritative:
    # they reflect what was actually modified, not what was talked about.
    local task_id
    task_id=$(_render_surface_extract_task_id "$task_file")
    local git_files
    git_files=$(_render_surface_git_touched_paths "$task_id")

    if [[ -n "$git_files" ]]; then
        local p
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            if _render_surface_path_matches "$p"; then
                return 0
            fi
        done <<< "$git_files"
        return 1
    fi

    # Fallback: body + components scan (legacy behaviour). Fires when git
    # evidence is empty — brand-new task being closed in the same commit
    # it's filed, test fixtures with synthetic task ids not in git log.
    local found
    found=$(_render_surface_body_candidates "$task_file")
    [[ -z "$found" ]] && return 1

    local p
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        if _render_surface_path_matches "$p"; then
            return 0
        fi
    done <<< "$found"
    return 1
}


render_surface_files_in() {
    local task_file="$1"
    [[ -f "$task_file" ]] || return 1

    # Mirror task_touches_render_surface's source-selection: git evidence
    # is primary; body+components is fallback when git has nothing.
    local task_id git_files
    task_id=$(_render_surface_extract_task_id "$task_file")
    git_files=$(_render_surface_git_touched_paths "$task_id")

    local found
    if [[ -n "$git_files" ]]; then
        found="$git_files"
    else
        found=$(_render_surface_body_candidates "$task_file")
    fi

    local p
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        if _render_surface_path_matches "$p"; then
            echo "$p"
        fi
    done <<< "$found"
}
