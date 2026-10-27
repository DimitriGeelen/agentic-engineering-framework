#!/usr/bin/env bats
# T-4823: the upgrade's one `git add` line stages the designer build it
# installed AND the removal of the build it replaced.
#
# 055 be.37 field report (msg a5d08b2a): the new pinned build under
# vendor/designer/ was not committed with the other upgraded files. Reproduced:
# a TRACKED superseded build was only printed as "KEPT ... git rm" (T-4736),
# outside the T-4692 commit list, so following "Commit them with: git add --"
# committed the new build next to the old one, and the old one stayed.
#
# Rule under test: once the pinned build is in place, a superseded root build
# that is tracked, byte-identical to the published AEF build and unchanged
# against HEAD is removed and journalled; the commit list shows it as deleted
# and the same git add line stages the removal. Locally modified tracked builds
# are still kept.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4823-XXXXXX)"
    REAL_FW="$FRAMEWORK_ROOT"
    export NO_COLOR=1
    DESIGNER_SH="$REAL_FW/agents/designer/designer.sh"
    HELPER="$REAL_FW/lib/upgrade_commit_list.py"
    source "$REAL_FW/lib/colors.sh"
    source "$REAL_FW/lib/upgrade.sh"
    source "$REAL_FW/lib/init.sh"

    PROJ="$TEST_TEMP_DIR/proj"
    SRC="$TEST_TEMP_DIR/src-fw"
    _put_build "$SRC" 0.8.0
    _put_build "$SRC" 0.9.0
    _put_build "$PROJ/.agentic-framework" 0.9.0
    mkdir -p "$PROJ/.agentic-framework/bin"
    cat > "$PROJ/.agentic-framework/bin/fw" <<SHIM
#!/usr/bin/env bash
[ "\$1" = "designer" ] || { echo "unexpected: \$*" >&2; exit 99; }
exec env PROJECT_ROOT="\${PROJECT_ROOT}" FRAMEWORK_ROOT="$PROJ/.agentic-framework" \\
    bash "$DESIGNER_SH" "\$2"
SHIM
    chmod +x "$PROJ/.agentic-framework/bin/fw"
    git -C "$PROJ" init -q
    git -C "$PROJ" config user.email t@t
    git -C "$PROJ" config user.name t
    # The consumer commits its vendored tree and its installed 0.8.0 build.
    mkdir -p "$PROJ/vendor/designer"
    printf 'DESIGNER-BUILD-0.8.0' > "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html"
    chmod 0444 "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html"
    git -C "$PROJ" add -A
    git -C "$PROJ" commit -qm "T-001: consumer with designer 0.8.0"
    FRAMEWORK_ROOT="$SRC"
    BEFORE="$TEST_TEMP_DIR/before.snap"
    _t4697_log="$TEST_TEMP_DIR/wrote.journal"
    : > "$_t4697_log"
}

teardown() {
    FRAMEWORK_ROOT="$REAL_FW"
    [ -d "${TEST_TEMP_DIR:-}" ] && chmod -R u+w "$TEST_TEMP_DIR" 2>/dev/null
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

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

# snapshot → designer sync (journalled, as in do_upgrade step 4b) → report
_upgrade_designer() {
    python3 "$HELPER" snapshot "$PROJ" > "$BEFORE"
    _t4672_sync_designer "$PROJ" false > "$TEST_TEMP_DIR/sync.out" 2>&1
    python3 "$HELPER" report "$PROJ" "$BEFORE" "$_t4697_log"
}

@test "tracked published old build: git add line names the new build and the removed old one" {
    run _upgrade_designer
    [ "$status" -eq 0 ]
    [[ "$output" == *"new       vendor/designer/aef-workflow-designer-0.9.0.html"* ]]
    [[ "$output" == *"deleted   vendor/designer/aef-workflow-designer-0.8.0.html"* ]]
    printf '%s\n' "$output" | grep -F 'git add -- ' > "$TEST_TEMP_DIR/add"
    [ "$(wc -l < "$TEST_TEMP_DIR/add")" -eq 1 ]
    grep -qF 'vendor/designer/aef-workflow-designer-0.9.0.html' "$TEST_TEMP_DIR/add"
    grep -qF 'vendor/designer/aef-workflow-designer-0.8.0.html' "$TEST_TEMP_DIR/add"
    grep -q "REMOVED.*aef-workflow-designer-0.8.0.html" "$TEST_TEMP_DIR/sync.out"
    ! grep -q "KEPT" "$TEST_TEMP_DIR/sync.out" || false
}

@test "running the printed git add line stages both: nothing designer-related is left unstaged" {
    run _upgrade_designer
    [ "$status" -eq 0 ]
    local line
    line=$(printf '%s\n' "$output" | grep -F 'git add -- ' | sed 's/^ *//')
    bash -c "$line"
    git -C "$PROJ" status --porcelain -- vendor/designer > "$TEST_TEMP_DIR/st"
    grep -q '^A  vendor/designer/aef-workflow-designer-0.9.0.html$' "$TEST_TEMP_DIR/st"
    grep -q '^D  vendor/designer/aef-workflow-designer-0.8.0.html$' "$TEST_TEMP_DIR/st"
    ! grep -q '^.[^ ]' "$TEST_TEMP_DIR/st" || false
}

@test "tracked old build with local edits is kept, with its git rm hint" {
    chmod u+w "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html"
    printf 'DESIGNER-BUILD-0.8.0-patched' > "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html"
    git -C "$PROJ" commit -qam "T-001: patched designer"
    run _upgrade_designer
    [ "$status" -eq 0 ]
    [ -f "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html" ]
    grep -q "KEPT" "$TEST_TEMP_DIR/sync.out"
    [[ "$output" != *"aef-workflow-designer-0.8.0.html"* ]]
}

@test "tracked published build dirty against HEAD is kept" {
    # committed bytes differ, working copy matches the published build: the
    # commit is the project's own, so the upgrade does not remove it
    chmod u+w "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html"
    printf 'PROJECT-OWN' > "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html"
    git -C "$PROJ" commit -qam "T-001: own bytes"
    printf 'DESIGNER-BUILD-0.8.0' > "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html"
    run _upgrade_designer
    [ -f "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html" ]
    grep -q "KEPT" "$TEST_TEMP_DIR/sync.out"
}

@test "--dry-run names the removal and deletes nothing" {
    rm -rf "$PROJ/.agentic-framework/policy" "$PROJ/.agentic-framework/vendor"
    run _t4672_sync_designer "$PROJ" true
    [ "$status" -eq 0 ]
    [[ "$output" == *"WOULD REMOVE"*"aef-workflow-designer-0.8.0.html"* ]]
    [ -f "$PROJ/vendor/designer/aef-workflow-designer-0.8.0.html" ]
}
