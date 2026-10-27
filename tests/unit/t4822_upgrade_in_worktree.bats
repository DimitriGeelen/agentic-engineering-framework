#!/usr/bin/env bats
# T-4822: fw upgrade / fw cron generate in a LINKED WORKTREE of a consumer.
#
# Field report (055, be.37, msg a5d08b2a; be.21 items 1-2): 055 upgrades in a
# linked worktree as standard practice, and
#   1. needed FW_REEXEC_DEPTH=1, because the auto-clone handoff runs the clone's
#      bin/fw with PROJECT_ROOT=<worktree>, and the T-3111 authority redirect
#      then exec'd the MAIN checkout's vendored fw — the upgrade ran the old
#      code, not the upstream it had just cloned;
#   2. got .context/cron/agentic-audit.crontab (git-tracked) rewritten with the
#      worktree's paths, which then merged into the main checkout.
#
# Fixture: a real consumer made by `fw init` in a temp git repo, a real
# `git worktree add` of it, and a file:// upstream that is one commit AHEAD of
# the vendored copy (the commit adds a marker file), so "which code ran the
# upgrade" has an observable answer. Temp repos only — never this repo.

load ../git_fence

setup_file() {
    export FW_SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export S="$(mktemp -d)"
    export UP="$S/up.git" PROJ="$S/proj" WT="$S/wt"

    git clone -q --bare --shared "$FW_SRC" "$UP"
    git clone -q "$UP" "$S/upwork"
    git -C "$S/upwork" config user.email t@t
    git -C "$S/upwork" config user.name t
    # The upstream is the release under test: the code this file guards, as it
    # stands in the checkout running the test (identical to HEAD once committed).
    local f
    for f in bin/fw lib/upgrade.sh lib/cron-registry.sh agents/audit/audit.sh; do
        cp "$FW_SRC/$f" "$S/upwork/$f"
    done
    echo "# T-4822 marker: only the upstream clone has this file" > "$S/upwork/lib/t4822-upstream-marker.sh"
    git -C "$S/upwork" add -A
    git -C "$S/upwork" commit -qm "T-4822: upstream-only marker"
    git -C "$S/upwork" push -q origin HEAD

    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    git -C "$PROJ" config user.email t@t
    git -C "$PROJ" config user.name t
    (cd "$PROJ" && env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u CLAUDECODE -u CLAUDE_PROJECT_DIR \
        -u FW_REEXEC_DEPTH "$FW_SRC/bin/fw" init . --provider claude >/dev/null 2>&1)
    sed -i "s#^upstream_repo:.*#upstream_repo: file://$UP#" "$PROJ/.framework.yaml"
    # Hooks off in the fixture: the commit is fixture setup, not governed work.
    mv "$PROJ/.git/hooks" "$PROJ/.git/hooks.off"
    git -C "$PROJ" add -A >/dev/null 2>&1
    git -C "$PROJ" commit -qm "fixture" >/dev/null 2>&1 || true
    git -C "$PROJ" worktree add -q "$WT" -b wt-branch >/dev/null 2>&1
}

teardown_file() {
    [ -n "${S:-}" ] && rm -rf "$S"
}

# The operator's shell inside the worktree: nothing inherited, minimal PATH.
_wt_run() {
    (cd "$WT" && env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$S/home" \
        "$WT/.agentic-framework/bin/fw" "$@")
}

@test "fixture sanity: worktree is linked, crontab tracked with main-checkout paths, marker only upstream" {
    [ "$(git -C "$WT" rev-parse --git-dir)" != "$(git -C "$WT" rev-parse --git-common-dir)" ]
    git -C "$PROJ" ls-files --error-unmatch .context/cron/agentic-audit.crontab >/dev/null
    grep -q "cd \"$PROJ\"" "$WT/.context/cron/agentic-audit.crontab"
    [ ! -e "$WT/.agentic-framework/lib/t4822-upstream-marker.sh" ]
}

@test "fw cron generate in a linked worktree renders the main checkout's paths (tracked file unchanged)" {
    run _wt_run cron generate
    [ "$status" -eq 0 ]
    ! grep -q "$WT" "$WT/.context/cron/agentic-audit.crontab" || false
    git -C "$WT" diff --quiet -- .context/cron/agentic-audit.crontab
}

@test "fw doctor in the worktree reports no registry→generated drift for the main-path crontab" {
    run _wt_run doctor
    [[ "$output" != *"Cron registry edited but not generated"* ]]
}

@test "fw upgrade in a linked worktree runs the upstream clone (no FW_REEXEC_DEPTH needed) and keeps main-checkout cron paths" {
    run _wt_run upgrade
    [ "$status" -eq 0 ]
    # 1: the upstream's code was synced — the redirect did not swap in the
    #    main checkout's vendored copy.
    [ -f "$WT/.agentic-framework/lib/t4822-upstream-marker.sh" ]
    # 2: the regenerated tracked crontab names the main checkout, never the worktree.
    ! grep -q "$WT" "$WT/.context/cron/agentic-audit.crontab" || false
    grep -q "cd \"$PROJ\"" "$WT/.context/cron/agentic-audit.crontab"
    # And the main checkout was not touched by an upgrade aimed at the worktree.
    [ ! -e "$PROJ/.agentic-framework/lib/t4822-upstream-marker.sh" ]
}

@test "upgrade of a worktree through a tag clone's bin/fw is not redirected to the main checkout's fw" {
    # 055's shape: a non-shallow clone of the tag, its bin/fw run against the
    # worktree, and a main checkout with a root bin/fw — the T-3111 redirect
    # target. Before the fix the redirect exec'd that fw (the main checkout's
    # OLD vendored code), so the upstream marker never arrived unless the
    # operator exported FW_REEXEC_DEPTH=1.
    local wt2="$S/wt2"
    git -C "$PROJ" worktree add -q "$wt2" -b wt2-branch >/dev/null 2>&1
    mkdir -p "$PROJ/bin"
    ln -sf ../.agentic-framework/bin/fw "$PROJ/bin/fw"
    run bash -c "cd '$wt2' && env -i PATH=/usr/local/bin:/usr/bin:/bin HOME='$S/home' \
        '$S/upwork/bin/fw' upgrade '$wt2' 2>&1"
    rm -f "$PROJ/bin/fw"
    [ "$status" -eq 0 ]
    [ -f "$wt2/.agentic-framework/lib/t4822-upstream-marker.sh" ]
    ! grep -q "$wt2" "$wt2/.context/cron/agentic-audit.crontab" || false
}
