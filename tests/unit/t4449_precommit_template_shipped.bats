#!/usr/bin/env bats
# T-4449 — the pre-commit hook refuses a commit that stages .tasks/templates/*.md
# while the STAGED lib/upgrade_template_shipped.py is not current (generate_known
# differs). Third occurrence of the class (T-4035, T-4213, T-4441): before this,
# only the nightly test_upgrade_template_sync_t3955 noticed, a day later.
#
# Hermetic: same fixture shape as t4379_precommit_dead_negation.bats — hooks are
# installed into a temp repo whose .framework.yaml points at this checkout; the
# hook is run directly, no commit is made.

load ../git_fence

setup() {
    FW_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    FX="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$FX/.tasks/templates" "$FX/lib"
    git -C "$FX" init -q
    git -C "$FX" config user.email "t4449@localhost"
    git -C "$FX" config user.name "T-4449 fixture"
    printf 'framework_path: %s\n' "$FW_ROOT" > "$FX/.framework.yaml"
    cp "$FW_ROOT/lib/upgrade_template_sync.py" "$FX/lib/"
    printf 'v1\n' > "$FX/.tasks/templates/default.md"
    git -C "$FX" add .tasks lib .framework.yaml
    git -C "$FX" commit -q -m "fixture: v1 template" --no-verify
    _gen
    git -C "$FX" add lib/upgrade_template_shipped.py
    git -C "$FX" commit -q -m "fixture: shipped list" --no-verify
    export PROJECT_ROOT="$FX"
    run bash "$FW_ROOT/agents/git/git.sh" install-hooks
    [ "$status" -eq 0 ]
    [ -f "$FX/.git/hooks/pre-commit" ]
}

_gen() {
    (cd "$FX" && python3 lib/upgrade_template_sync.py --gen-known "$FX" >/dev/null)
}

_precommit() {
    run bash -c "cd '$FX' && PROJECT_ROOT='$FX' .git/hooks/pre-commit"
}

@test "a staged template edit with a stale shipped list is refused, naming the regenerate command" {
    printf 'v2\n' > "$FX/.tasks/templates/default.md"
    git -C "$FX" add .tasks/templates/default.md
    _precommit
    [ "$status" -ne 0 ]
    [[ "$output" == *"upgrade_template_shipped.py is not current"* ]]
    [[ "$output" == *".tasks/templates/default.md"* ]]
    [[ "$output" == *"--gen-known"* ]]
}

@test "the same edit with the regenerated list staged passes" {
    printf 'v2\n' > "$FX/.tasks/templates/default.md"
    _gen
    git -C "$FX" add .tasks/templates/default.md lib/upgrade_template_shipped.py
    _precommit
    [ "$status" -eq 0 ]
    [[ "$output" != *"not current"* ]]
}

@test "regenerated but NOT staged is still refused (the staged list is what ships)" {
    printf 'v2\n' > "$FX/.tasks/templates/default.md"
    _gen
    git -C "$FX" add .tasks/templates/default.md
    _precommit
    [ "$status" -ne 0 ]
    [[ "$output" == *"not current"* ]]
}

@test "a new template file is caught too" {
    printf 'new\n' > "$FX/.tasks/templates/inception.md"
    git -C "$FX" add .tasks/templates/inception.md
    _precommit
    [ "$status" -ne 0 ]
    [[ "$output" == *".tasks/templates/inception.md"* ]]
}

@test "a commit that stages no template is not checked" {
    printf 'v2\n' > "$FX/.tasks/templates/default.md"
    printf 'x\n' > "$FX/other.txt"
    git -C "$FX" add other.txt
    _precommit
    [ "$status" -eq 0 ]
    [[ "$output" != *"not current"* ]]
}
