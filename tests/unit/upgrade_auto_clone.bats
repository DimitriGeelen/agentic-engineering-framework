#!/usr/bin/env bats
# T-1634: tests for fw upgrade auto-clone path (bare-from-consumer).
#
# When fw upgrade is invoked from inside the consumer's vendored copy
# (FRAMEWORK_ROOT collapses to .agentic-framework/), instead of erroring
# we should:
#   1. Resolve upstream URL (--from-upstream > .framework.yaml upstream_repo)
#   2. Clone it to a tempdir
#   3. Hand off to that bin/fw upgrade $target_dir
#   4. Clean up the tempdir on exit

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a consumer fixture: proj/ with .framework.yaml and .agentic-framework/
# inside. The vendored copy has its own .git so cwd-collapse triggers the
# bare-from-consumer path in do_upgrade.
make_consumer_fixture() {
    local proj="$1"
    local upstream_repo="$2"
    mkdir -p "$proj/.agentic-framework"
    # Vendored copy as a git repo (own .git) — simulates post-`fw vendor` shape.
    (cd "$proj/.agentic-framework" && git init -q 2>/dev/null && \
        touch FRAMEWORK.md && git add FRAMEWORK.md && \
        git -c user.email=t@t -c user.name=t commit -q -m init 2>/dev/null)
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.4.0
provider: claude
upstream_repo: $upstream_repo
YAML
}

@test "upgrade: --help shows --from-upstream flag" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--from-upstream"* ]]
}

@test "upgrade: --from-upstream URL arg is parsed (no unknown-option error)" {
    # Passing --from-upstream with a value past --help should not error on arg parse.
    # --help wins (short-circuit return 0), so this just exercises the case branch.
    run do_upgrade --from-upstream "https://example.com/fw.git" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw upgrade"* ]]
}

@test "upgrade: bare-from-consumer with NO upstream_repo and NO --from-upstream — clear 3-path remediation" {
    local proj="$TEST_TEMP_DIR/no-upstream-proj"
    mkdir -p "$proj/.agentic-framework"
    (cd "$proj/.agentic-framework" && git init -q 2>/dev/null)
    # .framework.yaml without upstream_repo
    cat > "$proj/.framework.yaml" <<YAML
project_name: no-upstream-proj
version: 1.4.0
YAML
    # Collapse FRAMEWORK_ROOT to vendored copy to trigger bare-from-consumer
    local _saved_fw="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$proj/.agentic-framework"
    run do_upgrade "$proj"
    export FRAMEWORK_ROOT="$_saved_fw"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no upstream URL is known"* ]]
    [[ "$output" == *"Remediation"* ]]
    [[ "$output" == *"upstream_repo:"* ]]
    [[ "$output" == *"--from-upstream"* ]]
}

@test "upgrade: bare-from-consumer with upstream_repo in .framework.yaml — dry-run shows clone plan" {
    local proj="$TEST_TEMP_DIR/yaml-upstream-proj"
    make_consumer_fixture "$proj" "https://github.com/DimitriGeelen/agentic-engineering-framework.git"
    local _saved_fw="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$proj/.agentic-framework"
    run do_upgrade "$proj" --dry-run
    export FRAMEWORK_ROOT="$_saved_fw"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bare-from-consumer detected"* ]]
    [[ "$output" == *"https://github.com/DimitriGeelen/agentic-engineering-framework.git"* ]]
    [[ "$output" == *"would clone"* ]]
}

@test "upgrade: --from-upstream overrides .framework.yaml upstream_repo" {
    local proj="$TEST_TEMP_DIR/override-proj"
    make_consumer_fixture "$proj" "https://github.com/yaml-side/repo.git"
    local _saved_fw="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$proj/.agentic-framework"
    run do_upgrade "$proj" --from-upstream "https://github.com/flag-side/repo.git" --dry-run
    export FRAMEWORK_ROOT="$_saved_fw"
    [ "$status" -eq 0 ]
    [[ "$output" == *"flag-side/repo.git"* ]]
    [[ "$output" != *"yaml-side/repo.git"* ]]
}

@test "upgrade: GitHub shorthand (owner/repo) in upstream_repo is normalised to full URL" {
    local proj="$TEST_TEMP_DIR/shorthand-proj"
    make_consumer_fixture "$proj" "DimitriGeelen/agentic-engineering-framework"
    local _saved_fw="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$proj/.agentic-framework"
    run do_upgrade "$proj" --dry-run
    export FRAMEWORK_ROOT="$_saved_fw"
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://github.com/DimitriGeelen/agentic-engineering-framework.git"* ]]
}

@test "upgrade: bare-from-consumer with file:// upstream actually clones (live)" {
    # Build a local fixture upstream: a bare repo with a bin/fw that exits 0
    # — just to prove the clone happens and the hand-off invocation fires.
    local upstream_src="$TEST_TEMP_DIR/upstream-src"
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    mkdir -p "$upstream_src/bin"
    cat > "$upstream_src/bin/fw" <<'STUB'
#!/usr/bin/env bash
# Stub upstream fw — just echo what was invoked and exit 0
echo "STUB-UPSTREAM-FW invoked: $*"
exit 0
STUB
    chmod +x "$upstream_src/bin/fw"
    (cd "$upstream_src" && git init -q 2>/dev/null && git add . && \
        git -c user.email=t@t -c user.name=t commit -q -m seed 2>/dev/null)
    git clone --quiet --bare "$upstream_src" "$upstream_bare" 2>/dev/null

    local proj="$TEST_TEMP_DIR/live-proj"
    make_consumer_fixture "$proj" "file://$upstream_bare"
    local _saved_fw="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$proj/.agentic-framework"
    run do_upgrade "$proj"
    export FRAMEWORK_ROOT="$_saved_fw"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bare-from-consumer detected"* ]]
    [[ "$output" == *"Cloning"* ]]
    [[ "$output" == *"STUB-UPSTREAM-FW invoked: upgrade"* ]]
    [[ "$output" == *"$proj"* ]]
}
