#!/bin/bash
# Healing Agent - Antifragile error recovery and pattern learning
#
# Commands:
#   diagnose T-XXX    Analyze task issues, suggest recovery
#   resolve T-XXX     Mark issue resolved, log pattern
#   patterns          Show known failure patterns
#   suggest           Get suggestions for current issues
#
# Usage:
#   ./agents/healing/healing.sh diagnose T-015
#   ./agents/healing/healing.sh resolve T-015 --mitigation "Added retry logic"
#   ./agents/healing/healing.sh patterns

set -euo pipefail

VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
PATTERNS_FILE="$CONTEXT_DIR/project/patterns.yaml"
LIB_DIR="$SCRIPT_DIR/lib"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Show usage
show_usage() {
    echo "Healing Agent v$VERSION - Antifragile error recovery"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  diagnose T-XXX          Analyze task issues, suggest recovery"
    echo "  resolve T-XXX           Mark issue resolved, log pattern"
    echo "  patterns                Show known failure patterns"
    echo "  suggest                 Get suggestions for all tasks with issues"
    echo ""
    echo "Examples:"
    echo "  $0 diagnose T-015"
    echo "  $0 resolve T-015 --mitigation 'Added retry logic'"
    echo "  $0 patterns"
}

# Route to subcommand
case "${1:-}" in
    diagnose)
        shift
        source "$LIB_DIR/diagnose.sh"
        do_diagnose "$@"
        ;;
    resolve)
        shift
        source "$LIB_DIR/resolve.sh"
        do_resolve "$@"
        ;;
    patterns)
        shift
        source "$LIB_DIR/patterns.sh"
        do_patterns "$@"
        ;;
    suggest)
        shift
        source "$LIB_DIR/suggest.sh"
        do_suggest "$@"
        ;;
    -h|--help|help)
        show_usage
        exit 0
        ;;
    -v|--version)
        echo "Healing Agent v$VERSION"
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
