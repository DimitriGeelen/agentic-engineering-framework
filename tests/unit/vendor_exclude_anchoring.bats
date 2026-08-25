#!/usr/bin/env bats
# T-2849 — vendor exclude pattern anchoring regression.
#
# `_vendor_excludes_for` (bin/fw) translates repo-root-relative exclude
# patterns into the transfer-root coordinate system each per-include
# rsync/cp actually uses. Before the fix, slash-bearing patterns (e.g.
# "lib/ts/node_modules") were passed straight to rsync, which anchors any
# pattern containing '/' to the transfer root ("$src/lib/") — so the pattern
# was matched against a tree whose paths begin "ts/", never fired, and 305
# node_modules files shipped into every consumer. Slashless patterns
# (__pycache__, *.pyc, .DS_Store) matched anyway (rsync treats them as a
# basename at any depth), which is what made the list look functional.
#
# This suite pins:
#   - the real function (extracted verbatim from bin/fw, not duplicated) so
#     a future edit to the logic cannot silently drift away from the test
#   - a negative control proving the anchoring claim is falsifiable
#   - end-to-end: a fresh `fw vendor` ships zero files the source's own
#     .gitignore excludes, on both the rsync branch and the cp -r fallback
#   - re-vendoring over an already-polluted target self-heals (AC5)

load ../test_helper

FW_BIN="$FRAMEWORK_ROOT/bin/fw"

# Extract _vendor_excludes_for verbatim from bin/fw and source it into the
# current shell. bin/fw is not safe to `source` wholesale (it dispatches
# unconditionally on $1 at EOF) — pulling just this one function means the
# test exercises the real, live logic instead of a hand-copied duplicate.
_load_vendor_excludes_for() {
    local fn
    fn=$(sed -n '/^_vendor_excludes_for()/,/^}/p' "$FW_BIN")
    [ -n "$fn" ] || { echo "could not extract _vendor_excludes_for from bin/fw" >&2; return 1; }
    eval "$fn"
}

# Build a fixture "upstream" repo with exactly the shapes T-2849 measured:
# hand-excluded node_modules/src/tsconfig/package files under lib/ts, a
# tracked dist/ build output that must survive, a gitignore-only-excluded
# directory to exercise the git-derived half of _vendor_excludes_for, and
# the FRAMEWORK.md sentinel do_vendor requires when --source is given.
_make_fixture_source() {
    local src="$1"
    mkdir -p "$src/lib/ts/node_modules/pkg" \
             "$src/lib/ts/src" \
             "$src/lib/ts/dist" \
             "$src/lib/generated" \
             "$src/lib/__pycache__"
    echo "# fixture" > "$src/FRAMEWORK.md"
    echo "console.log('pkg')" > "$src/lib/ts/node_modules/pkg/index.js"
    echo "export const x = 1" > "$src/lib/ts/src/foo.ts"
    echo "{}" > "$src/lib/ts/tsconfig.json"
    echo "{}" > "$src/lib/ts/package.json"
    echo "{}" > "$src/lib/ts/package-lock.json"
    echo "keep-me" > "$src/lib/ts/dist/foo.js"
    echo "keep-me-too" > "$src/lib/keep.txt"
    echo "x" > "$src/lib/__pycache__/x.pyc"
    echo "generated content" > "$src/lib/generated/out.txt"

    git -C "$src" init -q
    cat > "$src/.gitignore" <<GITIGNORE
lib/ts/node_modules/
lib/generated/
__pycache__/
*.pyc
GITIGNORE
    git -C "$src" add -A
    git -C "$src" -c user.email=t@t -c user.name=t commit -q -m fixture
}

# Assert the vendored tree contains none of: node_modules, the hand-excluded
# lib/ts files, or the gitignore-only-excluded lib/generated tree — while
# the tracked dist/ output and an ordinary tracked file both survive.
_assert_vendor_clean() {
    local dest="$1"
    [ ! -e "$dest/lib/ts/node_modules" ]
    [ ! -e "$dest/lib/ts/src" ]
    [ ! -e "$dest/lib/ts/tsconfig.json" ]
    [ ! -e "$dest/lib/ts/package.json" ]
    [ ! -e "$dest/lib/ts/package-lock.json" ]
    [ ! -e "$dest/lib/generated" ]
    [ ! -e "$dest/lib/__pycache__" ]
    [ -f "$dest/lib/ts/dist/foo.js" ]
    [ -f "$dest/lib/keep.txt" ]
}

# Symlink-farm every executable on PATH except rsync into an isolated dir,
# so `command -v rsync` genuinely fails inside a subprocess run with this
# PATH — exercising do_vendor's cp -r fallback branch for real, rather than
# assuming its behaviour from reading the code.
_make_no_rsync_path() {
    local farm="$TEST_TEMP_DIR/no-rsync-bin"
    mkdir -p "$farm"
    local dir bin name
    local IFS=':'
    for dir in $PATH; do
        [ -d "$dir" ] || continue
        for bin in "$dir"/*; do
            [ -x "$bin" ] && [ -f "$bin" ] || continue
            name=$(basename "$bin")
            [ "$name" = "rsync" ] && continue
            [ -e "$farm/$name" ] && continue
            ln -s "$bin" "$farm/$name" 2>/dev/null || true
        done
    done
    echo "$farm"
}

@test "T-2849: _vendor_excludes_for strips the include prefix for a matching slash-bearing pattern" {
    _load_vendor_excludes_for
    run _vendor_excludes_for "lib" "/nonexistent-not-a-git-repo" "lib/ts/node_modules"
    [ "$status" -eq 0 ]
    [ "$output" = "ts/node_modules" ]
}

@test "T-2849: _vendor_excludes_for drops a slash-bearing pattern naming a DIFFERENT include" {
    _load_vendor_excludes_for
    run _vendor_excludes_for "bin" "/nonexistent-not-a-git-repo" "lib/ts/node_modules"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-2849: _vendor_excludes_for passes a slashless pattern through unchanged" {
    _load_vendor_excludes_for
    run _vendor_excludes_for "lib" "/nonexistent-not-a-git-repo" "__pycache__"
    [ "$status" -eq 0 ]
    [ "$output" = "__pycache__" ]
}

@test "T-2849: _vendor_excludes_for appends the source's own gitignore rules, transfer-root anchored" {
    _load_vendor_excludes_for
    local src="$TEST_TEMP_DIR/gitsrc"
    mkdir -p "$src/lib/generated"
    echo "x" > "$src/lib/generated/out.txt"
    git -C "$src" init -q
    echo "lib/generated/" > "$src/.gitignore"
    git -C "$src" add -A
    git -C "$src" -c user.email=t@t -c user.name=t commit -q -m fixture

    run _vendor_excludes_for "lib" "$src"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/generated"* ]]
}

@test "T-2849 negative control: the pre-fix repo-root form does NOT exclude under rsync's real transfer root" {
    # Same fixture, same rsync call shape do_vendor uses, only the pattern's
    # coordinate system differs. Proves the anchoring claim is falsifiable —
    # if this test's own assertions were wrong, THIS case would fail too.
    command -v rsync >/dev/null || skip "rsync not available"
    local src="$TEST_TEMP_DIR/src"
    mkdir -p "$src/lib/ts/node_modules/pkg"
    echo "x" > "$src/lib/ts/node_modules/pkg/index.js"

    local pre_fix="$TEST_TEMP_DIR/dest_pre_fix"
    mkdir -p "$pre_fix"
    # Pre-fix: pattern in repo-root form, passed straight to the per-include
    # rsync — this is literally what do_vendor did before T-2849.
    rsync -a --exclude="lib/ts/node_modules" "$src/lib/" "$pre_fix/"
    [ -e "$pre_fix/ts/node_modules/pkg/index.js" ]   # ships — the bug, reproduced

    local post_fix="$TEST_TEMP_DIR/dest_post_fix"
    mkdir -p "$post_fix"
    # Post-fix: pattern translated to transfer-root form (what
    # _vendor_excludes_for now emits for this include).
    rsync -a --exclude="ts/node_modules" "$src/lib/" "$post_fix/"
    [ ! -e "$post_fix/ts/node_modules" ]              # excluded — the fix, confirmed
}

@test "T-2849: fresh fw vendor (rsync branch) ships none of the excluded fixture files" {
    command -v rsync >/dev/null || skip "rsync not available"
    local src="$TEST_TEMP_DIR/src_rsync"
    local dest="$TEST_TEMP_DIR/dest_rsync"
    _make_fixture_source "$src"
    mkdir -p "$dest"
    run "$FW_BIN" vendor --target "$dest" --source "$src"
    [ "$status" -eq 0 ]
    _assert_vendor_clean "$dest/.agentic-framework"
}

@test "T-2849: fresh fw vendor (cp -r fallback branch, rsync hidden from PATH) ships none of the excluded fixture files" {
    local src="$TEST_TEMP_DIR/src_cp"
    local dest="$TEST_TEMP_DIR/dest_cp"
    _make_fixture_source "$src"
    mkdir -p "$dest"
    local no_rsync_path
    no_rsync_path="$(_make_no_rsync_path)"
    if PATH="$no_rsync_path" command -v rsync >/dev/null 2>&1; then false; fi   # sanity: the farm really hides rsync

    PATH="$no_rsync_path" run "$FW_BIN" vendor --target "$dest" --source "$src"
    [ "$status" -eq 0 ]
    _assert_vendor_clean "$dest/.agentic-framework"
}

@test "T-2849: vendored tree contains zero files the source's own git check-ignore excludes (anti-vacuity anchor)" {
    command -v rsync >/dev/null || skip "rsync not available"
    local src="$TEST_TEMP_DIR/src_predicate"
    local dest="$TEST_TEMP_DIR/dest_predicate"
    _make_fixture_source "$src"
    mkdir -p "$dest"
    run "$FW_BIN" vendor --target "$dest" --source "$src"
    [ "$status" -eq 0 ]

    # Anti-vacuity anchor: the fixture really did ship an ignored file before
    # the fix existed (proved by the negative-control test above), so this
    # predicate is not trivially satisfied by an empty vendored tree.
    [ -d "$dest/.agentic-framework/lib" ]
    local ignored_shipped=0
    local f rel
    while IFS= read -r -d '' f; do
        rel="${f#"$dest"/.agentic-framework/}"
        [ -f "$src/$rel" ] || continue
        if git -C "$src" check-ignore -q "$rel"; then
            echo "shipped a source-gitignored file: $rel" >&2
            ignored_shipped=1
        fi
    done < <(find "$dest/.agentic-framework/lib" -type f -print0)
    [ "$ignored_shipped" -eq 0 ]
}

@test "T-2849 AC5: re-vendoring over an already-polluted target removes the wrongly-shipped files" {
    command -v rsync >/dev/null || skip "rsync not available"
    local src="$TEST_TEMP_DIR/src_heal"
    local dest="$TEST_TEMP_DIR/dest_heal"
    _make_fixture_source "$src"

    # Simulate a pre-fix consumer: node_modules already present in the
    # vendored copy, as if an old `fw vendor` had shipped it.
    mkdir -p "$dest/.agentic-framework/lib/ts/node_modules/pkg"
    echo "stale" > "$dest/.agentic-framework/lib/ts/node_modules/pkg/index.js"
    [ -e "$dest/.agentic-framework/lib/ts/node_modules" ]  # sanity: pollution really present

    run "$FW_BIN" vendor --target "$dest" --source "$src"
    [ "$status" -eq 0 ]
    _assert_vendor_clean "$dest/.agentic-framework"
}
