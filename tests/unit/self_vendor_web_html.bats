#!/usr/bin/env bats
# T-2412 (OBS-077) — _self_vendor_web syncs the full render surface, not just
# .sh and .py.
#
# DEFECT (OBS-077): the find filter in `_self_vendor_web` was
#   \( -name "*.sh" -o -name "*.py" \)
# which silently skipped every .html template, .css, .js, .svg, .j2, .jinja2 in
# the framework web/ tree. Consumer's vendored web/templates/ would drift from
# the framework's, and there was no warning at vendor time.
#
# FIX (T-2412): extend the filter to the full render surface
#   \( -name "*.sh" -o -name "*.py" -o -name "*.html" -o -name "*.css"
#      -o -name "*.js" -o -name "*.svg" -o -name "*.j2" -o -name "*.jinja2" \)
#
# This test creates a synthetic framework + consumer pair, edits a .html file
# in framework web/, runs `_self_vendor_web`, and asserts the consumer copy now
# contains the HTML (it would NOT have been copied before the fix).

setup() {
    FRAMEWORK_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    LIB="$FRAMEWORK_ROOT_REAL/lib/upgrade.sh"
    [ -f "$LIB" ] || skip "lib/upgrade.sh not found"

    FAKE_FW="$(mktemp -d)"
    # Build a synthetic framework root with .agentic-framework/web/ already
    # present (the structural guard at line 445 short-circuits if not).
    mkdir -p "$FAKE_FW/web/templates"
    mkdir -p "$FAKE_FW/web/static/css"
    mkdir -p "$FAKE_FW/web/static/js"
    mkdir -p "$FAKE_FW/.agentic-framework/web/templates"
    mkdir -p "$FAKE_FW/.agentic-framework/web/static/css"
    mkdir -p "$FAKE_FW/.agentic-framework/web/static/js"
    # Source files in framework web/
    cat > "$FAKE_FW/web/templates/foo.html" <<EOF
<html><body>edited</body></html>
EOF
    cat > "$FAKE_FW/web/static/css/site.css" <<EOF
body { color: red; }
EOF
    cat > "$FAKE_FW/web/static/js/app.js" <<EOF
console.log("edited");
EOF
    cat > "$FAKE_FW/web/app.py" <<EOF
# python control file
EOF
    # Provide a NOP do_upgrade so sourcing lib/upgrade.sh has no side-effects.
    # The function under test (_self_vendor_web) is what we call directly.
}

teardown() {
    [ -n "${FAKE_FW:-}" ] && rm -rf "$FAKE_FW"
}

# Source lib/upgrade.sh inside a subshell with the fake FRAMEWORK_ROOT, then
# call _self_vendor_web directly.
_run_vendor() {
    FRAMEWORK_ROOT="$FAKE_FW" bash -c "
        # Stub `command -v` lookups the rest of upgrade.sh might want.
        GREEN=''; NC=''
        source '$LIB'
        _self_vendor_web false
    "
}

@test "FIX: HTML templates are synced to consumer .agentic-framework/web/" {
    run _run_vendor
    [ "$status" -eq 0 ]
    [ -f "$FAKE_FW/.agentic-framework/web/templates/foo.html" ]
    grep -q "edited" "$FAKE_FW/.agentic-framework/web/templates/foo.html"
}

@test "FIX: CSS files are synced" {
    run _run_vendor
    [ "$status" -eq 0 ]
    [ -f "$FAKE_FW/.agentic-framework/web/static/css/site.css" ]
}

@test "FIX: JS files are synced" {
    run _run_vendor
    [ "$status" -eq 0 ]
    [ -f "$FAKE_FW/.agentic-framework/web/static/js/app.js" ]
}

@test "CONTROL: existing .py files are still synced (regression guard)" {
    run _run_vendor
    [ "$status" -eq 0 ]
    [ -f "$FAKE_FW/.agentic-framework/web/app.py" ]
}
