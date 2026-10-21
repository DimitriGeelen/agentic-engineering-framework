#!/usr/bin/env bats
#
# T-2657 — `fw update` ran the RUNNING (old) bin/fw's do_vendor against the fetched
# upstream, so an include the new version added (832: policy/) never arrived on the
# upgrade that introduced it. The update must vendor with the upstream's own bin/fw.
#
# Fixtures: the upstream's bin/fw is a stub that differs from the running one, which
# is the version skew no earlier update test could express.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TMP="$(mktemp -d)"
    SRC="$TMP/src"
    PROJ="$TMP/proj"
    AF="$PROJ/.agentic-framework"

    mkdir -p "$SRC/bin" "$SRC/lib"
    printf '#!/bin/sh\necho stub\n' > "$SRC/bin/fw"; chmod +x "$SRC/bin/fw"
    echo "# framework" > "$SRC/FRAMEWORK.md"
    echo "1.2.0" > "$SRC/VERSION"
    echo "a v1" > "$SRC/lib/a.sh"
    git -C "$SRC" init -q -b master
    _commit v1

    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    # Vendor v1 with the running fw, then point the project at the upstream.
    ( cd "$PROJ" && env FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/fw" vendor --target "$PROJ" --source "$SRC" >/dev/null 2>&1 )
    # The vendor stamps the running fw's version; pin it to something older.
    echo "1.2.0" > "$AF/VERSION"
    printf 'upstream_repo: %s\nversion: 1.2.0\n' "$SRC" > "$PROJ/.framework.yaml"
}

teardown() { rm -rf "$TMP"; }

_commit() {
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t add -A
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qm "$1"
}

# Upstream v1.3.0 whose bin/fw defines do_vendor and vendors a NEW include the
# running fw's list does not know about. $1 = exit code of its vendor.
_upstream_with_vendor() {
    cat > "$SRC/bin/fw" <<EOF
#!/usr/bin/env bash
# new-version bin/fw (stub)
do_vendor() {
    [ "$1" = 0 ] || { echo "upstream vendor refused" >&2; exit $1; }
    mkdir -p "\$PROJECT_ROOT/.agentic-framework/newinclude"
    echo "\$*" > "\$PROJECT_ROOT/.agentic-framework/newinclude/args"
}
[ "\${1:-}" = vendor ] && { shift; do_vendor "\$@"; exit \$?; }
EOF
    chmod +x "$SRC/bin/fw"
    echo "1.3.0" > "$SRC/VERSION"
    _commit v1.3.0
}

_update() {
    ( cd "$PROJ" && env NO_COLOR=1 FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/fw" update 2>&1 )
}

@test "update vendors through the upstream's own bin/fw (new includes list)" {
    _upstream_with_vendor 0
    run _update
    [ "$status" -eq 0 ]
    [ -f "$AF/newinclude/args" ]
    grep -q -- "--source .*/upstream" "$AF/newinclude/args"
    grep -q -- "--target $PROJ" "$AF/newinclude/args"
    [ "$(cat "$AF/VERSION")" = "1.3.0" ]
}

@test "a refusal from the upstream vendor aborts the update and leaves VERSION" {
    _upstream_with_vendor 3
    run _update
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "upstream vendor refused"
    echo "$output" | grep -q "Update aborted"
    [ "$(cat "$AF/VERSION")" = "1.2.0" ]
}

@test "upstream bin/fw without do_vendor falls back to the running vendor, with a WARN" {
    echo "a v2" > "$SRC/lib/a.sh"
    echo "1.3.0" > "$SRC/VERSION"
    _commit v1.3.0
    run _update
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "WARN: upstream bin/fw defines no do_vendor"
    [ "$(cat "$AF/lib/a.sh")" = "a v2" ]
    [ "$(cat "$AF/VERSION")" = "1.3.0" ]
}
