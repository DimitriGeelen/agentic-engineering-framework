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

# T-4260 (F-16): a freshly initialised project has NO tracked task files, so
# `git status --porcelain` (default -unormal) collapsed the whole directory to
# one entry and doctor reported "1" for five seeded tasks.
@test "untracked-tasks: wholly-untracked directory lists every file (T-4260)" {
    FRESH="$BATS_TEST_TMPDIR/fresh"
    mkdir -p "$FRESH/.tasks/active"
    git init -q -b master "$FRESH"
    for n in 1 2 3; do printf -- '---\nid: T-00%s\n---\n' "$n" > "$FRESH/.tasks/active/T-00$n-x.md"; done
    run fw_untracked_tasks "$FRESH"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c .)" -eq 3 ]
    echo "$output" | grep -q "^.tasks/active/T-002-x.md$"
}

# T-4260 (F-16): a project nested in an enclosing repo got toplevel-relative
# paths (sub/.tasks/...), not project-relative ones.
@test "untracked-tasks: project nested in an enclosing repo → project-relative paths (T-4260)" {
    mkdir -p "$REPO/sub/.tasks/active"
    printf -- '---\nid: T-001\n---\n' > "$REPO/sub/.tasks/active/T-001-x.md"
    run fw_untracked_tasks "$REPO/sub"
    [ "$status" -eq 0 ]
    [ "$output" = ".tasks/active/T-001-x.md" ]
}

# T-4260 (F-16): init-seeded onboarding tasks must not be offered for removal;
# the doctor needs to know which untracked files they are.
@test "untracked-onboarding: names only onboarding-tagged untracked tasks (T-4260)" {
    printf -- '---\nid: T-001\ntags: [onboarding]\n---\n' > .tasks/active/T-001-seed.md
    printf -- '---\nid: T-002\ntags: [onboarding, inception]\n---\n' > .tasks/active/T-002-seed.md
    printf -- '---\nid: T-200\ntags: [bug]\n---\n' > .tasks/completed/T-200-orphan.md
    run fw_untracked_onboarding_tasks "$REPO"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c .)" -eq 2 ]
    echo "$output" | grep -q "^.tasks/active/T-001-seed.md$"
    ! echo "$output" | grep -q "T-200" || false
}

@test "untracked-onboarding: tracked onboarding task is NOT listed (T-4260)" {
    printf -- '---\nid: T-001\ntags: [onboarding]\n---\n' > .tasks/active/T-001-seed.md
    git add -A && git commit -qm seed
    run fw_untracked_onboarding_tasks "$REPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "untracked-tasks: non-git directory → empty, exit 0 (no crash)" {
    run fw_untracked_tasks "$BATS_TEST_TMPDIR/not-a-repo"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
