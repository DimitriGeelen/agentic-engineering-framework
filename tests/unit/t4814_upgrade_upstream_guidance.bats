#!/usr/bin/env bats
# T-4814 (ring20 be.37 field test A): fw upgrade kept a locally edited
# .claude/commands/*.md and wrote the new template beside it as <file>.upstream,
# then said nothing about it: the `git add` line did not name it (on a re-run the
# .upstream was already untracked with the same bytes, so the T-4692 list dropped
# it) and no line said whether to keep, merge or delete it.
#
# Surfaces under test:
#   _t4814_emit_upstream_list         (lib/upgrade.sh) — one action line per file
#   lib/upgrade_commit_list.py report — *.upstream never in the git add line
#   do_upgrade end to end, first run and re-run

load ../test_helper
load ../git_fence

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export NO_COLOR=1
    HELPER="$FRAMEWORK_ROOT/lib/upgrade_commit_list.py"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "T-4814: _t4814_emit_upstream_list prints one action line per .upstream; silent when empty" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/upgrade.sh' >/dev/null 2>&1; _t4814_emit_upstream_list /x"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run bash -c "source '$FRAMEWORK_ROOT/lib/upgrade.sh' >/dev/null 2>&1; _t4814_emit_upstream_list /x .claude/commands/a.md .claude/commands/a.md '.tasks/templates/b c.md'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cd /x"* ]]
    [ "$(printf '%s\n' "$output" | grep -c 'diff -u .claude/commands/a.md .claude/commands/a.md.upstream')" -eq 1 ]
    [[ "$output" == *"diff -u .tasks/templates/b\\ c.md .tasks/templates/b\\ c.md.upstream"* ]]
    [[ "$output" == *"keep yours"* ]]
    [[ "$output" == *"take upstream"* ]]
    [[ "$output" == *"merge"* ]]
    [[ "$output" == *"not committed"* ]]
}

@test "T-4814: report keeps *.upstream out of the git add line and says so" {
    R="$TEST_TEMP_DIR/r"
    mkdir -p "$R/.claude/commands" && git -C "$R" init -q
    echo mine > "$R/.claude/commands/x.md"
    git -C "$R" add . && git -C "$R" -c user.email=t@t -c user.name=t commit -qm base
    python3 "$HELPER" snapshot "$R" > "$TEST_TEMP_DIR/before"
    echo tmpl > "$R/.claude/commands/x.md.upstream"
    echo new > "$R/other.txt"
    printf '%s\n' .claude/commands/x.md .claude/commands/x.md.upstream other.txt > "$TEST_TEMP_DIR/wrote"
    run python3 "$HELPER" report "$R" "$TEST_TEMP_DIR/before" "$TEST_TEMP_DIR/wrote"
    [ "$status" -eq 0 ]
    [[ "$output" == *"git add -- other.txt"* ]]
    ! printf '%s\n' "$output" | grep 'git add --' | grep -q '\.upstream' || false
    [[ "$output" == *"1 .upstream"*"left out of the git add line on purpose"* ]]
}

@test "T-4814: report with only *.upstream changed prints no empty git add line" {
    R="$TEST_TEMP_DIR/r"
    mkdir -p "$R" && git -C "$R" init -q
    python3 "$HELPER" snapshot "$R" > "$TEST_TEMP_DIR/before"
    echo tmpl > "$R/y.md.upstream"
    echo y.md.upstream > "$TEST_TEMP_DIR/wrote"
    run python3 "$HELPER" report "$R" "$TEST_TEMP_DIR/before" "$TEST_TEMP_DIR/wrote"
    [ "$status" -eq 0 ]
    ! printf '%s\n' "$output" | grep -q 'git add --' || false
    [[ "$output" == *"left out of the git add line on purpose"* ]]
}

@test "T-4814: fw upgrade names every .upstream it wrote with an action, first run and re-run" {
    C="$TEST_TEMP_DIR/consumer"
    mkdir -p "$C" && cd "$C" && git init -q && git config user.email t@t && git config user.name t
    "$FRAMEWORK_ROOT/bin/fw" init . >/dev/null 2>&1 || true
    [ -f "$C/.claude/commands/resume.md" ] || { echo "fw init created no resume.md"; false; }
    printf '\n<!-- ring20: our own resume notes -->\n' >> "$C/.claude/commands/resume.md"
    git add -A >/dev/null 2>&1 && git commit -qm base >/dev/null 2>&1 || true

    run env PROJECT_ROOT="$C" timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$C"
    [ -f "$C/.claude/commands/resume.md.upstream" ]
    [[ "$output" == *"diff -u .claude/commands/resume.md .claude/commands/resume.md.upstream"* ]]
    ! printf '%s\n' "$output" | grep 'git add --' | grep -q '\.upstream' || false

    # re-run: the .upstream is already untracked with the same bytes — still named
    run env PROJECT_ROOT="$C" timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$C"
    [[ "$output" == *"diff -u .claude/commands/resume.md .claude/commands/resume.md.upstream"* ]]
}
