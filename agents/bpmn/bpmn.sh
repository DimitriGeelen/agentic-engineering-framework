#!/usr/bin/env bash
# fw bpmn — BPMN process diagram → AEF task compiler (Child-2 forward bridge).
# Thin wrapper: routes `compile` to tools/bpmn_to_tasks.py. See agents/bpmn/AGENT.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FW_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
COMPILER="$FW_ROOT/tools/bpmn_to_tasks.py"

usage() {
  cat <<'USAGE'
fw bpmn — BPMN process diagram → AEF task compiler (Child-2 forward bridge)

Usage:
  fw bpmn compile <file.bpmn>   Compile a BPMN diagram to AEF task skeletons (stdout)
  fw bpmn help                  Show this help

The compiler extracts task nodes + aef:uid (IW-1 keystone), maps lane→owner
(IW-7, owner-from-lane), and flow-order→horizon + related_tasks (T-2532).
Output is AEF task-skeleton YAML frontmatter, one block per task node.
USAGE
}

cmd="${1:-help}"
case "$cmd" in
  compile)
    shift
    if [ "$#" -lt 1 ]; then
      echo "error: 'compile' needs a <file.bpmn> argument" >&2
      usage
      exit 2
    fi
    if [ ! -f "$COMPILER" ]; then
      echo "error: compiler not found at $COMPILER" >&2
      exit 1
    fi
    exec python3 "$COMPILER" "$1"
    ;;
  help|-h|--help|"")
    usage
    ;;
  *)
    echo "error: unknown subcommand '$cmd'" >&2
    usage
    exit 2
    ;;
esac
