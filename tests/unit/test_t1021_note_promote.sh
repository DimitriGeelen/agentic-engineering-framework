#!/usr/bin/env bash
# _t1027-note-promote-teeth.sh — `fw note promote` links an observation to the task it became.
#
# WHY (T-912, erased silently by the 1.7.740 re-vendor; found by the T-1020 census): promote wrote
# the literal string `promoted_to: task` — never an id — so nothing linked an observation to the
# task it turned into; it ignored create-task's exit code, so a failed creation still marked the
# observation promoted; and it created every task as owner: human, which the delegation surface
# then counts as a decision only the operator can close.
#
# Legs, on a scratch project driven through the real CLI (hermetic):
#   1. promoted_to records the created task id (T-NNNN), not the constant `task`
#   2. the created task carries `observation: OBS-NNN` (the reverse link)
#   3. the created task's owner is agent by default; --owner human is honoured
#   4. when task creation fails, the observation stays pending (not promoted to nothing)
# Exit 0 = all legs pass, 1 = a leg fails, 2 = cannot run.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# the framework repo itself (FRAMEWORK.md at root), else a vendored consumer
if [ -f "$ROOT/FRAMEWORK.md" ]; then FW_HOME="$ROOT"; else FW_HOME="$ROOT/.agentic-framework"; fi
FWR="${T1027_FRAMEWORK:-$FW_HOME}"
[ -x "$FWR/bin/fw" ] || { echo "CANNOT RUN: no fw at $FWR/bin/fw"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  PASS  $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL  $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /' | head -8; }

mkproj() {
  mkdir -p "$1/.tasks/active" "$1/.tasks/completed" "$1/.tasks/templates" "$1/.context/project" "$1/.context/working"
  cp "$ROOT/.tasks/templates/default.md" "$1/.tasks/templates/" 2>/dev/null || true
  printf 'project_name: t1027\n' > "$1/.framework.yaml"
  git -C "$1" init -q 2>/dev/null
}
fwp() { (cd "$1" && shift && PROJECT_ROOT="$PWD" FRAMEWORK_ROOT="$FWR" CLAUDECODE= "$FWR/agents/observe/observe.sh" "$@") 2>&1; }
obs_field() { # $1 inbox $2 obs $3 field
  python3 - "$1" "$2" "$3" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
for o in d.get('observations', []) or []:
    if o.get('id') == sys.argv[2]:
        print(o.get(sys.argv[3])); break
PY
}

echo "=== T-1027: fw note promote links observation <-> task ==="
P="$T/p"; mkproj "$P"
out=$(fwp "$P" "the save button sometimes does nothing" ); oid=$(printf '%s' "$out" | grep -oE 'OBS-[0-9]+' | head -1)
[ -n "$oid" ] || { echo "CANNOT RUN: capture produced no OBS id"; printf '%s\n' "$out" | head -5; exit 2; }
out=$(fwp "$P" promote "$oid")
INBOX="$P/.context/inbox.yaml"; [ -f "$INBOX" ] || INBOX=$(ls "$P"/.context/*inbox*.yaml 2>/dev/null | head -1)
pt=$(obs_field "$INBOX" "$oid" promoted_to)
if [[ "$pt" =~ ^T-[0-9]+$ ]]; then ok "promoted_to records the task id ($oid -> $pt)"
else bad "promoted_to records the task id (got '$pt')" "$out"; fi
tf=$(ls "$P"/.tasks/active/"$pt"-*.md 2>/dev/null | head -1)
if [ -n "$tf" ] && grep -q "^observation: $oid" "$tf"; then ok "the task carries the reverse link (observation: $oid)"
else bad "the task carries the reverse link" "$(head -12 "${tf:-/dev/null}")"; fi
if [ -n "$tf" ] && grep -q "^owner: agent" "$tf"; then ok "owner defaults to agent"
else bad "owner defaults to agent (got: $(grep '^owner:' "${tf:-/dev/null}"))"; fi

out=$(fwp "$P" "needs a person to judge the colour palette"); oid2=$(printf '%s' "$out" | grep -oE 'OBS-[0-9]+' | head -1)
out=$(fwp "$P" promote "$oid2" --owner human); pt2=$(obs_field "$INBOX" "$oid2" promoted_to)
tf2=$(ls "$P"/.tasks/active/"$pt2"-*.md 2>/dev/null | head -1)
if [[ "$pt2" =~ ^T-[0-9]+$ ]] && [ -n "$tf2" ] && grep -q "^owner: human" "$tf2"; then ok "--owner human is honoured ($oid2 -> $pt2)"
else bad "--owner human is honoured (promoted_to='$pt2')" "$out"; fi

out=$(fwp "$P" "this one cannot become a task"); oid3=$(printf '%s' "$out" | grep -oE 'OBS-[0-9]+' | head -1)
out=$(fwp "$P" promote "$oid3" --type no-such-type); st=$(obs_field "$INBOX" "$oid3" status); pt3=$(obs_field "$INBOX" "$oid3" promoted_to)
if [ "$st" = "pending" ] && { [ "$pt3" = "None" ] || [ -z "$pt3" ]; }; then ok "a failed creation leaves the observation pending"
else bad "a failed creation leaves the observation pending (status=$st promoted_to=$pt3)" "$out"; fi

echo "=== SUMMARY ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
