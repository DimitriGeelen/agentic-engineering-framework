#!/usr/bin/env bats
# T-2516 (T-2121 prong 3): fw_untracked_tasks in lib/branch-hygiene.sh.
#
# Early-detection rail for the active↔completed divergence class (T-2091): an
# orphaned untracked completion copy that never got committed was invisible for
# ~7 days because nothing surfaced untracked files under .tasks/. These tests
# pin both branches (clean → empty, untracked → named) plus the two things the
# check must NOT flag: gitignored files and merely-modified (tracked) files.
#
# Fixture: a plain git repo with tracked task files under .tasks/{active,completed}/.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$REPO/.tasks/active" "$REPO/.tasks/completed"
    cd "$REPO"
    git init -q -b master "$REPO"
    git config user.email t@t && git config user.name t
    printf -- '---\nid: T-100\nstatus: started-work\n---\n' > .tasks/active/T-100-a.md
    printf -- '---\nid: T-101\nstatus: work-completed\n---\n' > .tasks/completed/T-101-b.md
    git add -A && git commit -qm "seed tracked task files"
    # shellcheck disable=SC1091
    . "$REPO_ROOT/lib/branch-hygiene.sh"
}

@test "untracked-tasks: clean tree (all tracked) → empty output, exit 0" {
    run fw_untracked_tasks "$REPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "untracked-tasks: untracked file in active/ → path named" {
    printf -- '---\nid: T-200\n---\n' > .tasks/active/T-200-orphan.md
    run fw_untracked_tasks "$REPO"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^.tasks/active/T-200-orphan.md$"
}

@test "untracked-tasks: untracked file in completed/ → path named (T-2091 divergence shape)" {
    printf -- '---\nid: T-201\nstatus: work-completed\n---\n' > .tasks/completed/T-201-orphan.md
    run fw_untracked_tasks "$REPO"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^.tasks/completed/T-201-orphan.md$"
}

@test "untracked-tasks: gitignored file is NOT flagged" {
    echo '.tasks/active/*.tmp' > .gitignore
    git add .gitignore && git commit -qm "ignore tmp"
    printf 'scratch\n' > .tasks/active/scratch.tmp
    run fw_untracked_tasks "$REPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "untracked-tasks: modified (tracked) file is NOT flagged — only untracked" {
    printf -- '---\nid: T-100\nstatus: work-completed\n---\n' > .tasks/active/T-100-a.md
    run fw_untracked_tasks "$REPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "untracked-tasks: non-git directory → empty, exit 0 (no crash)" {
    run fw_untracked_tasks "$BATS_TEST_TMPDIR/not-a-repo"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
