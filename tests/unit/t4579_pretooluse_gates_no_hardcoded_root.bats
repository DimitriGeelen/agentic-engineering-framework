#!/usr/bin/env bats
# T-4579: tests/governance/test_pretooluse_gates.bats built its hook inputs with
# file_path literals under the origin host's checkout path. In any clone at
# another path the project root is the clone, so check-active-task and
# check-project-boundary correctly treated those paths as outside the project and
# the two ALLOWS tests went red (reproduced in a clean clone under env -i).
# Every in-project path a hook input names must be built from $FRAMEWORK_ROOT.

ROOT="${BATS_TEST_DIRNAME}/../.."
GATES="$ROOT/tests/governance/test_pretooluse_gates.bats"

@test "T-4579: no hook input names the origin host's checkout path" {
    # T-4592: the origin path is test data, so it is passed inline, never assigned
    # (an assignment reads as a root default to no-hardcoded-checkout-root.bats).
    run grep -nF "/opt/999-Agentic-Engineering-""Framework" "$GATES"
    [ "$status" -eq 1 ]
}

@test "T-4579: every absolute file_path in a hook input is \$FRAMEWORK_ROOT or the deliberate outside path" {
    # Pull every file_path value (single- or double-quoted JSON) and keep the
    # absolute ones that are neither \$FRAMEWORK_ROOT-based nor /etc/passwd
    # (the boundary test's intentional outside path).
    bad=$(grep -oE 'file_path\\?":\\?"[^"\\]*' "$GATES" \
        | sed -E 's/^file_path\\?":\\?"//' \
        | grep -E '^/' | grep -vxF '/etc/passwd' || true)
    [ -z "$bad" ] || { echo "hard-coded file_path: $bad"; false; }
    # The positive control: the ALLOWS tests really do use \$FRAMEWORK_ROOT.
    grep -qF 'file_path\":\"$FRAMEWORK_ROOT/test.txt' "$GATES"
    grep -qF 'file_path\":\"$FRAMEWORK_ROOT/.context/working/test.yaml' "$GATES"
}
