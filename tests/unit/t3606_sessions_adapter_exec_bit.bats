#!/usr/bin/env bats
# T-3606: `fw sessions` execs agents/sessions/<provider>/list.sh and refuses
# when it is not executable (bin/fw `[ -x "$_sess_adapter" ]`). The claude-code
# adapter was committed 100644, so the exec bit lived only in the author's
# working tree and every fresh checkout / vendored copy was broken.
#
# Assert the GIT INDEX mode, not only the on-disk mode: the on-disk check is
# green on the author's tree, which is exactly how this shipped.

load ../test_helper

@test "every sessions adapter is indexed 100755 in git" {
    cd "$FRAMEWORK_ROOT"
    run git ls-files -s -- 'agents/sessions/*/list.sh'
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    bad=$(echo "$output" | awk '$1 != "100755" {print $4}')
    if [ -n "$bad" ]; then
        echo "adapter(s) not indexed 100755: $bad"
        return 1
    fi
}

@test "every sessions adapter is executable on disk" {
    cd "$FRAMEWORK_ROOT"
    for f in agents/sessions/*/list.sh; do
        [ -x "$f" ] || { echo "not executable: $f"; return 1; }
    done
}
