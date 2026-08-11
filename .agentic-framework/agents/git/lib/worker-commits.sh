#!/bin/bash
# Git Agent - worker-commits subcommand (T-2917)
#
# Answers "what did autonomy commit on my behalf this week" without the
# operator needing to know the identity string or hand-roll a `git log
# --author` incantation. Filters on the dispatch-worker email shape minted by
# `lib/worker_identity.py:worker_git_env` / `lib/git-identity.sh:fw_worker_git_identity_env`
# (dispatch+<8-char-id>@aef.local) — anything matching that pattern is, by
# construction, a commit the operator did not type.

WORKER_EMAIL_PATTERN='dispatch\+[0-9a-f]+@aef\.local'

do_worker_commits() {
    local days=7
    local task_filter=""
    local json_out=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --days|-d)
                days="$2"
                shift 2
                ;;
            --task|-t)
                task_filter="$2"
                shift 2
                ;;
            --json)
                json_out=true
                shift
                ;;
            -h|--help)
                show_worker_commits_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    check_git_repo

    local -a grep_args=(-i -E "--author=$WORKER_EMAIL_PATTERN" \
        --since="$days days ago" \
        --pretty=format:'%H%x1f%aI%x1f%an%x1f%ae%x1f%s')
    if [ -n "$task_filter" ]; then
        grep_args+=(--grep="$task_filter")
    fi

    local log_out
    log_out=$(git -C "$PROJECT_ROOT" log "${grep_args[@]}" 2>/dev/null || true)

    if [ -z "$log_out" ]; then
        if [ "$json_out" = true ]; then
            echo "[]"
        else
            echo -e "${CYAN}=== Worker commits (last $days days) ===${NC}"
            echo "None — no commits with a dispatch-worker identity in this window."
        fi
        return 0
    fi

    if [ "$json_out" = true ]; then
        _worker_commits_json "$log_out"
        return 0
    fi

    echo -e "${CYAN}=== Worker commits (last $days days) ===${NC}"
    echo ""
    printf '%-8s  %-20s  %-24s  %-10s  %s\n' "SHA" "DATE" "MECHANISM" "DISPATCH" "SUBJECT"
    local line
    while IFS=$'\x1f' read -r sha date author email subject; do
        [ -z "$sha" ] && continue
        local short_sha="${sha:0:8}"
        local mechanism
        mechanism=$(echo "$author" | sed -E 's/^fw worker \((.*)\)$/\1/')
        local dispatch_short
        dispatch_short=$(echo "$email" | sed -E 's/^dispatch\+([0-9a-f]+)@aef\.local$/\1/')
        printf '%-8s  %-20s  %-24s  %-10s  %s\n' "$short_sha" "${date:0:19}" "$mechanism" "$dispatch_short" "$subject"
    done <<< "$log_out"
    echo ""
    local count
    count=$(echo "$log_out" | grep -c '^' || echo 0)
    echo "$count worker commit(s) in the last $days days."
    echo "Full row (task_id, outcome): fw resolver explain <dispatch_short>  (best-effort — short id may not be unique)"
}

_worker_commits_json() {
    local log_out="$1"
    echo "["
    local first=true
    while IFS=$'\x1f' read -r sha date author email subject; do
        [ -z "$sha" ] && continue
        local mechanism dispatch_short
        mechanism=$(echo "$author" | sed -E 's/^fw worker \((.*)\)$/\1/')
        dispatch_short=$(echo "$email" | sed -E 's/^dispatch\+([0-9a-f]+)@aef\.local$/\1/')
        local esc_subject
        esc_subject=$(echo "$subject" | sed 's/\\/\\\\/g; s/"/\\"/g')
        [ "$first" = true ] && first=false || echo ","
        printf '  {"sha": "%s", "date": "%s", "mechanism": "%s", "dispatch_id_prefix": "%s", "subject": "%s"}' \
            "$sha" "$date" "$mechanism" "$dispatch_short" "$esc_subject"
    done <<< "$log_out"
    echo ""
    echo "]"
}

show_worker_commits_help() {
    cat << EOF
Git Agent - Worker Commits Command (T-2917)

Lists commits made under a dispatch-worker git identity — i.e. commits the
operator did not type. Answers "what did the loop commit on my behalf?"

Usage: git.sh worker-commits [options]

Options:
  -d, --days N      Look back N days (default: 7)
  -t, --task ID     Filter to commits referencing task ID
  --json            Machine-readable JSON array
  -h, --help        Show this help

Examples:
  git.sh worker-commits
  git.sh worker-commits --days 30
  git.sh worker-commits --task T-2917
  git.sh worker-commits --json
EOF
}
