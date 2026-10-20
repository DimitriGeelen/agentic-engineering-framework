#!/usr/bin/env bats
# T-4438: install.sh must not leak its agentic-fw-fetch-* clone when a run fails
# or is killed. install.sh:195 mktemp's INSTALL_DIR, and cleanup_fetch used to run
# only at the end of the success path, so any earlier exit left a 350 MB-2 GB
# shallow clone in /tmp. The fix registers the cleanup the moment this run
# creates the directory; a caller-supplied INSTALL_DIR is never removed.
#
# Failure is forced after the fetch: the fixture clone has no bin/fw, bin/fw-router
# or bin/fw-shim, so link_fw hits `fatal` before the explicit cleanup_fetch call.
# TMPDIR is private to this test, so the check cannot see the real /tmp.

bats_require_minimum_version 1.5.0

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT/install.sh"

setup_file() {
    CURRENT_BRANCH="$(git -C "$FRAMEWORK_ROOT" rev-parse --abbrev-ref HEAD)"
    export CURRENT_BRANCH
    [[ "$CURRENT_BRANCH" == "HEAD" ]] && return 0

    FIXTURE_REPO=$(mktemp -d)
    export FIXTURE_REPO
    git clone -q --depth 1 --branch "$CURRENT_BRANCH" --single-branch \
        "file://$FRAMEWORK_ROOT" "$FIXTURE_REPO"
    git -C "$FIXTURE_REPO" rm -q bin/fw bin/fw-router bin/fw-shim
    git -C "$FIXTURE_REPO" -c user.name=t -c user.email=t@example.com \
        commit -q -m "T-4438 fixture: no framework entry point, so link_fw fatals after fetch"

    REAL_GIT="$(command -v git)"
    export REAL_GIT
}

teardown_file() {
    [[ -n "${FIXTURE_REPO:-}" ]] && rm -rf "$FIXTURE_REPO"
    return 0
}

setup() {
    [[ "$CURRENT_BRANCH" == "HEAD" ]] && skip "detached HEAD -- --local install needs a real branch name"
    TEST_HOME=$(mktemp -d)
    TEST_TARGET=$(mktemp -d)
    git init -q "$TEST_TARGET"
    PRIV_TMP=$(mktemp -d)
    export PRIV_TMP
}

teardown() {
    rm -rf "${TEST_HOME:-}" "${TEST_TARGET:-}" "${PRIV_TMP:-}"
}

# Same env -i shape as t4248_install_init_failure.bats, plus a private TMPDIR so
# mktemp -t writes into PRIV_TMP and nowhere else.
run_install() {
    run env -i HOME="$TEST_HOME" \
        PATH="${EXTRA_PATH:+$EXTRA_PATH:}/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        TMPDIR="$PRIV_TMP" \
        GIT_CEILING_DIRECTORIES="$(dirname "$TEST_TARGET")" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        "$@" \
        bash "$INSTALL" "$TEST_TARGET" --local "$FIXTURE_REPO" --branch "$CURRENT_BRANCH" --no-scan
}

fetch_leftovers() {
    find "$PRIV_TMP" -maxdepth 1 -name 'agentic-fw-fetch-*' -print
}

@test "T-4438: forced failure after the fetch — install fails and leaves no agentic-fw-fetch-* dir" {
    run_install
    [[ "$output" == *"bin/fw not found"* ]]
    [[ "$output" != *"Installation complete!"* ]]
    [ "$status" -ne 0 ]
    [ -z "$(fetch_leftovers)" ]
}

@test "T-4438: TERM during the fetch — no agentic-fw-fetch-* dir, and the process dies by the signal" {
    # Fake git: on clone, signal install.sh (its parent) and linger. bash runs the
    # TERM trap once this foreground child returns, so the clone still completes
    # and then the trap has to clean it up.
    FAKEBIN="$PRIV_TMP/fakebin"
    mkdir -p "$FAKEBIN"
    cat > "$FAKEBIN/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == clone ]]; then kill -TERM "\$PPID"; sleep 1; fi
exec "$REAL_GIT" "\$@"
EOF
    chmod +x "$FAKEBIN/git"
    EXTRA_PATH="$FAKEBIN" run_install
    [ -z "$(fetch_leftovers)" ]
    [ "$status" -eq 143 ]
}

@test "T-4438: caller-supplied INSTALL_DIR survives a failed run" {
    CALLER_DIR="$PRIV_TMP/caller-fetch"
    mkdir -p "$CALLER_DIR"
    run_install INSTALL_DIR="$CALLER_DIR"
    [ "$status" -ne 0 ]
    [ -d "$CALLER_DIR/.git" ]
}
