#!/bin/bash
# Fabric Agent - Component topology system for codebase self-awareness
#
# Commands:
#   register <path>     Create component card for a file
#   scan                Batch-create skeleton cards for unregistered files
#   search <keyword>    Search components by tags, name, purpose
#   get <component>     Show full component card
#   deps <file-path>    Show dependencies for a file (what it uses + what uses it)
#   impact <file-path>  Full transitive downstream chain
#   blast-radius [ref]  Downstream impact of a commit (default: HEAD)
#   ui <route>          Interactive elements on a route
#   drift               Detect unregistered, orphaned, and stale components
#   validate [id]       Deep-validate component edges
#   overview            Compact subsystem summary for onboarding
#   subsystem <id>      Drill into one subsystem
#   stats               Component count, edge count, coverage
#
# Usage:
#   fw fabric search "learnings"
#   fw fabric impact agents/context/lib/learning.sh
#   fw fabric blast-radius HEAD
#   fw fabric drift
#   fw fabric overview

set -euo pipefail

VERSION="0.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Resolve PROJECT_ROOT from git toplevel — framework/ is typically a subdirectory,
# not the project root. Fall back to FRAMEWORK_ROOT for standalone installs.
PROJECT_ROOT="${PROJECT_ROOT:-$(git -C "$FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$FRAMEWORK_ROOT")}"
FABRIC_DIR="$PROJECT_ROOT/.fabric"
COMPONENTS_DIR="$FABRIC_DIR/components"
LIB_DIR="$SCRIPT_DIR/lib"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Ensure fabric directory exists
ensure_fabric_dirs() {
    mkdir -p "$COMPONENTS_DIR"
}

show_usage() {
    echo -e "${BOLD}Fabric Agent${NC} v${VERSION} — Component topology system"
    echo ""
    echo "Usage: fw fabric <command> [args]"
    echo ""
    echo "Registration:"
    echo "  register <path>      Create component card for a file"
    echo "  scan                 Batch-create skeletons for unregistered files"
    echo ""
    echo "Navigation (UC-1):"
    echo "  search <keyword>     Search by tags, name, purpose"
    echo "  get <component>      Show full component card"
    echo "  deps <file-path>     Dependencies: what it uses + what uses it"
    echo ""
    echo "Impact (UC-2):"
    echo "  impact <file-path>   Full transitive downstream chain"
    echo ""
    echo "UI (UC-3):"
    echo "  ui <route>           Interactive elements on a route"
    echo ""
    echo "Onboarding (UC-4):"
    echo "  overview             Compact subsystem summary"
    echo "  subsystem <id>       Drill into one subsystem"
    echo ""
    echo "Regression (UC-5):"
    echo "  blast-radius [ref]   Downstream impact of commit (default: HEAD)"
    echo ""
    echo "Completeness (UC-6):"
    echo "  drift                Detect unregistered/orphaned/stale"
    echo "  validate [id]        Deep-validate component edges"
    echo ""
    echo "Enrichment:"
    echo "  enrich [--dry-run] [--subsystem X]  Auto-detect dependency edges"
    echo ""
    echo "Meta:"
    echo "  stats                Component count, edge count, coverage"
}

# Route to subcommand
case "${1:-}" in
    register)
        shift
        source "$LIB_DIR/register.sh"
        do_register "$@"
        ;;
    scan)
        shift
        source "$LIB_DIR/register.sh"
        do_scan "$@"
        ;;
    search)
        shift
        source "$LIB_DIR/query.sh"
        do_search "$@"
        ;;
    get)
        shift
        source "$LIB_DIR/query.sh"
        do_get "$@"
        ;;
    deps)
        shift
        source "$LIB_DIR/query.sh"
        do_deps "$@"
        ;;
    impact)
        shift
        source "$LIB_DIR/traverse.sh"
        do_impact "$@"
        ;;
    blast-radius)
        shift
        source "$LIB_DIR/traverse.sh"
        do_blast_radius "$@"
        ;;
    ui)
        shift
        source "$LIB_DIR/ui.sh"
        do_ui "$@"
        ;;
    drift)
        shift
        source "$LIB_DIR/drift.sh"
        do_drift "$@"
        ;;
    validate)
        shift
        source "$LIB_DIR/drift.sh"
        do_validate "$@"
        ;;
    overview)
        shift
        source "$LIB_DIR/summary.sh"
        do_overview "$@"
        ;;
    subsystem)
        shift
        source "$LIB_DIR/summary.sh"
        do_subsystem "$@"
        ;;
    stats)
        shift
        source "$LIB_DIR/summary.sh"
        do_stats "$@"
        ;;
    enrich)
        shift
        exec python3 "$LIB_DIR/enrich.py" "$@"
        ;;
    -h|--help|help)
        show_usage
        ;;
    "")
        show_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run 'fw fabric help' for usage"
        exit 1
        ;;
esac
