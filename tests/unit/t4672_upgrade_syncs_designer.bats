#!/usr/bin/env bats
# T-4672: `fw upgrade` brings an INSTALLED Workflow Designer along with a pin bump.
#
# 832 field report (be.3): after fw upgrade, `fw designer status` said NOT SYNCED
# until `fw designer install` was run by hand. Upgrade refreshed the vendored pin
# and build (.agentic-framework/) but never the installed copy at
# <project>/<vendored_path>, which is what status and /designer read.
#
# Fixture: a consumer that had designer 0.8.0 installed, whose vendored tree now
# carries the 0.9.0 pin and build (the state right after step 4b's do_vendor), and
# a synthetic framework source carrying the same 0.9.0 pin (what --dry-run reads,
# because in a dry run the vendored pin has not moved yet). The pin sha256 is
# computed from the fixture, so the install path runs the real verification.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4672-XXXXXX)"
    REAL_FW="$FRAMEWORK_ROOT"
    export NO_COLOR=1
    DESIGNER_SH="$REAL_FW/agents/designer/designer.sh"
    source "$REAL_FW/lib/colors.sh"
    source "$REAL_FW/lib/upgrade.sh"
    source "$REAL_FW/lib/init.sh"

    PROJ="$TEST_TEMP_DIR/proj"
    SRC="$TEST_TEMP_DIR/src-fw"
    _put_build "$SRC" 0.9.0
    _put_build "$PROJ/.agentic-framework" 0.9.0
    # The vendored bin/fw routes `designer install` to the real script, as in t3064.
    mkdir -p "$PROJ/.agentic-framework/bin"
    cat > "$PROJ/.agentic-framework/bin/fw" <<SHIM
#!/usr/bin/env bash
[ "\$1" = "designer" ] || { echo "unexpected: \$*" >&2; exit 99; }
exec env PROJECT_ROOT="\${PROJECT_ROOT}" FRAMEWORK_ROOT="$PROJ/.agentic-framework" \\
    bash "$DESIGNER_SH" "\$2"
SHIM
    chmod +x "$PROJ/.agentic-framework/bin/fw"
    FRAMEWORK_ROOT="$SRC"
}

teardown() {
    FRAMEWORK_ROOT="$REAL_FW"
    [ -d "${TEST_TEMP_DIR:-}" ] && chmod -R u+w "$TEST_TEMP_DIR" 2>/dev/null
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# _put_build <root> <version>: pin + build under <root>, sha computed from the bytes.
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

# The consumer's previously INSTALLED build (old pin).
_install_old() {
    mkdir -p "$PROJ/vendor/designer"
    printf 'DESIGNER-BUILD-0.8.0' > "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html"
    chmod 0444 "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html"
}

@test "installed designer + pin bump: upgrade installs the new pinned build" {
    _install_old
    run _t4672_sync_designer "$PROJ" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"Workflow Designer installed (sha256 verified against pin)"* ]]
    cmp -s "$PROJ/vendor/designer/aef-workflow-designer-0.9.0.html" \
           "$PROJ/.agentic-framework/vendor/designer/aef-workflow-designer-0.9.0.html"
    # and `fw designer status` now agrees
    run env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$PROJ/.agentic-framework" bash "$DESIGNER_SH" status
    [[ "$output" == *"PRESENT"* ]]
    [[ "$output" != *"NOT SYNCED"* ]]
}

@test "--dry-run: names the build it would install and writes nothing" {
    _install_old
    rm -rf "$PROJ/.agentic-framework/policy" "$PROJ/.agentic-framework/vendor"   # vendored not refreshed yet
    run _t4672_sync_designer "$PROJ" true
    [ "$status" -eq 0 ]
    [[ "$output" == *"WOULD INSTALL"*"aef-workflow-designer-0.9.0.html"* ]]
    [ ! -e "$PROJ/vendor/designer/aef-workflow-designer-0.9.0.html" ]
}

@test "no designer installed: skipped quietly, nothing installed" {
    run _t4672_sync_designer "$PROJ" false
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$PROJ/vendor/designer" ]
}

@test "already current: no-op, no output" {
    mkdir -p "$PROJ/vendor/designer"
    cp "$PROJ/.agentic-framework/vendor/designer/aef-workflow-designer-0.9.0.html" "$PROJ/vendor/designer/"
    run _t4672_sync_designer "$PROJ" false
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "step 4b calls the designer sync after a successful vendor" {
    run grep -c '_t4672_sync_designer "$target_dir" "$dry_run"' "$REAL_FW/lib/upgrade.sh"
    [ "$output" = "1" ]
}
