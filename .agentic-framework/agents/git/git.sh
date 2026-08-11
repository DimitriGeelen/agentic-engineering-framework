#!/bin/bash
# Git Agent - Structural Enforcement for Git Operations
# Ensures every commit connects to a task (T-XXX pattern)

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
LIB_DIR="$SCRIPT_DIR/lib"

# Source common utilities
source "$LIB_DIR/common.sh"

# The git agent's own version, shown by `fw git --help`.
#
# T-2852: this is NOT the hook-compatibility version and must not be compared
# against an installed hook's `# VERSION=` marker. It used to be — the comment
# here instructed the reader to keep this value equal to the commit-msg
# template's marker, and it drifted anyway (1.6 vs 1.11), which made the
# "already installed" short-circuit in lib/hooks.sh unreachable.
#
# Hook compatibility now lives with the templates it describes, as
# COMMIT_MSG_HOOK_VERSION in agents/git/lib/hooks.sh, pinned by
# tests/unit/hook_version_marker_parity.bats. Bump that one when you change a
# hook template (PL-078); this one tracks the agent.
VERSION="1.6"

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
  worker-commits What did autonomous dispatch commit on my behalf (T-2917)
  help          Show this help

Examples:
  git.sh commit -m "T-003: Add bypass log"
  git.sh commit -t T-003 -m "Add bypass log"
  git.sh commit --bypass -m "Emergency fix"
  git.sh status
  git.sh install-hooks
  git.sh log-bypass --commit acb4594 --reason "Bootstrap exception"
  git.sh log --task T-003
  git.sh worker-commits --days 7

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
    worker-commits)
        shift
        source "$LIB_DIR/worker-commits.sh"
        do_worker_commits "$@"
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
