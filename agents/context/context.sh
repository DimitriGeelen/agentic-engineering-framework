#!/bin/bash
# Context Agent - Manages the Context Fabric memory system
#
# Commands:
#   init          Initialize working memory for new session
#   status        Show current context state
#   add-learning  Add a new learning to project memory
#   add-pattern   Add a new pattern (failure/success/workflow)
#   add-decision  Add a decision to project memory
#   generate-episodic  Generate episodic summary for completed task
#   focus         Set or show current focus
#
# Usage:
#   ./agents/context/context.sh init
#   ./agents/context/context.sh status
#   ./agents/context/context.sh add-learning "Learning text" --task T-014 --source P-001
#   ./agents/context/context.sh add-pattern failure "Pattern name" --task T-013 --mitigation "How to avoid"
#   ./agents/context/context.sh generate-episodic T-014
#   ./agents/context/context.sh focus T-005

set -euo pipefail

VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
LIB_DIR="$SCRIPT_DIR/lib"

# Colors provided by lib/colors.sh (via paths.sh chain)

# Ensure context directories exist
ensure_context_dirs() {
    mkdir -p "$CONTEXT_DIR"/{working,project,episodic}
}

# Show usage
show_usage() {
    echo "Context Agent v$VERSION - Manages Context Fabric memory system"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init              Initialize working memory for new session"
    echo "  status            Show current context state"
    echo "  add-learning      Add a learning to project memory"
    echo "  add-pattern       Add a pattern (failure/success/workflow)"
    echo "  add-decision      Add a decision to project memory"
    echo "  generate-episodic Generate episodic summary for completed task"
    echo "  focus [task]      Set or show current focus"
    echo ""
    echo "Examples:"
    echo "  $0 init"
    echo "  $0 status"
    echo "  $0 add-learning 'Always validate inputs' --task T-014 --source P-001"
    echo "  $0 add-pattern failure 'API timeout' --task T-015 --mitigation 'Add retry logic'"
    echo "  $0 generate-episodic T-014"
    echo "  $0 focus T-005"
}

# Route to subcommand
case "${1:-}" in
    init)
        shift
        source "$LIB_DIR/init.sh"
        do_init "$@"
        ;;
    status)
        shift
        source "$LIB_DIR/status.sh"
        do_status "$@"
        ;;
    add-learning)
        shift
        source "$LIB_DIR/learning.sh"
        do_add_learning "$@"
        ;;
    add-pattern)
        shift
        source "$LIB_DIR/pattern.sh"
        do_add_pattern "$@"
        ;;
    add-decision)
        shift
        source "$LIB_DIR/decision.sh"
        do_add_decision "$@"
        ;;
    generate-episodic)
        shift
        source "$LIB_DIR/episodic.sh"
        do_generate_episodic "$@"
        ;;
    focus)
        shift
        source "$LIB_DIR/focus.sh"
        do_focus "$@"
        ;;
    -h|--help|help)
        show_usage
        exit 0
        ;;
    -v|--version)
        echo "Context Agent v$VERSION"
        exit 0
        ;;
    "")
        show_usage
        exit 1
        ;;
    *)
        error "Unknown command: $1"
        die "Run '$0 --help' for usage"
        ;;
esac
