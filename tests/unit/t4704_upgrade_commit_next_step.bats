#!/usr/bin/env bats
# T-4704: fw upgrade "Next steps" item 2 must name the consumer's focused task,
# never a fixed id. It printed T-012 (the framework's own task) in every consumer,
# and quoting it tripped the consumer's focus-drift gate (dimitri-mint-dev be.9).

setup() {
    U="$BATS_TEST_DIRNAME/../../lib/upgrade.sh"
    eval "$(awk '/^_t4704_commit_next_step\(\) \{/{p=1} p{print} p&&/^\}/{exit}' "$U")"
    C="$BATS_TEST_TMPDIR/consumer"
    mkdir -p "$C/.context/working"
}

@test "focused task: the commit step names it, no placeholder, no work-on line" {
    printf '# Working Memory\ncurrent_task: T-0042\npriorities: []\n' > "$C/.context/working/focus.yaml"
    run _t4704_commit_next_step "$C"
    [ "$status" -eq 0 ]
    [ "$output" = "  2. Commit: cd $C && fw git commit -m 'T-0042: fw upgrade — sync framework improvements'" ]
}

@test "quoted focused id is read too" {
    printf "current_task: 'T-7'\n" > "$C/.context/working/focus.yaml"
    run _t4704_commit_next_step "$C"
    [[ "$output" == *"fw git commit -m 'T-7: fw upgrade"* ]]
}

@test "no focus.yaml: T-XXXX placeholder, preceded by fw work-on" {
    run _t4704_commit_next_step "$C"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "${lines[0]}" == *"fw work-on \"framework upgrade\" --type build"* ]]
    [[ "${lines[1]}" == *"fw git commit -m 'T-XXXX: fw upgrade"* ]]
}

@test "empty, null or non-task focus: placeholder, never a fixed id" {
    for v in "" "null" "WM-001"; do
        printf 'current_task: %s\n' "$v" > "$C/.context/working/focus.yaml"
        run _t4704_commit_next_step "$C"
        [[ "$output" == *"T-XXXX:"* ]]
        [[ "$output" == *"fw work-on"* ]]
        [[ "$output" != *"WM-001"* ]]
    done
}

@test "do_upgrade wiring: Next steps calls the helper and prints no fixed T-012" {
    grep -q '_t4704_commit_next_step "\$target_dir"' "$U"
    ! grep -E "^[[:space:]]*echo .*T-012" "$U" || false
}
