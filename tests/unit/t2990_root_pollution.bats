#!/usr/bin/env bats
# T-2990: the root-pollution rail, proven in BOTH directions.
#
# The rail exists because four ImageMagick PostScript files accumulated in the
# repo root over three months and nothing noticed. A rail that only ever passes
# would reproduce exactly that state while looking like coverage (L-543), so the
# planted-junk case below carries as much weight as the clean-root one.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    LIB="$FRAMEWORK_ROOT/lib/root-pollution.sh"
    [ -f "$LIB" ] || skip "lib/root-pollution.sh not found"
    source "$LIB"

    SB="$(mktemp -d)"
    git -C "$SB" init -q 2>/dev/null || true
}

teardown() {
    rm -rf "$SB" 2>/dev/null
}

# Writes a file whose bytes are what ImageMagick's PostScript export actually
# produced — the four real ones all begin exactly like this.
_plant_postscript() {
    printf '%%!PS-Adobe-3.0\n%%%%Creator: (ImageMagick)\n%%%%Title: (%s)\n' "$1" > "$SB/$1"
    # Pad past `file`'s "very short file" threshold so the type probe is real.
    head -c 4096 /dev/zero | tr '\0' 'A' >> "$SB/$1"
}

@test "T-2990: a clean root is silent" {
    echo "# readme" > "$SB/README.md"
    echo "key: value" > "$SB/config.yaml"
    run fw_root_pollution_scan "$SB"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-2990: a planted PostScript file is reported" {
    _plant_postscript "yaml"
    run fw_root_pollution_scan "$SB"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'yaml'
    echo "$output" | grep -qi 'postscript'
}

@test "T-2990: every one of the four real filenames is caught" {
    # The real instances. Named individually because the detector deliberately
    # does NOT match on these names — if a future refactor swaps the content
    # predicate for a name list, this still passes while the next differently
    # named instance walks through, so the sibling test below is the real guard.
    local f
    for f in os sys yaml "yaml,sys"; do _plant_postscript "$f"; done
    run fw_root_pollution_scan "$SB"
    [ "$status" -eq 1 ]
    [ "$(echo "$output" | grep -c .)" -eq 4 ]
}

@test "T-2990: an offender named nothing like a Python module is still caught" {
    # The guard against a name-list detector (L-543): the rule is 'binary at the
    # repo root', not 'named after a module we already saw'.
    _plant_postscript "quarterly-render"
    run fw_root_pollution_scan "$SB"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'quarterly-render'
}

@test "T-2990: legitimate root screenshots are not flagged" {
    # ~14 verification PNGs live at this repo's root (T-2060, T-2632, arc-006).
    # Flagging them would make the rail noise, and noise is how the last one was
    # missed — `yaml` and `yaml,sys` sat in `git status` as `??` for days.
    printf '\211PNG\r\n\032\n' > "$SB/t2060-verify.png"
    head -c 4096 /dev/zero >> "$SB/t2060-verify.png"
    run fw_root_pollution_scan "$SB"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-2990: a tracked binary is left to the large-file gate" {
    # Two rails reporting one file under two names makes both easier to dismiss.
    _plant_postscript "committed-blob"
    git -C "$SB" config user.email t@example.com
    git -C "$SB" config user.name t
    git -C "$SB" add "committed-blob" 2>/dev/null
    git -C "$SB" commit -qm "tracked" 2>/dev/null
    run fw_root_pollution_scan "$SB"
    [ "$status" -eq 0 ]
}

@test "T-2990: source files at the root are not flagged" {
    printf '#!/usr/bin/env bash\necho hi\n' > "$SB/script.sh"
    printf 'def f():\n    return 1\n' > "$SB/mod.py"
    printf '{"a": 1}\n' > "$SB/data.json"
    run fw_root_pollution_scan "$SB"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-2990: subdirectories are out of scope" {
    mkdir -p "$SB/build"
    _plant_postscript "deep"
    mv "$SB/deep" "$SB/build/deep"
    run fw_root_pollution_scan "$SB"
    [ "$status" -eq 0 ]
}

@test "T-2990: doctor surfaces the finding" {
    # The predicate being right is not the same as the operator seeing it.
    grep -q 'fw_root_pollution_scan' "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'Repo root:' "$FRAMEWORK_ROOT/bin/fw"
}

@test "T-2990: the four real files are gone from this repo" {
    # The cleanup half of the task, asserted rather than remembered.
    local f
    for f in os sys yaml "yaml,sys"; do
        [ ! -f "$FRAMEWORK_ROOT/$f" ] || { echo "junk file '$f' is back" >&2; return 1; }
    done
}

@test "T-2990: the /os and /sys ignore rules stay removed" {
    # They were the reason instances 1 and 2 were invisible. Re-adding them
    # would blind git status again, so the absence is pinned, not trusted.
    ! grep -qx '/os'  "$FRAMEWORK_ROOT/.gitignore"
    ! grep -qx '/sys' "$FRAMEWORK_ROOT/.gitignore"
}
