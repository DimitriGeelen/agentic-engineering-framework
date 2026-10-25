#!/usr/bin/env bats
# T-4736: `fw upgrade` prunes superseded Workflow Designer builds from the
# consumer ROOT vendor/designer/, but only the ones it can prove are AEF's own.
#
# 050 be.16 report: the root kept an untracked 0.25.0 and a tracked 0.14.0 next
# to the current 0.26.0, ~1.2 MB per pin bump. _self_vendor_designer prunes the
# vendored tree; nothing pruned the installed copy.
#
# Rule under test: delete a superseded root build only when it is untracked in
# the consumer's git AND byte-identical to the same-named build in the framework
# source's vendor/designer/. Tracked or unknown builds are listed and kept.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4736-XXXXXX)"
    REAL_FW="$FRAMEWORK_ROOT"
    export NO_COLOR=1
    DESIGNER_SH="$REAL_FW/agents/designer/designer.sh"
    source "$REAL_FW/lib/colors.sh"
    source "$REAL_FW/lib/upgrade.sh"
    source "$REAL_FW/lib/init.sh"

    PROJ="$TEST_TEMP_DIR/proj"
    SRC="$TEST_TEMP_DIR/src-fw"
    # The framework source publishes 0.8.0 and 0.9.0 (pin = 0.9.0).
    _put_build "$SRC" 0.8.0
    _put_build "$SRC" 0.9.0
    _put_build "$PROJ/.agentic-framework" 0.9.0
    mkdir -p "$PROJ/.agentic-framework/bin"
    cat > "$PROJ/.agentic-framework/bin/fw" <<SHIM
#!/usr/bin/env bash
[ "\$1" = "designer" ] || { echo "unexpected: \$*" >&2; exit 99; }
exec env PROJECT_ROOT="\${PROJECT_ROOT}" FRAMEWORK_ROOT="$PROJ/.agentic-framework" \\
    bash "$DESIGNER_SH" "\$2"
SHIM
    chmod +x "$PROJ/.agentic-framework/bin/fw"
    git -C "$PROJ" init -q
    git -C "$PROJ" config user.email t@t
    git -C "$PROJ" config user.name t
    mkdir -p "$PROJ/vendor/designer"
    FRAMEWORK_ROOT="$SRC"
}

teardown() {
    FRAMEWORK_ROOT="$REAL_FW"
    [ -d "${TEST_TEMP_DIR:-}" ] && chmod -R u+w "$TEST_TEMP_DIR" 2>/dev/null
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# _put_build <root> <version>: build under <root>; the pin names the last one put.
_put_build() {
    local root="$1" ver="$2" sha
    mkdir -p "$root/policy" "$root/vendor/designer"
    printf 'DESIGNER-BUILD-%s' "$ver" > "$root/vendor/designer/aef-workflow-designer-$ver.html"
    sha="$(sha256sum "$root/vendor/designer/aef-workflow-designer-$ver.html" | cut -d' ' -f1)"
    cat > "$root/policy/designer-pin.yaml" <<EOF
version: "$ver"
sha256: "$sha"
bytes: 21
vendored_path: "vendor/designer/aef-workflow-designer-$ver.html"
EOF
}

# A root build with the given bytes, 0444 as the installer leaves it.
_root_build() {
    printf '%s' "$2" > "$PROJ/vendor/designer/aef-workflow-designer-$1.html"
    chmod 0444 "$PROJ/vendor/designer/aef-workflow-designer-$1.html"
}

@test "pin bump: untracked old build identical to the published one is pruned" {
    _root_build 0.8.0 'DESIGNER-BUILD-0.8.0'
    run _t4672_sync_designer "$PROJ" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"PRUNED"*"aef-workflow-designer-0.8.0.html"* ]]
    [ -f "$PROJ/vendor/designer/aef-workflow-designer-0.9.0.html" ]
    [ ! -e "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html" ]
}

@test "already current (050 shape): the leftover untracked build is still pruned" {
    _root_build 0.8.0 'DESIGNER-BUILD-0.8.0'
    cp "$SRC/vendor/designer/aef-workflow-designer-0.9.0.html" "$PROJ/vendor/designer/"
    run _t4672_sync_designer "$PROJ" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"PRUNED"*"0.8.0"* ]]
    [ ! -e "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html" ]
}

@test "tracked old build is listed with git rm and kept" {
    _root_build 0.8.0 'DESIGNER-BUILD-0.8.0'
    git -C "$PROJ" add vendor/designer/aef-workflow-designer-0.8.0.html
    git -C "$PROJ" commit -qm "track old designer"
    run _t4672_sync_designer "$PROJ" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"KEPT"*"aef-workflow-designer-0.8.0.html"*"tracked in git"*"git rm vendor/designer/aef-workflow-designer-0.8.0.html"* ]]
    [ -f "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html" ]
}

@test "unknown file with a designer-like name is listed and kept" {
    _root_build 0.8.0 'my own edits'
    _root_build 0.7.0 'DESIGNER-BUILD-0.7.0'   # no such published build in SRC
    run _t4672_sync_designer "$PROJ" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"KEPT"*"aef-workflow-designer-0.8.0.html"*"does not match any published AEF build"* ]]
    [[ "$output" == *"KEPT"*"aef-workflow-designer-0.7.0.html"* ]]
    [ -f "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html" ]
    [ -f "$PROJ/vendor/designer/aef-workflow-designer-0.7.0.html" ]
}

@test "--dry-run: names what it would prune and deletes nothing" {
    _root_build 0.8.0 'DESIGNER-BUILD-0.8.0'
    rm -rf "$PROJ/.agentic-framework/policy" "$PROJ/.agentic-framework/vendor"
    run _t4672_sync_designer "$PROJ" true
    [ "$status" -eq 0 ]
    [[ "$output" == *"WOULD PRUNE"*"aef-workflow-designer-0.8.0.html"* ]]
    [ -f "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html" ]
}

@test "refused install: nothing is pruned" {
    _root_build 0.8.0 'DESIGNER-BUILD-0.8.0'
    chmod u+w "$PROJ/.agentic-framework/vendor/designer/aef-workflow-designer-0.9.0.html"
    printf 'tampered' > "$PROJ/.agentic-framework/vendor/designer/aef-workflow-designer-0.9.0.html"
    run _t4672_sync_designer "$PROJ" false
    [ "$status" -eq 0 ]
    [ ! -e "$PROJ/vendor/designer/aef-workflow-designer-0.9.0.html" ]
    [ -f "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html" ]
    [[ "$output" != *"PRUNED"* ]]
}
