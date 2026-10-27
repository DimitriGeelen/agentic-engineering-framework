#!/usr/bin/env bats
# T-4836: the pinned designer VALIDATOR (policy/designer-pin.yaml validator_path,
# T-4830) reaches consumers by every path the pinned build does.
#
# The defect: `fw vendor`, `fw vendor self`, `fw designer install` and the
# upgrade re-install knew only vendored_path, so a consumer had the build and no
# validator, and POST /api/validate answered 503 everywhere but this repo.
#
# Surfaces under test:
#   bin/fw do_vendor (T-3064 carve-out)        — t1, t2 (real fw vendor, real pin)
#   agents/designer/designer.sh do_install     — t3 accept, t4 mismatch, t5 absent, t6 no key
#   lib/upgrade.sh _self_vendor_designer       — t7 sync + prune
#   lib/upgrade.sh _t4672_sync_designer        — t8 build current, validator missing

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4836-XXXXXX)"
    REAL_FW="$FRAMEWORK_ROOT"
    export NO_COLOR=1
    DESIGNER_SH="$REAL_FW/agents/designer/designer.sh"
    source "$REAL_FW/lib/colors.sh"
    source "$REAL_FW/lib/upgrade.sh"
    source "$REAL_FW/lib/init.sh"
    PROJ="$TEST_TEMP_DIR/proj"
}

teardown() {
    FRAMEWORK_ROOT="$REAL_FW"
    [ -d "${TEST_TEMP_DIR:-}" ] && chmod -R u+w "$TEST_TEMP_DIR" 2>/dev/null
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# _put_pinned <root> <version>: pin + build + validator under <root>; both sha256
# values computed from the bytes, so install runs the real verification.
_put_pinned() {
    local root="$1" ver="$2" sha vsha
    mkdir -p "$root/policy" "$root/vendor/designer"
    printf 'DESIGNER-BUILD-%s' "$ver" > "$root/vendor/designer/aef-workflow-designer-$ver.html"
    printf 'def run_xml(x):\n    return []  # %s\n' "$ver" > "$root/vendor/designer/validate-workflow-$ver.py"
    sha="$(sha256sum "$root/vendor/designer/aef-workflow-designer-$ver.html" | cut -d' ' -f1)"
    vsha="$(sha256sum "$root/vendor/designer/validate-workflow-$ver.py" | cut -d' ' -f1)"
    cat > "$root/policy/designer-pin.yaml" <<EOF
version: "$ver"
sha256: "$sha"
vendored_path: "vendor/designer/aef-workflow-designer-$ver.html"
validator_sha256: "$vsha"
validator_path: "vendor/designer/validate-workflow-$ver.py"
EOF
}

_install() {
    env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$PROJ/.agentic-framework" bash "$DESIGNER_SH" install
}

_pin_rel() {
    _designer_pin_path "$REAL_FW/policy/designer-pin.yaml" "$1"
}

@test "t1 fw vendor ships the pin's validator_path beside the build, read-only, sha256 = pin" {
    local vrel
    vrel="$(_pin_rel validator_path)"
    [ -n "$vrel" ]
    mkdir -p "$PROJ" && git -C "$PROJ" init -q
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT "$REAL_FW/bin/fw" vendor --target "$PROJ"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$vrel (pinned designer validator)"* ]]
    [ -f "$PROJ/.agentic-framework/$vrel" ]
    [ "$(stat -c %a "$PROJ/.agentic-framework/$vrel")" = 444 ]
    cmp -s "$REAL_FW/$vrel" "$PROJ/.agentic-framework/$vrel"
    # the build is still shipped and still counted as written by the vendor
    [ -f "$PROJ/.agentic-framework/$(_pin_rel vendored_path)" ]
    [[ "$output" != *"NOT written by the vendor"* ]]
}

@test "t2 fw vendor --dry-run lists the validator it would copy" {
    mkdir -p "$PROJ"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT "$REAL_FW/bin/fw" vendor --dry-run --target "$PROJ"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$(_pin_rel validator_path) (pinned designer validator)"* ]]
    [ ! -e "$PROJ/.agentic-framework" ]
}

@test "t3 fw designer install installs the validator into PROJECT_ROOT; second run is a no-op" {
    _put_pinned "$PROJ/.agentic-framework" 0.9.0
    run _install
    [ "$status" -eq 0 ]
    [[ "$output" == *"installed"*"validator → vendor/designer/validate-workflow-0.9.0.py (sha256 verified, read-only)"* ]]
    cmp -s "$PROJ/vendor/designer/validate-workflow-0.9.0.py" \
           "$PROJ/.agentic-framework/vendor/designer/validate-workflow-0.9.0.py"
    [ "$(stat -c %a "$PROJ/vendor/designer/validate-workflow-0.9.0.py")" = 444 ]
    run _install
    [ "$status" -eq 0 ]
    [[ "$output" == *"validator already installed"* ]]
}

@test "t4 sha256 mismatch: install refuses (rc 1) and installs no validator" {
    _put_pinned "$PROJ/.agentic-framework" 0.9.0
    echo "# tampered" >> "$PROJ/.agentic-framework/vendor/designer/validate-workflow-0.9.0.py"
    run _install
    [ "$status" -eq 1 ]
    [[ "$output" == *"validator sha256 MISMATCH"* ]]
    [ ! -e "$PROJ/vendor/designer/validate-workflow-0.9.0.py" ]
}

@test "t5 vendored validator absent: install is loud and non-zero (rc 5), naming the file" {
    _put_pinned "$PROJ/.agentic-framework" 0.9.0
    rm -f "$PROJ/.agentic-framework/vendor/designer/validate-workflow-0.9.0.py"
    run _install
    [ "$status" -eq 5 ]
    [[ "$output" == *"validator NOT installed"*"the pin names vendor/designer/validate-workflow-0.9.0.py"* ]]
}

@test "t6 a pin without validator_path installs the build only (rc 0)" {
    _put_pinned "$PROJ/.agentic-framework" 0.9.0
    sed -i '/^validator_/d' "$PROJ/.agentic-framework/policy/designer-pin.yaml"
    run _install
    [ "$status" -eq 0 ]
    [ -f "$PROJ/vendor/designer/aef-workflow-designer-0.9.0.html" ]
    [ ! -e "$PROJ/vendor/designer/validate-workflow-0.9.0.py" ]
}

@test "t7 fw vendor self syncs the validator and prunes the superseded one" {
    local syn="$TEST_TEMP_DIR/syn-fw"
    _put_pinned "$syn" 0.9.0
    mkdir -p "$syn/.agentic-framework/vendor/designer"
    printf 'old' > "$syn/.agentic-framework/vendor/designer/validate-workflow-0.8.0.py"
    FRAMEWORK_ROOT="$syn"
    run _self_vendor_designer false
    [ "$status" -eq 0 ]
    cmp -s "$syn/vendor/designer/validate-workflow-0.9.0.py" \
           "$syn/.agentic-framework/vendor/designer/validate-workflow-0.9.0.py"
    [ ! -e "$syn/.agentic-framework/vendor/designer/validate-workflow-0.8.0.py" ]
    [ -f "$syn/.agentic-framework/vendor/designer/aef-workflow-designer-0.9.0.html" ]
}

@test "t8 upgrade re-installs when the build is current but the validator is missing" {
    _put_pinned "$PROJ/.agentic-framework" 0.9.0
    mkdir -p "$PROJ/.agentic-framework/bin" "$PROJ/vendor/designer"
    cat > "$PROJ/.agentic-framework/bin/fw" <<SHIM
#!/usr/bin/env bash
[ "\$1" = "designer" ] || { echo "unexpected: \$*" >&2; exit 99; }
exec env PROJECT_ROOT="\${PROJECT_ROOT}" FRAMEWORK_ROOT="$PROJ/.agentic-framework" \\
    bash "$DESIGNER_SH" "\$2"
SHIM
    chmod +x "$PROJ/.agentic-framework/bin/fw"
    cp "$PROJ/.agentic-framework/vendor/designer/aef-workflow-designer-0.9.0.html" "$PROJ/vendor/designer/"
    run _t4672_sync_designer "$PROJ" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"Workflow Designer installed"* ]]
    [ -f "$PROJ/vendor/designer/validate-workflow-0.9.0.py" ]
    # now current: a second pass is silent
    run _t4672_sync_designer "$PROJ" false
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
