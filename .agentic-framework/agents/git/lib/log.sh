#!/bin/bash
# Git Agent - Log subcommand
# Task-filtered git log

do_log() {
    local task_filter=""
    local traceability=false
    local count=10

    while [[ $# -gt 0 ]]; do
        case $1 in
            --task|-t)
                task_filter="$2"
                shift 2
                ;;
            --traceability)
                traceability=true
                shift
                ;;
            -n)
                count="$2"
                shift 2
                ;;
            -h|--help)
                show_log_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    check_git_repo

    if [ "$traceability" = true ]; then
        show_traceability
        return
    fi

    if [ -n "$task_filter" ]; then
        echo -e "${CYAN}=== Commits for $task_filter ===${NC}"
        echo ""
        git -C "$PROJECT_ROOT" log --oneline -n "$count" --grep="$task_filter"
    else
        echo -e "${CYAN}=== Recent Commits ===${NC}"
        echo ""
        git -C "$PROJECT_ROOT" log --oneline -n "$count"
    fi
}

show_traceability() {
    echo -e "${CYAN}=== Git Traceability Report ===${NC}"
    echo ""

    local total_commits
    local task_commits

    total_commits=$(git -C "$PROJECT_ROOT" log --oneline | wc -l | tr -d ' ')
    task_commits=$(git -C "$PROJECT_ROOT" log --oneline | grep -cE "T-[0-9]+" || echo "0")

    if [ "$total_commits" -gt 0 ]; then
        local pct=$((task_commits * 100 / total_commits))
        echo "Total commits:     $total_commits"
        echo "With task ref:     $task_commits"
        echo "Traceability:      $pct%"
        echo ""

        # Show commits without task refs
        local orphans
        orphans=$(git -C "$PROJECT_ROOT" log --oneline | grep -vE "T-[0-9]+" || true)
        if [ -n "$orphans" ]; then
            echo -e "${YELLOW}Commits without task references:${NC}"
            echo "$orphans"
            echo ""
            echo "Log these with: ./agents/git/git.sh log-bypass --commit <SHA>"
        else
            echo -e "${GREEN}All commits have task references!${NC}"
        fi
    else
        echo "No commits found"
    fi
}

show_log_help() {
    cat << EOF
Git Agent - Log Command

Usage: git.sh log [options]

Options:
  -t, --task ID     Filter commits by task ID
  --traceability    Show task coverage statistics
  -n COUNT          Number of commits to show (default: 10)
  -h, --help        Show this help

Examples:
  git.sh log --task T-003
  git.sh log --traceability
  git.sh log -n 20
EOF
}
