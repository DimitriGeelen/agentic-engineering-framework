#!/usr/bin/env bats
# T-5093 (GitHub #113) — the consumer CLAUDE.md template called plain `handover.sh` a "manual
# commit", while handover.sh commits AND pushes by default (AUTO_COMMIT=true; --no-commit turns
# it off). An agent that followed the template got a skeleton handover pushed before it could
# fill the [TODO] sections. Pin the template to the script's real behaviour.

ROOT() { echo "$BATS_TEST_DIRNAME/../.."; }
TPL() { echo "$(ROOT)/lib/templates/claude-project.md"; }
HO() { echo "$(ROOT)/agents/handover/handover.sh"; }

@test "handover.sh still commits by default and offers --no-commit (the facts the template states)" {
    grep -q '^AUTO_COMMIT=true' "$(HO)"
    grep -q -- '--no-commit) AUTO_COMMIT=false' "$(HO)"
}

@test "T-5093: the template no longer calls the plain call a manual commit" {
    run grep -n 'manual commit' "$(TPL)"
    [ "$status" -ne 0 ]
}

@test "T-5093: the template names --no-commit for writing without committing" {
    grep -q 'handover.sh --no-commit' "$(TPL)"
    grep -q 'fw handover --no-commit' "$(TPL)"
}

@test "T-5093: the Quick Reference says the plain command commits and pushes" {
    grep -q '| Handover, commit and push (default) | `fw handover` |' "$(TPL)"
}

@test "T-5093: the session-end list does not tell agents to fill [TODO]s after a pushing call" {
    run grep -n -A1 'Generate handover: `fw handover`$' "$(TPL)"
    [ "$status" -ne 0 ]
}
