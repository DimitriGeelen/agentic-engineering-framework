#!/usr/bin/env bash
# _t1025-fabric-impact-teeth.sh — `fw fabric impact` must name a dependent recorded as a plain-string
# depends_on entry, and must REFUSE rather than print an empty chain when its traversal fails.
#
# WHY (T-908, lost silently by the 1.7.740 re-vendor; found by the T-1020 census): 24 of 704
# depends_on entries in this repo's cards are plain strings ("tools/x.py"), not {type,target}
# dicts. dep.get('type') raises on them, the traversal's stderr went to /dev/null, and the verb
# printed an EMPTY chain — which reads as "nothing depends on this file", the answer CLAUDE.md asks
# for before modifying a file. A crash rendered as reassurance.
#
# Two legs, both against a scratch fabric (hermetic):
#   1. with plain-string depends_on entries present in the corpus, the traversal still runs and
#      names a dependent recorded by a typed edge (it used to crash and print nothing at all);
#   2. a traversal that crashes (injected via a malformed card) produces a refusal and a
#      non-zero exit, never a clean-looking empty chain.
# Exit 0 = both legs pass, 1 = a leg fails, 2 = cannot run.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# the framework repo itself (FRAMEWORK.md at root), else a vendored consumer
if [ -f "$ROOT/FRAMEWORK.md" ]; then FW_HOME="$ROOT"; else FW_HOME="$ROOT/.agentic-framework"; fi
LIB="${T1025_TRAVERSE:-$FW_HOME/agents/fabric/lib/traverse.sh}"
[ -f "$LIB" ] || { echo "CANNOT RUN: traverse.sh not found at $LIB"; exit 2; }
FWR="$FW_HOME"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  PASS  $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL  $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /' | head -8; }

mkfab() { # $1 = dir
  mkdir -p "$1/.fabric/components" "$1/src"
  echo "x = 1" > "$1/src/target.py"; echo "import target" > "$1/src/user.py"
  cat > "$1/.fabric/components/src-target.yaml" <<'Y'
id: src/target.py
name: target
type: module
location: src/target.py
depends_on: []
Y
  cat > "$1/.fabric/components/src-user.yaml" <<'Y'
id: src/user.py
name: user
type: module
location: src/user.py
depends_on:
  - type: calls
    target: src/target.py
Y
  # An UNRELATED card carrying plain-string entries, as 24 of 704 do in this repo. Its mere
  # presence used to crash the whole traversal: the leg below goes red if it still does.
  echo "y = 2" > "$1/src/other.py"
  cat > "$1/.fabric/components/src-other.yaml" <<'Y'
id: src/other.py
name: other
type: module
location: src/other.py
depends_on:
  - src/target.py
  - git
Y
}

impact() { # $1 = project dir, $2 = file ; prints combined output, returns the traversal's rc
  PROJECT_ROOT="$1" FRAMEWORK_ROOT="$FWR" LIBF="$LIB" FILE="$2" bash -c '
    source "$FRAMEWORK_ROOT/lib/paths.sh" >/dev/null 2>&1
    PROJECT_ROOT="'"$1"'"; FABRIC_DIR="$PROJECT_ROOT/.fabric"; COMPONENTS_DIR="$FABRIC_DIR/components"
    RED=""; NC=""; GREEN=""; YELLOW=""; CYAN=""; BOLD=""
    ensure_fabric_dirs() { mkdir -p "$COMPONENTS_DIR"; }   # defined by fabric.sh, which this harness does not load
    source "$LIBF"; cd "$PROJECT_ROOT" && do_impact "$FILE"' 2>&1
}

echo "=== T-1025: fw fabric impact — string deps and loud failure ==="
echo "subject: $LIB"

P1="$T/p1"; mkfab "$P1"
out=$(impact "$P1" src/target.py); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "src/user.py"; then
  ok "plain-string entries in the corpus no longer crash the traversal: src/user.py is in the chain"
else
  bad "plain-string entries in the corpus must not empty the chain (rc=$rc; src/user.py not named)" "$out"
fi

P2="$T/p2"; mkfab "$P2"
printf 'id: broken\nlocation: src/user.py\ndepends_on: 7\n' > "$P2/.fabric/components/zz-broken.yaml"
out=$(impact "$P2" src/target.py); rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "IMPACT NOT COMPUTED"; then
  ok "a traversal that crashes is REFUSED (rc=$rc, 'IMPACT NOT COMPUTED'), not shown as an empty chain"
else
  bad "a crashing traversal must refuse loudly (rc=$rc)" "$out"
fi

echo "=== SUMMARY ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
