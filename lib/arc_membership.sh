#!/usr/bin/env bash
# Canonical shell helper for arc-membership scans.
#
# T-1880 (T-NEW-15, arc-grooming): consolidates the union-of-`arc_id:`-
# frontmatter plus legacy `arc:<slug>`-tag scan that previously lived
# inline in three places (lib/arc.sh, agents/handover/handover.sh,
# lib/evolution_log.sh).
#
# Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — see L-397.
# Each consumer re-implemented the scan, so T-1850's migration left
# every inline reader returning zero for migrated arcs.
#
# Public API (all functions assume PROJECT_ROOT is set):
#   arc_tasks_with_arc_id <slug>     → T-IDs whose `arc_id:` matches slug
#   arc_tasks_with_tag <tag>         → T-IDs whose `tags:` line includes tag
#                                      (tag includes prefix, e.g. "arc:foo")
#   arc_tasks_for <slug>             → union of both, sorted uniq
#   task_has_arc_membership <path>   → exit 0 if frontmatter declares
#                                      arc_id OR arc:<slug> in tags
#
# All emit-list functions ALWAYS exit 0 — empty output is valid.
# Source this file: `. "$LIB_DIR/arc_membership.sh"` after PROJECT_ROOT
# is exported.

# Idempotent guard: re-sourcing must not redefine if PROJECT_ROOT path
# already set (some scripts source lib/arc.sh which sources this).
[ -n "${__ARC_MEMBERSHIP_SOURCED:-}" ] && return 0
__ARC_MEMBERSHIP_SOURCED=1

# Emit T-IDs for tasks whose frontmatter `arc_id:` matches the given slug.
# Tolerates leading whitespace + optional single/double quoting.
arc_tasks_with_arc_id() {
    local slug="$1"
    [ -n "$slug" ] || return 0
    [ -n "${PROJECT_ROOT:-}" ] || return 0
    {
        grep -lE "^[[:space:]]*arc_id:[[:space:]]*[\"']?${slug}[\"']?[[:space:]]*$" \
            "$PROJECT_ROOT"/.tasks/active/*.md 2>/dev/null || true
        grep -lE "^[[:space:]]*arc_id:[[:space:]]*[\"']?${slug}[\"']?[[:space:]]*$" \
            "$PROJECT_ROOT"/.tasks/completed/*.md 2>/dev/null || true
    } | while IFS= read -r f; do
        awk -F: '/^id:/ {gsub(/[ "]/,"",$2); print $2; exit}' "$f"
    done | sort -u
}

# Emit T-IDs for tasks whose frontmatter `tags:` line contains the given
# raw tag substring (include any prefix, e.g. `arc:foo`, `from-T-123`).
arc_tasks_with_tag() {
    local tag="$1"
    [ -n "$tag" ] || return 0
    [ -n "${PROJECT_ROOT:-}" ] || return 0
    {
        grep -lE "^tags:.*${tag}" "$PROJECT_ROOT"/.tasks/active/*.md 2>/dev/null || true
        grep -lE "^tags:.*${tag}" "$PROJECT_ROOT"/.tasks/completed/*.md 2>/dev/null || true
    } | while IFS= read -r f; do
        awk -F: '/^id:/ {gsub(/[ "]/,"",$2); print $2; exit}' "$f"
    done | sort -u
}

# Union of arc_id frontmatter + legacy arc:<slug> tag scan. Single entry
# point for "tasks belonging to arc <slug>".
arc_tasks_for() {
    local slug="$1"
    [ -n "$slug" ] || return 0
    {
        arc_tasks_with_arc_id "$slug"
        arc_tasks_with_tag "arc:${slug}"
    } | sort -u
}

# Per-task frontmatter check. Returns 0 if the file's frontmatter
# declares arc membership via EITHER `arc_id:` OR a `tags:` line with
# `arc:<slug>`. Returns 1 otherwise (incl. missing file).
#
# Scopes the check to the frontmatter block (lines between the two
# `---` markers) so `arc:` mentions in commit refs / narrative body
# don't produce false positives.
task_has_arc_membership() {
    local task_file="$1"
    [ -f "$task_file" ] || return 1
    awk '
        /^---$/ { fm++; next }
        fm == 1 && /^arc_id:[[:space:]]*["\047]?[A-Za-z0-9_-]+["\047]?[[:space:]]*$/ { found=1; exit }
        fm == 1 && /^tags:.*arc:[A-Za-z0-9_-]+/ { found=1; exit }
        fm >= 2 { exit }
        END { exit (found ? 0 : 1) }
    ' "$task_file"
}
