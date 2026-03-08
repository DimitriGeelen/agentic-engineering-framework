#!/usr/bin/env bash
# ============================================================================
# Subsystem Article Generator
# T-366: Assembles context from fabric + source + episodic, then generates
#        a deep-dive article via Ollama or outputs a prompt file.
#
# Usage:
#   fw docs article <subsystem>              # prompt file only
#   fw docs article <subsystem> --generate   # call Ollama
#   fw docs article --list                   # list subsystems
#
# Output:
#   Prompt: docs/generated/articles/{subsystem}-prompt.md
#   Article: docs/articles/deep-dives/{NN}-{subsystem}.md
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
GENERATOR="$SCRIPT_DIR/generate_article.py"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "${1:-}" = "--list" ]; then
    echo -e "${CYAN}Available subsystems:${NC}"
    python3 -c "
import yaml, glob, os
from collections import Counter
COMP_DIR = os.path.join('$FRAMEWORK_ROOT', '.fabric', 'components')
counts = Counter()
for f in glob.glob(os.path.join(COMP_DIR, '*.yaml')):
    with open(f) as fh:
        d = yaml.safe_load(fh)
    if d:
        counts[d.get('subsystem', 'unknown')] += 1
for s, c in counts.most_common():
    print(f'  {s} ({c} components)')
"
    exit 0
fi

if [ -z "${1:-}" ] || [ "${1:-}" = "--help" ]; then
    echo "Usage: fw docs article <subsystem> [--generate]"
    echo ""
    echo "  <subsystem>       Subsystem name (e.g., healing, context-fabric)"
    echo "  --generate        Call Ollama to produce article (default: prompt file only)"
    echo "  --list            List available subsystems"
    echo ""
    echo "Without --generate, writes a prompt file you can use with any LLM."
    exit 0
fi

SUBSYSTEM="$1"
shift
EXTRA_ARGS="$*"

echo -e "${CYAN}Assembling context for subsystem: $SUBSYSTEM${NC}"
python3 "$GENERATOR" "$SUBSYSTEM" "$FRAMEWORK_ROOT" $EXTRA_ARGS
