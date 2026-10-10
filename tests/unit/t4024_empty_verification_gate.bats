#!/usr/bin/env bats
# T-4024 (option D) — P-011 refuses a build/refactor/decommission close whose
# `## Verification` block yields 0 commands, unless the block carries
# `# verification: none — <reason>` (serviced via the ledger) or the Tier-2
# bypass FW_ALLOW_EMPTY_VERIFICATION=1 is set.
#
# Fixture shape lifted from t3546_p011_reports_the_zero.bats (bare temp project,
# not a git repo). Refusal is asserted on exit code AND message here, because
# the refusal exits before any downstream gate that could fail for other reasons.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" ] || \
        { echo "missing update-task.sh" >&2; return 1; }
}

teardown() {
    if [ -n "${P:-}" ]; then rm -rf "$P"; fi
    return 0
}

# _make_project WORKFLOW_TYPE KIND
#   comments : heading present, comments only
#   declared : comments + a valid declaration line
#   emptyrsn : declaration line with no reason
#   absent   : no Verification heading
_make_project() {
    local wf="$1" kind="$2"
    P="$(mktemp -d)"
    mkdir -p "$P/.tasks/active" "$P/.tasks/completed" "$P/.context/working"
    { printf -- '---\nid: T-9999\nname: "fixture"\nstatus: started-work\n'
      printf 'workflow_type: %s\nowner: agent\nhorizon: now\n' "$wf"
      printf 'created: 2026-08-31T00:00:00Z\nlast_update: 2026-08-31T00:00:00Z\n---\n\n'
      printf '# T-9999: fixture\n\n## Context\n\nx\n\n## Acceptance Criteria\n\n### Agent\n- [x] done\n\n'
      case "$kind" in
          comments) printf '## Verification\n\n# only a comment\n\n' ;;
          declared) printf '## Verification\n\n# verification: none — pure docs change, nothing executable\n\n' ;;
          hyphen)   printf '## Verification\n\n# verification: none -- docs only\n\n' ;;
          emptyrsn) printf '## Verification\n\n# verification: none —   \n\n' ;;
          placeholder) printf '## Verification\n\n# verification: none — <why nothing can be run>\n\n' ;;
          absent)   : ;;
      esac
      printf '## Decisions\n\n'; } > "$P/.tasks/active/T-9999-fixture.md"
}

_close() {
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        timeout 120 bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" \
        T-9999 --status work-completed 2>&1
}

_ledger() { echo "$P/.context/audits/verification-servicing.jsonl"; }

@test "empty block on a build task is REFUSED, naming the declaration and the bypass" {
    _make_project build comments
    run _close
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "BLOCKED"
    echo "$output" | grep -q "# verification: none"
    echo "$output" | grep -q "FW_ALLOW_EMPTY_VERIFICATION"
    [ ! -f "$(_ledger)" ]
}

@test "refactor and decommission are refused too" {
    _make_project refactor comments;     run _close; [ "$status" -ne 0 ]; rm -rf "$P"
    _make_project decommission comments; run _close; [ "$status" -ne 0 ]
}

@test "a declaration closes it and appends a ledger row with the reason" {
    _make_project build declared
    run _close
    echo "$output" | grep -q "declared none"
    ! echo "$output" | grep -q "BLOCKED"
    [ -f "$(_ledger)" ]
    run python3 -c '
import json,sys
r=json.loads(open(sys.argv[1]).readlines()[-1])
assert r["source"]=="declaration", r
assert r["reason"]=="pure docs change, nothing executable", r
assert r["task"]=="T-9999" and r["workflow_type"]=="build" and r["state"]=="open", r
assert isinstance(r["files"], list) and r["ts"].endswith("Z"), r
' "$(_ledger)"
    [ "$status" -eq 0 ]
}

@test "a double-hyphen declaration is accepted" {
    _make_project build hyphen
    run _close
    ! echo "$output" | grep -q "BLOCKED"
    grep -q '"source": "declaration"' "$(_ledger)"
}

@test "a declaration with an EMPTY reason is refused" {
    _make_project build emptyrsn
    run _close
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "BLOCKED"
    [ ! -f "$(_ledger)" ]
}

@test "the template hint copied verbatim (<placeholder> reason) is refused" {
    _make_project build placeholder
    run _close
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "BLOCKED"
    [ ! -f "$(_ledger)" ]
}

@test "FW_ALLOW_EMPTY_VERIFICATION=1 closes, logs Tier-2, ledger source bypass" {
    _make_project build comments
    FW_ALLOW_EMPTY_VERIFICATION=1 run _close
    ! echo "$output" | grep -q "BLOCKED"
    grep -q "FW_ALLOW_EMPTY_VERIFICATION" "$P/.context/working/.gate-bypass-log.yaml"
    grep -q '"source": "bypass"' "$(_ledger)"
    grep -q '"reason": "bypass"' "$(_ledger)"
}

@test "no Verification heading: unchanged skipped notice, not refused" {
    _make_project build absent
    run _close
    echo "$output" | grep -q "Verification: skipped"
    ! echo "$output" | grep -q "BLOCKED"
    [ ! -f "$(_ledger)" ]
}

@test "test and inception workflow types with an empty block: warning only" {
    _make_project test comments;      run _close
    echo "$output" | grep -q "yielded none"; ! echo "$output" | grep -q "BLOCKED"; rm -rf "$P"
    _make_project inception comments; run _close
    echo "$output" | grep -q "yielded none"; ! echo "$output" | grep -q "BLOCKED"
}
