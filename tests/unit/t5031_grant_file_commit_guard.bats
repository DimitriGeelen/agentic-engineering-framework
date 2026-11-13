#!/usr/bin/env bats
# T-5031 (ring20-dashboard a14cb4c1, HIGH; G-129): a commit under agent control (CLAUDECODE=1)
# may not change policy/access-grants.yaml — the file is read from HEAD, so the commit is what
# makes a grant count. Exercises the REAL pre-commit / pre-merge-commit hooks that
# `git.sh install-hooks` writes; the operator's commit (no CLAUDECODE) still works.

load ../git_fence

setup() {
    _FW_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    GIT_AGENT="$_FW_ROOT/agents/git/git.sh"
    TEST_ROOT="$(mktemp -d)"
    R="$TEST_ROOT/proj"
    mkdir -p "$R/policy" "$R/.tasks/active" "$R/.context/working" "$R/lib"
    git -C "$R" init -q
    git -C "$R" config user.email t@t
    git -C "$R" config user.name t
    echo "task" > "$R/.tasks/active/T-0001-x.md"
    echo "src" > "$R/lib/a.sh"
    printf 'framework_path: %s\n' "$_FW_ROOT" > "$R/.framework.yaml"
    printf 'grants: []\n' > "$R/policy/access-grants.yaml"
    git -C "$R" add -A >/dev/null 2>&1
    git -C "$R" commit -qm "T-0001: fixture" -m "Grants-Change: operator" >/dev/null 2>&1
    PROJECT_ROOT="$R" bash "$GIT_AGENT" install-hooks --force >/dev/null 2>&1
    [ -f "$R/.git/hooks/pre-commit" ] || { echo "install-hooks wrote no pre-commit"; false; }
    # Only pre-commit / pre-merge-commit are on trial; the others gate on unrelated things.
    rm -f "$R/.git/hooks/commit-msg" "$R/.git/hooks/post-commit" "$R/.git/hooks/pre-push"
    WIDER=$'grants:\n  - path: /srv/x\n    level: create\n    via: /srv/x\n'
}

teardown() { rm -rf "$TEST_ROOT"; }

agent() { run env CLAUDECODE=1 git -C "$R" "$@"; }
operator() { run env -u CLAUDECODE git -C "$R" "$@"; }
head_grants() { git -C "$R" show HEAD:policy/access-grants.yaml; }

@test "agent: commit of a staged grant-file change is refused, HEAD unchanged" {
    printf '%s' "$WIDER" > "$R/policy/access-grants.yaml"
    git -C "$R" add policy/access-grants.yaml
    agent commit -qm "T-0001: widen"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ACCESS GRANTS"* ]]
    [ "$(head_grants)" = "grants: []" ]
}

@test "agent: commit -a of the operator's uncommitted edit is refused" {
    printf '%s' "$WIDER" > "$R/policy/access-grants.yaml"
    agent commit -aqm "T-0001: sweep"
    [ "$status" -ne 0 ]
    [ "$(head_grants)" = "grants: []" ]
}

@test "agent: deleting the grant file by commit is refused" {
    git -C "$R" rm -q policy/access-grants.yaml
    agent commit -qm "T-0001: drop"
    [ "$status" -ne 0 ]
}

@test "agent: renaming the grant file away is refused" {
    git -C "$R" mv policy/access-grants.yaml policy/old.yaml
    agent commit -qm "T-0001: rename"
    [ "$status" -ne 0 ]
}

@test "agent: checkout of the file from another branch, then commit, is refused" {
    git -C "$R" checkout -qb wide
    printf '%s' "$WIDER" > "$R/policy/access-grants.yaml"
    env -u CLAUDECODE git -C "$R" commit -qam "T-0001: wide (operator)" -m "Grants-Change: operator"
    git -C "$R" checkout -q -
    git -C "$R" checkout wide -- policy/access-grants.yaml
    agent commit -qm "T-0001: take it"
    [ "$status" -ne 0 ]
    [ "$(head_grants)" = "grants: []" ]
}

@test "agent: a merge commit that brings a grant-file change is refused (pre-merge-commit)" {
    base=$(git -C "$R" symbolic-ref --short HEAD)
    git -C "$R" checkout -qb wide
    printf '%s' "$WIDER" > "$R/policy/access-grants.yaml"
    env -u CLAUDECODE git -C "$R" commit -qam "T-0001: wide (operator)" -m "Grants-Change: operator"
    git -C "$R" checkout -q "$base"
    echo more >> "$R/lib/a.sh"; git -C "$R" commit -qam "T-0001: diverge"
    agent merge --no-ff --no-edit wide
    [ "$status" -ne 0 ]
    [ "$(head_grants)" = "grants: []" ]
}

@test "operator (no CLAUDECODE): the grant-file commit goes through" {
    printf '%s' "$WIDER" > "$R/policy/access-grants.yaml"
    git -C "$R" add policy/access-grants.yaml
    operator commit -qm "T-0001: widen" -m "Grants-Change: operator"
    [ "$status" -eq 0 ]
    [[ "$(head_grants)" == *"/srv/x"* ]]
}

@test "control: an agent commit that does not touch the grant file is allowed" {
    echo more >> "$R/lib/a.sh"
    git -C "$R" add lib/a.sh
    agent commit -qm "T-0001: src"
    [ "$status" -eq 0 ]
}

@test "the guard script alone: CLAUDECODE unset allows, set refuses a staged change" {
    printf '%s' "$WIDER" > "$R/policy/access-grants.yaml"
    git -C "$R" add policy/access-grants.yaml
    run env -u CLAUDECODE bash -c "cd '$R' && bash '$_FW_ROOT/agents/git/lib/grant-file-guard.sh'"
    [ "$status" -eq 0 ]
    run env CLAUDECODE=1 bash -c "cd '$R' && bash '$_FW_ROOT/agents/git/lib/grant-file-guard.sh'"
    [ "$status" -eq 1 ]
}
