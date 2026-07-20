#!/usr/bin/env bash
# fw bpmn — BPMN process diagram → AEF task compiler (Child-2 forward bridge).
# Thin wrapper: routes `compile` to tools/bpmn_to_tasks.py. See agents/bpmn/AGENT.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FW_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
COMPILER="$FW_ROOT/tools/bpmn_to_tasks.py"
PROMOTER="$FW_ROOT/tools/bpmn_promote.py"

usage() {
  cat <<'USAGE'
fw bpmn — BPMN process diagram → AEF task compiler (Child-2 forward bridge)

Usage:
  fw bpmn compile <file.bpmn>          Compile a BPMN diagram to AEF task skeletons (stdout)
  fw bpmn compile --write <file.bpmn>  Also stage uid-keyed proposals to .context/bpmn-staged/
                                       (proposals, NOT tasks — promote separately; T-2539)
  fw bpmn promote <uid|all>            Promote staged proposals to real .tasks/ files via the
                                       gated writer (owner:human + captured). DRY-RUN default.
  fw bpmn promote <uid|all> --write    Execute the promotion (delegates to fw task create; T-2542)
  fw bpmn claim <uuid> <project>       Bind a pending ghost uuid to a live designer-store project
                                       (T-2575: uuid → meta.json, ghost → claims[] audit; every
                                       referring workflowRef connector resolves with zero edits)
  fw bpmn help                  Show this help

The compiler extracts task nodes + aef:uid (IW-1 keystone), maps lane→owner
(IW-7, owner-from-lane), and flow-order→horizon + related_tasks (T-2532).
Output is AEF task-skeleton YAML frontmatter, one block per task node.

`promote` reconciles idempotently on (uid, source_bpmn_sha) per 832's IW-2 contract:
new→create, unchanged→no-op, changed→refuse-clobber if human-touched, deleted→orphan+flag.
The .tasks/ write NEVER leaves the task-gate perimeter — it goes through `fw task create`.
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
    # Forward all args (e.g. --write) — the compiler parses them.
    exec python3 "$COMPILER" "$@"
    ;;
  promote)
    shift
    if [ "$#" -lt 1 ]; then
      echo "error: 'promote' needs a <uid|all> argument" >&2
      usage
      exit 2
    fi
    if [ ! -f "$PROMOTER" ]; then
      echo "error: promoter not found at $PROMOTER" >&2
      exit 1
    fi
    # Forward all args (uid|all, --write, --stage-dir) — the promoter parses them.
    exec python3 "$PROMOTER" "$@"
    ;;
  claim)
    shift
    if [ "$#" -lt 2 ]; then
      echo "error: 'claim' needs <uuid> <project> arguments" >&2
      usage
      exit 2
    fi
    # Explicit-claim-only contract (T-2571 IW-4, rail offsets 110/111): binds an
    # existing ghost uuid — never re-mints, never name-matches. Store resolved
    # from the project root so claim works from any cwd.
    exec python3 - "$1" "$2" <<PYEOF
import sys
sys.path.insert(0, "$FW_ROOT")
from pathlib import Path
from web.designer_registry import ClaimError, claim_ghost

try:
    r = claim_ghost(Path("$FW_ROOT/.context/designer/projects"), sys.argv[1], sys.argv[2])
except ClaimError as e:
    print(f"error: {e}", file=sys.stderr)
    sys.exit(1)
print(
    f"claimed: {r['uuid']} -> {r['project']} "
    f"({r['resolved_referrers']} referring connector(s) now resolve)"
)
PYEOF
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
