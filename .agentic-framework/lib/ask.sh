#!/usr/bin/env bash
# fw ask — synchronous RAG+LLM wrapper (T-264)
#
# Usage:
#   fw ask "How do I create a task?"
#   fw ask --json "What is the healing loop?"
#   fw ask --concise "List enforcement tiers"
#   fw ask --think "Why does the healing agent fail?"

set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"

if [[ "${1:-}" == "" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: fw ask [OPTIONS] \"question\""
    echo ""
    echo "Options:"
    echo "  --json       Output as JSON"
    echo "  --concise    Brief answers (2-3 sentences)"
    echo "  --think      Force thinking mode"
    echo "  --no-think   Disable thinking mode"
    echo "  --limit N    Max chunks to retrieve (default: 10)"
    echo ""
    echo "Examples:"
    echo "  fw ask \"How do I create a task?\""
    echo "  fw ask --concise \"What is the healing loop?\""
    echo "  fw ask --json --think \"Why does the audit fail?\""
    exit 0
fi

export PROJECT_ROOT
exec python3 "$FRAMEWORK_ROOT/lib/ask.py" "$@"
