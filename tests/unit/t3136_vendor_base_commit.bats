#!/usr/bin/env bats
#
# T-3136 — `fw update` re-vendors wholesale. Consumer 001-CashWeb (their T-111)
# lost a carried bin/fw patch and only found out because a gate happened to
# cover it, and no record of the vendored base commit existed to diff against.
#
# T-3850 already made the vendor refuse to overwrite a locally edited file
# (pinned here for bin/fw specifically). What this task adds: the vendor stamp
# records the upstream commit the copy came from, and `fw update` shows it.
#
# Synthetic fixtures only: a tiny git-tracked framework source vendored into a
# throwaway consumer.

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
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t add -A
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qm v1

    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
}

teardown() { rm -rf "$TMP"; }

_vendor() {
    ( cd "$PROJ" && env FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/fw" vendor --target "$PROJ" --source "$SRC" "$@" 2>&1 )
}

_stamp_commit() {
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("source_commit",""))' \
        "$AF/.fw-vendor-stamp.json"
}

@test "vendor stamp records the full source commit" {
    run _vendor
    [ "$status" -eq 0 ]
    [ -f "$AF/.fw-vendor-stamp.json" ]
    [ "$(_stamp_commit)" = "$(git -C "$SRC" rev-parse HEAD)" ]
}

@test "re-vendor after an upstream commit records the NEW base" {
    _vendor >/dev/null
    echo "a v2" > "$SRC/lib/a.sh"
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qam v2
    run _vendor
    [ "$status" -eq 0 ]
    [ "$(_stamp_commit)" = "$(git -C "$SRC" rev-parse HEAD)" ]
}

@test "non-git source: stamp is written without source_commit" {
    rm -rf "$SRC/.git"
    run _vendor
    [ "$status" -eq 0 ]
    [ -f "$AF/.fw-vendor-stamp.json" ]
    [ -z "$(_stamp_commit)" ]
}

@test "a carried bin/fw patch makes the re-vendor refuse, unwritten (T-3850 pin)" {
    _vendor >/dev/null
    printf '#!/bin/sh\necho stub\n# cashweb-local patch\n' > "$AF/bin/fw"
    echo "a v2" > "$SRC/lib/a.sh"
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qam v2
    run _vendor
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "LOCAL  bin/fw  — edited locally — would be OVERWRITTEN"
    grep -q "cashweb-local patch" "$AF/bin/fw"
}

@test "fw update shows the vendored base commit from the stamp" {
    _vendor >/dev/null
    base=$(git -C "$SRC" rev-parse HEAD)
    printf 'upstream_repo: %s\n' "$SRC" > "$PROJ/.framework.yaml"
    run bash -c 'export NO_COLOR=1 PROJECT_ROOT="$1" FRAMEWORK_ROOT="$2"
        source "$2/lib/colors.sh"; source "$2/lib/compat.sh"; source "$2/lib/update.sh"
        do_update --check' _ "$PROJ" "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Base:      ${base:0:12} (upstream commit this copy was vendored from)"
}

@test "fw update says so when no base was recorded" {
    mkdir -p "$AF"
    echo "1.2.0" > "$AF/VERSION"
    printf 'upstream_repo: %s\n' "$SRC" > "$PROJ/.framework.yaml"
    run bash -c 'export NO_COLOR=1 PROJECT_ROOT="$1" FRAMEWORK_ROOT="$2"
        source "$2/lib/colors.sh"; source "$2/lib/compat.sh"; source "$2/lib/update.sh"
        do_update --check' _ "$PROJ" "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Base:      not recorded"
}
