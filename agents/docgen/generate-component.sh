#!/usr/bin/env bash
# ============================================================================
# Component Reference Doc Generator
# T-364: Generates markdown reference docs from Component Fabric data
#
# Usage:
#   fw docs [component-card.yaml]
#   fw docs --all
#
# Output: docs/generated/components/{card-name}.md
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"

COMPONENTS_DIR="$FRAMEWORK_ROOT/.fabric/components"
OUTPUT_DIR="$FRAMEWORK_ROOT/docs/generated/components"
GENERATOR="$SCRIPT_DIR/generate_component.py"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p "$OUTPUT_DIR"

if [ "${1:-}" = "--all" ]; then
    echo -e "${CYAN}Generating reference docs for all components...${NC}"
    count=0
    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        python3 "$GENERATOR" "$card" "$FRAMEWORK_ROOT" "$OUTPUT_DIR"
        count=$((count + 1))
    done
    echo -e "${GREEN}Generated $count component reference docs in $OUTPUT_DIR${NC}"
elif [ -n "${1:-}" ]; then
    card="$1"
    [ -f "$card" ] || card="$COMPONENTS_DIR/$1"
    [ -f "$card" ] || card="$COMPONENTS_DIR/$1.yaml"
    if [ ! -f "$card" ]; then
        echo -e "${YELLOW}Card not found: $1${NC}" >&2
        exit 1
    fi
    python3 "$GENERATOR" "$card" "$FRAMEWORK_ROOT" "$OUTPUT_DIR"
else
    echo "Usage: fw docs [card.yaml | --all]"
    echo "  Generate reference docs from Component Fabric cards"
    echo ""
    echo "  --all              Generate for all components"
    echo "  card.yaml          Generate for a specific card"
fi
