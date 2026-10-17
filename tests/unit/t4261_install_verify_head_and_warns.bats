#!/usr/bin/env bats
# T-4261: install.sh verify() must (1) not hide fw doctor WARNs behind a green
# "doctor passes" line, and (2) fail the summary + exit non-zero when the
# project has no HEAD (bootstrap commit did not land). Origin: 0909 run F-17/F-07.

bats_require_minimum_version 1.5.0

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT/install.sh"

setup() {
    TEST_HOME=$(mktemp -d)
    TEST_TARGET=$(mktemp -d)
    # Own repo, so an enclosing repo (e.g. a commit-less /.git) cannot stand in.
    git init -q "$TEST_TARGET"
    SHIM=$(mktemp -d)
    CURRENT_BRANCH="$(git -C "$FRAMEWORK_ROOT" rev-parse --abbrev-ref HEAD)"
    REAL_GIT="$(command -v git)"
    # git shim: `git ... commit ...` fails (simulates a failed bootstrap
    # commit); everything else passes through.
    cat > "$SHIM/git" <<EOF
#!/bin/bash
for a in "\$@"; do
    if [[ "\$a" == "commit" ]]; then echo "shim: commit refused" >&2; exit 1; fi
done
exec "$REAL_GIT" "\$@"
EOF
    chmod +x "$SHIM/git"
}

teardown() {
    rm -rf "$TEST_HOME" "$TEST_TARGET" "$SHIM"
}

run_install() {
    local extra_path="$1"
    # Identity is supplied so the bootstrap commit can land; WITHOUT it the
    # commit fails (T-4251 owns that git-init behaviour) and the new HEAD
    # check correctly reports it.
    env -i HOME="$TEST_HOME" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        PATH="${extra_path}/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        bash "$INSTALL" "$TEST_TARGET" --local "$FRAMEWORK_ROOT" --branch "$CURRENT_BRANCH" --no-scan
}

@test "T-4261: no HEAD (bootstrap commit failed) fails the summary and exits non-zero" {
    [[ "$CURRENT_BRANCH" == "HEAD" ]] && skip "detached HEAD"
    run run_install "$SHIM:"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no HEAD"* ]]
    [[ "$output" != *"All verification steps passed"* ]]
}

@test "T-4261: healthy install still passes and reports doctor warnings honestly" {
    [[ "$CURRENT_BRANCH" == "HEAD" ]] && skip "detached HEAD"
    run run_install ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"All verification steps passed"* ]]
    [[ "$output" == *"Bootstrap commit present"* ]]
    # Never the old unconditional claim when doctor has WARNs.
    if [[ "$output" == *"warning(s)"* ]]; then
        [[ "$output" != *"fw doctor passes ✓"* ]]
    fi
}
