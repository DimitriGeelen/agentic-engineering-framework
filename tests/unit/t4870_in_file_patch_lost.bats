#!/usr/bin/env bats
#
# T-4870 — `fw upgrade` removed 1409's 4-line block in web/blueprints/__init__.py
# (their /arbeiter page) twice, at be.46 and be.50. It was a declared in_file
# marker, but the only signal was one WARN line mid-log and an exit 0; nothing
# afterwards noticed. Now: an ACTION REQUIRED block, repeated last; fw doctor
# WARNs until the patch is back; `on_missing: fail` makes the vendor exit 4.
#
# FIXTURES ONLY: a tiny git-tracked framework source vendored into a consumer.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    VP="$FRAMEWORK_ROOT/lib/vendor_preserve.py"
    TMP="$(mktemp -d)"
    SRC="$TMP/src"
    PROJ="$TMP/proj"
    AF="$PROJ/.agentic-framework"

    mkdir -p "$SRC/bin" "$SRC/web/blueprints"
    printf '#!/bin/sh\necho stub\n' > "$SRC/bin/fw"; chmod +x "$SRC/bin/fw"
    echo "# framework" > "$SRC/FRAMEWORK.md"
    echo "bp v1" > "$SRC/web/blueprints/__init__.py"
    git -C "$SRC" init -q
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t add -A
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qm v1

    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    _vendor >/dev/null
    # 1409's shape: a local block appended to an upstream file.
    printf 'bp v1\n# T-2754 1409-local: arbeiter\nregister(arbeiter_bp)\n' \
        > "$AF/web/blueprints/__init__.py"

    echo "bp v2" > "$SRC/web/blueprints/__init__.py"
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qam v2
}

teardown() { rm -rf "$TMP"; }

_vendor() {
    ( cd "$PROJ" && env FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/fw" vendor --target "$PROJ" --source "$SRC" "$@" 2>&1 )
}

_manifest() {  # $1 = optional on_missing value
    {
        echo "in_file:"
        echo "  - file: web/blueprints/__init__.py"
        echo '    marker: "1409-local: arbeiter"'
        if [ -n "${1:-}" ]; then echo "on_missing: $1"; fi
    } > "$PROJ/.fwvendor-preserve.yaml"
}

@test "default (warn): exit 0, ACTION REQUIRED block is the last thing printed" {
    _manifest
    run _vendor
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "ACTION REQUIRED: 1 local in-file patch(es) were REMOVED"
    echo "$output" | grep -q "marker:          1409-local: arbeiter"
    echo "$output" | grep -q "pre-vendor copy: .context/working/vendor-backup/"
    echo "$output" | grep -q "set \`on_missing: fail\`"
    # Repeated after "Vendored successfully", so it is not buried mid-log.
    after=$(echo "$output" | sed -n '/Vendored successfully/,$p')
    echo "$after" | grep -q "ACTION REQUIRED"
    [ -f "$PROJ/.context/working/vendor-missing-markers.json" ]
}

@test "on_missing: fail: vendor completes, then exits 4" {
    _manifest fail
    run _vendor
    [ "$status" -eq 4 ]
    grep -q "bp v2" "$AF/web/blueprints/__init__.py"   # vendor completed, nothing rolled back
    [ -f "$AF/.fw-vendor-stamp.json" ]
    echo "$output" | grep -q "on_missing: fail is set"
    echo "$output" | grep -q "nothing was rolled back"
}

@test "on_missing: invalid value refuses before writing" {
    _manifest sometimes
    run _vendor
    [ "$status" -ne 0 ] && [ "$status" -ne 4 ]
    echo "$output" | grep -q "on_missing must be 'warn' or 'fail'"
    grep -q "1409-local" "$AF/web/blueprints/__init__.py"
}

@test "check: exit 1 while the marker is missing, 0 (and record cleared) once re-applied" {
    _manifest
    _vendor >/dev/null
    run python3 "$VP" check --target "$PROJ"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qF '.agentic-framework/web/blueprints/__init__.py: "1409-local: arbeiter" missing'
    echo "# T-2754 1409-local: arbeiter" >> "$AF/web/blueprints/__init__.py"
    run python3 "$VP" check --target "$PROJ"
    [ "$status" -eq 0 ]
    [ ! -f "$PROJ/.context/working/vendor-missing-markers.json" ]
    run python3 "$VP" report --target "$PROJ"
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "check: exit 2 with no manifest or no in_file entries" {
    run python3 "$VP" check --target "$PROJ"
    [ "$status" -eq 2 ]
    printf 'files:\n  - web/x.py\n' > "$PROJ/.fwvendor-preserve.yaml"
    run python3 "$VP" check --target "$PROJ"
    [ "$status" -eq 2 ]
}

@test "a vendor with every marker present leaves no record and no block" {
    _manifest fail
    _vendor >/dev/null || true
    echo "# T-2754 1409-local: arbeiter" >> "$SRC/web/blueprints/__init__.py"
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qam v3
    run _vendor
    [ "$status" -eq 0 ]
    [[ "$output" != *"ACTION REQUIRED"* ]]
    [ ! -f "$PROJ/.context/working/vendor-missing-markers.json" ]
}

@test "fw doctor WARNs on a lost in-file patch (wiring)" {
    grep -q 'vendor_preserve.py" check --target "$PROJECT_ROOT"' "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'In-file patches lost from .agentic-framework/ (T-4870)' "$FRAMEWORK_ROOT/bin/fw"
}

@test "fw upgrade: rc 4 is 'patches lost', summary repeats the block, exits 4 at the end" {
    grep -q 'in-file patches lost (on_missing: fail)' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -q 'vendor_preserve.py" report --target "$target_dir"' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -q '_t4870_patches_lost" = 1' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "fallback parser (no PyYAML) reads on_missing" {
    run python3 - "$FRAMEWORK_ROOT/lib" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import vendor_preserve as v
t = """in_file:
  - file: web/app.py
    marker: "m1"
on_missing: fail   # 1409
"""
d = v._mini_yaml(t)
sys.exit(0 if d.get("on_missing") == "fail" and d["in_file"][0]["marker"] == "m1" else 1)
PY
    [ "$status" -eq 0 ]
}
