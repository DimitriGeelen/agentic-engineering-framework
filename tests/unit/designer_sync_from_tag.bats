#!/usr/bin/env bats
# T-2616: fw designer sync --from-tag — pull-at-tag intake contract (T-247/D-335).
#
# The intake fetches artifact + MANIFEST.yaml AT an annotated tag from the pin's
# read-only `source_origin` and refuses install unless the independently computed
# sha256 matches BOTH the MANIFEST at the same tag AND the pin. These tests use a
# LOCAL fixture origin (throwaway git repo + annotated tag) — zero network.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO/agents/designer/designer.sh"
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/policy" "$ROOT/bin"
    # minimal fw shim so `fw watchtower url` inside the script doesn't explode
    printf '#!/usr/bin/env bash\necho "http://localhost:3000"\n' > "$ROOT/bin/fw"
    chmod +x "$ROOT/bin/fw"

    # ── fixture origin: git repo with dist/artifact + MANIFEST at annotated tag ──
    ORIGIN="$ROOT/origin-repo"
    mkdir -p "$ORIGIN/dist"
    git init -q "$ORIGIN"
    printf 'DESIGNER-TAG-FIXTURE-9.9.9' > "$ORIGIN/dist/aef-workflow-designer-9.9.9.html"
    FIX_SHA="$(sha256sum "$ORIGIN/dist/aef-workflow-designer-9.9.9.html" | cut -d' ' -f1)"
    FIX_BYTES="$(stat -c '%s' "$ORIGIN/dist/aef-workflow-designer-9.9.9.html")"
    cat > "$ORIGIN/dist/MANIFEST.yaml" <<EOF
latest: "9.9.9"
artifact: "dist/aef-workflow-designer-9.9.9.html"
sha256: "$FIX_SHA"
bytes: $FIX_BYTES
EOF
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t add -A
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t commit -qm "release 9.9.9"
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t tag -a designer-v9.9.9 -m "release 9.9.9"

    # pin matching the fixture release
    cat > "$ROOT/policy/designer-pin.yaml" <<EOF
version: "9.9.9"
sha256: "$FIX_SHA"
bytes: $FIX_BYTES
source_tag: "designer-v9.9.9"
source_manifest: "dist/MANIFEST.yaml"
source_origin: "$ORIGIN"
vendored_path: "vendor/designer/fixture.html"
EOF
}

teardown() { rm -rf "$ROOT"; }

@test "from-tag installs when sha matches MANIFEST and pin (tag defaults to pin source_tag)" {
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag
    [ "$status" -eq 0 ]
    [[ "$output" == *"MANIFEST anchor"* ]]
    [[ "$output" == *"pin anchor"* ]]
    [ -f "$ROOT/vendor/designer/fixture.html" ]
    run diff "$ORIGIN/dist/aef-workflow-designer-9.9.9.html" "$ROOT/vendor/designer/fixture.html"
    [ "$status" -eq 0 ]
    perms="$(stat -c '%a' "$ROOT/vendor/designer/fixture.html")"
    [ "$perms" = "444" ]
    # idempotent re-install over the read-only copy
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag designer-v9.9.9
    [ "$status" -eq 0 ]
}

@test "from-tag REFUSES when MANIFEST at tag disagrees with artifact bytes (release not self-consistent)" {
    # cut a new tag whose MANIFEST lies about the sha
    sed -i 's/^sha256:.*/sha256: "0000000000000000000000000000000000000000000000000000000000000000"/' "$ORIGIN/dist/MANIFEST.yaml"
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t commit -aqm "bad manifest"
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t tag -a designer-v9.9.10 -m "bad"
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag designer-v9.9.10
    [ "$status" -eq 1 ]
    [[ "$output" == *"MISMATCH vs MANIFEST"* ]]
    [ ! -f "$ROOT/vendor/designer/fixture.html" ]
}

@test "from-tag REFUSES install when tag is self-consistent but does not match the pin" {
    # cut a self-consistent NEWER release the pin doesn't know about
    printf 'DESIGNER-TAG-FIXTURE-10.0.0' > "$ORIGIN/dist/aef-workflow-designer-10.0.0.html"
    NEW_SHA="$(sha256sum "$ORIGIN/dist/aef-workflow-designer-10.0.0.html" | cut -d' ' -f1)"
    NEW_BYTES="$(stat -c '%s' "$ORIGIN/dist/aef-workflow-designer-10.0.0.html")"
    cat > "$ORIGIN/dist/MANIFEST.yaml" <<EOF
latest: "10.0.0"
artifact: "dist/aef-workflow-designer-10.0.0.html"
sha256: "$NEW_SHA"
bytes: $NEW_BYTES
EOF
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t add -A
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t commit -qm "release 10.0.0"
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t tag -a designer-v10.0.0 -m "release 10.0.0"
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag designer-v10.0.0
    [ "$status" -eq 1 ]
    [[ "$output" == *"MISMATCH vs pin"* ]]
    [ ! -f "$ROOT/vendor/designer/fixture.html" ]
}

@test "from-tag --dry-run verifies self-consistency, reports pin mismatch as info, installs NOTHING" {
    # same newer-release setup as above — dry-run must exit 0 and not install
    printf 'DESIGNER-TAG-FIXTURE-10.0.0' > "$ORIGIN/dist/aef-workflow-designer-10.0.0.html"
    NEW_SHA="$(sha256sum "$ORIGIN/dist/aef-workflow-designer-10.0.0.html" | cut -d' ' -f1)"
    NEW_BYTES="$(stat -c '%s' "$ORIGIN/dist/aef-workflow-designer-10.0.0.html")"
    cat > "$ORIGIN/dist/MANIFEST.yaml" <<EOF
latest: "10.0.0"
artifact: "dist/aef-workflow-designer-10.0.0.html"
sha256: "$NEW_SHA"
bytes: $NEW_BYTES
EOF
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t add -A
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t commit -qm "release 10.0.0"
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t tag -a designer-v10.0.0 -m "release 10.0.0"
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag designer-v10.0.0 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"does NOT match current pin"* ]]
    [[ "$output" == *"dry-run OK"* ]]
    [ ! -f "$ROOT/vendor/designer/fixture.html" ]
    # and dry-run against the pinned tag reports a pin match
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"sha matches current pin"* ]]
    [ ! -f "$ROOT/vendor/designer/fixture.html" ]
}

@test "from-tag fails cleanly (exit 4) on an unreachable tag" {
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag designer-v0.0.0-nonexistent
    [ "$status" -eq 4 ]
    [[ "$output" == *"fetch failed"* ]]
}

@test "from-tag without source_origin in pin fails with actionable error (exit 3)" {
    sed -i '/^source_origin:/d' "$ROOT/policy/designer-pin.yaml"
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag
    [ "$status" -eq 3 ]
    [[ "$output" == *"source_origin"* ]]
}
