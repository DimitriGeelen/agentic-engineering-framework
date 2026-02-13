#!/bin/bash
# Git Agent - Structural Enforcement for Git Operations
# Ensures every commit connects to a task (T-XXX pattern)

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source common utilities
source "$LIB_DIR/common.sh"

# Version for hook compatibility checking
VERSION="1.0"

show_help() {
    cat << EOF
Git Agent - Structural Enforcement for Git Operations
Version: $VERSION

Usage: git.sh <command> [options]

Commands:
  commit        Commit with task reference validation
  status        Task-aware git status
  install-hooks Install pre-commit and post-commit hooks
  log-bypass    Record a bypass in the bypass log
  log           Task-filtered git log
  help          Show this help

Examples:
  git.sh commit -m "T-003: Add bypass log"
  git.sh commit -t T-003 -m "Add bypass log"
  git.sh commit --bypass -m "Emergency fix"
  git.sh status
  git.sh install-hooks
  git.sh log-bypass --commit acb4594 --reason "Bootstrap exception"
  git.sh log --task T-003

For command-specific help:
  git.sh <command> --help
EOF
}

# Route to subcommands
case "${1:-}" in
    commit)
        shift
        source "$LIB_DIR/commit.sh"
        do_commit "$@"
        ;;
    status)
        shift
        source "$LIB_DIR/status.sh"
        do_status "$@"
        ;;
    install-hooks)
        shift
        source "$LIB_DIR/hooks.sh"
        do_install_hooks "$@"
        ;;
    log-bypass)
        shift
        source "$LIB_DIR/bypass.sh"
        do_log_bypass "$@"
        ;;
    log)
        shift
        source "$LIB_DIR/log.sh"
        do_log "$@"
        ;;
    help|--help|-h)
        show_help
        exit 0
        ;;
    "")
        show_help
        exit 0
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run 'git.sh help' for usage"
        exit 1
        ;;
esac
