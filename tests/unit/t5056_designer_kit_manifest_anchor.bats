#!/usr/bin/env bats
# T-5056: `fw designer sync --from-tag` must anchor the authoring kit's SHA256SUMS to the
# MANIFEST at the same tag, not only to the pin. Before T-5056 the comment on
# _sync_validator_at_tag named the MANIFEST but the code compared the pin alone.
# Local fixture origin, zero network (same shape as designer_sync_from_tag.bats).

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO/agents/designer/designer.sh"
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/policy" "$ROOT/bin"
    unset FRAMEWORK_ROOT
    export FW_DESIGNER_PIN_FILE="$ROOT/policy/designer-pin.yaml"
    printf '#!/usr/bin/env bash\necho "http://localhost:3000"\n' > "$ROOT/bin/fw"
    chmod +x "$ROOT/bin/fw"

    ORIGIN="$ROOT/origin-repo"
    KIT="dist/aef-authoring-kit-9.9.9"
    mkdir -p "$ORIGIN/$KIT"
    git init -q "$ORIGIN"
    printf 'DESIGNER-TAG-FIXTURE-9.9.9' > "$ORIGIN/dist/aef-workflow-designer-9.9.9.html"
    printf 'print("validator fixture")\n' > "$ORIGIN/$KIT/validate-workflow.py"
    printf 'skill\n' > "$ORIGIN/$KIT/SKILL.md"
    ( cd "$ORIGIN/$KIT" && sha256sum SKILL.md validate-workflow.py > SHA256SUMS )
    FIX_SHA="$(sha256sum "$ORIGIN/dist/aef-workflow-designer-9.9.9.html" | cut -d' ' -f1)"
    FIX_BYTES="$(stat -c '%s' "$ORIGIN/dist/aef-workflow-designer-9.9.9.html")"
    KIT_SHA="$(sha256sum "$ORIGIN/$KIT/SHA256SUMS" | cut -d' ' -f1)"
    VAL_SHA="$(sha256sum "$ORIGIN/$KIT/validate-workflow.py" | cut -d' ' -f1)"
    VAL_BYTES="$(stat -c '%s' "$ORIGIN/$KIT/validate-workflow.py")"
}

teardown() { rm -rf "$ROOT"; }

_release() {   # $1: kit_sha256 line for the MANIFEST ("" = omit the key)
    {
        echo 'latest: "9.9.9"'
        echo 'artifact: "dist/aef-workflow-designer-9.9.9.html"'
        echo "sha256: \"$FIX_SHA\""
        echo "bytes: $FIX_BYTES"
        [ -n "$1" ] && echo "kit_sha256: \"$1\""
    } > "$ORIGIN/dist/MANIFEST.yaml"
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t add -A
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t commit -qm "release 9.9.9"
    git -C "$ORIGIN" -c user.email=t@t -c user.name=t tag -a designer-v9.9.9 -m "release 9.9.9"
    cat > "$ROOT/policy/designer-pin.yaml" <<EOF
version: "9.9.9"
sha256: "$FIX_SHA"
bytes: $FIX_BYTES
source_tag: "designer-v9.9.9"
source_manifest: "dist/MANIFEST.yaml"
source_origin: "$ORIGIN"
vendored_path: "vendor/designer/fixture.html"
validator_source: "$KIT/validate-workflow.py"
validator_sums: "$KIT/SHA256SUMS"
validator_kit_sha256: "$KIT_SHA"
validator_sha256: "$VAL_SHA"
validator_bytes: $VAL_BYTES
validator_path: "vendor/designer/validate-workflow-9.9.9.py"
EOF
}

@test "T-5056: kit sums matching pin AND MANIFEST vendor the validator" {
    _release "$KIT_SHA"
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag
    [ "$status" -eq 0 ]
    [[ "$output" == *"kit SHA256SUMS (pin + MANIFEST)"* ]]
    [ -f "$ROOT/vendor/designer/validate-workflow-9.9.9.py" ]
}

@test "T-5056: MANIFEST kit_sha256 disagreeing with the kit sums refuses, naming all three values" {
    _release "0000000000000000000000000000000000000000000000000000000000000000"
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag
    [ "$status" -eq 1 ]
    [[ "$output" == *"validator sha256 MISMATCH"* ]]
    [[ "$output" == *"manifest=0000000000000000000000000000000000000000000000000000000000000000"* ]]
    [[ "$output" == *"pin=$KIT_SHA"* ]]
    [ ! -f "$ROOT/vendor/designer/validate-workflow-9.9.9.py" ]
}

@test "T-5056: a MANIFEST without kit_sha256 is named on stderr, pin check still applies" {
    _release ""
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from-tag
    [ "$status" -eq 0 ]
    [[ "$output" == *"has no kit_sha256"* ]]
}
