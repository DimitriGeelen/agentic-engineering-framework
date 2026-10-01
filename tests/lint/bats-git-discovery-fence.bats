#!/usr/bin/env bats
# T-3610 — a bats file that installs framework hooks or runs `fw init` must fence
# git discovery, so the write cannot land in a repo ABOVE its temp dir.
#
# ORIGIN. On 2026-09-30 this host's stray /.git (T-2787) was written twice:
#   22:30:22  /.git/config gained [user] email=t@t name=T — a consumer project's
#             hook test ran `git init; git config user.email t@t` with its output
#             piped to `head -20`; git init died of SIGPIPE before creating .git,
#             and the silent `git config` walked up to /.git.
#   22:30:59  /.git/hooks/{commit-msg,pre-commit,post-commit,pre-merge-commit,
#             pre-push} rewritten — tests/unit/init_head_bootstrap.bats, run on
#             its own, called `fw init` on a /tmp fixture; with /.git above it
#             the fixture was "a subdirectory of an existing repo", so the hooks
#             went to the root repo (reproduced against a fake root, T-3610).
# Both writes succeeded. Nothing went red except, later, the fixture's own
# assertions — which read like a code regression, not a host write.
#
# THE FENCE is tests/git_fence.bash (GIT_CEILING_DIRECTORIES at the temp roots).
# tests/test_helper.bash sources it, so every file that loads the helper is
# fenced. This lint covers the files that do not.
#
# SCOPE. The rule targets `fw init` and hook installation because those resolve
# their target through git discovery and write into whatever they find. A plain
# `git -C "$X" config` after `git -C "$X" init` is caught by the helper fence
# when the file loads it; that is the helper's job, not this lint's.

FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

# Files owned by concurrent work at the time this lint landed, left for their
# owner to fence. Each must still be an unfenced writer; fence one and this list
# must shrink (leg 2), so it cannot rot into a silent exemption.
GRANDFATHERED=(
    # T-3603 triage range (approvals*..lib_review*)
    tests/unit/audit_root_commit_traceability.bats
    tests/unit/fw_init_atomic.bats
    tests/unit/git_install_hooks_git_path.bats
    tests/unit/hook_version_marker_parity.bats
    tests/unit/init_validation_ordering.bats
    # T-3593 / T-3594 round 4
    tests/unit/t3593_round4_prefix_cdpath_dedup.bats
    tests/unit/t3594_prepush_forced_update_guard.bats
    tests/unit/t3594_round4_tag_keys_commit_n.bats
)

WRITER_RE='install-hooks|install_hooks|(fw|FW|FW_BIN|FW_CMD)"?\}? init\b|bin/fw"? init\b'
FENCE_RE='load +("|'"'"')?(\.\./)*(test_helper|git_fence)|GIT_CEILING_DIRECTORIES'

# Print every .bats under the given root (relative path) that writes via fw
# init / hook install and carries no fence.
_unfenced_writers() {
    local root="$1" f
    while IFS= read -r f; do
        grep -vE '^[[:space:]]*#' "$f" | grep -qE "$WRITER_RE" || continue
        grep -qE "$FENCE_RE" "$f" && continue
        echo "${f#"$root"/}"
    done < <(find "$root/tests" -name '*.bats' 2>/dev/null | sort)
}

_is_grandfathered() {
    local g
    for g in "${GRANDFATHERED[@]}"; do [ "$g" = "$1" ] && return 0; done
    return 1
}

@test "every bats file that runs fw init or installs hooks fences git discovery" {
    local bad=() f
    while IFS= read -r f; do
        _is_grandfathered "$f" || bad+=("$f")
    done < <(_unfenced_writers "$FRAMEWORK_ROOT")
    if [ "${#bad[@]}" -gt 0 ]; then
        {
            echo "These bats files run \`fw init\` or install hooks with no git-discovery fence."
            echo "If their fixture is not a repo, the write lands in the repo above the temp"
            echo "dir — on this host, /.git (T-3610). Fix: add \`load ../test_helper\` or"
            echo "\`load ../git_fence\` near the top of the file."
            printf '  %s\n' "${bad[@]}"
        } >&2
        return 1
    fi
}

@test "grandfather list only names files that are still unfenced writers" {
    local g stale=() live
    live=$(_unfenced_writers "$FRAMEWORK_ROOT")
    for g in "${GRANDFATHERED[@]}"; do
        grep -qxF "$g" <<<"$live" || stale+=("$g")
    done
    if [ "${#stale[@]}" -gt 0 ]; then
        echo "Remove from GRANDFATHERED (gone, fenced, or no longer a writer): ${stale[*]}" >&2
        return 1
    fi
}

@test "negative control: the lint flags an unfenced writer and passes a fenced one" {
    local fx="$BATS_TEST_TMPDIR/corpus"
    mkdir -p "$fx/tests/unit"
    printf '%s\n' '@test "x" { "$FW" init "$D" --provider generic; }' > "$fx/tests/unit/bad.bats"
    printf '%s\n' 'load ../git_fence' '@test "x" { "$FW" init "$D"; }' > "$fx/tests/unit/good_load.bats"
    printf '%s\n' 'export GIT_CEILING_DIRECTORIES="$D"' '@test "x" { bash git.sh install-hooks; }' > "$fx/tests/unit/good_env.bats"
    printf '%s\n' '@test "x" { git -C "$D" status; }' > "$fx/tests/unit/not_a_writer.bats"
    run _unfenced_writers "$fx"
    [ "$status" -eq 0 ]
    [ "$output" = "tests/unit/bad.bats" ]
}

@test "negative control: the fence stops git config and toplevel discovery escaping to a repo above the temp dir" {
    # A fake root stands in for "/": it carries a .git, and TMPDIR lives under it.
    local fr="$BATS_TEST_TMPDIR/fakeroot"
    mkdir -p "$fr/tmp/fixture/sub"
    git -C "$fr" init -q
    local fx="$fr/tmp/fixture/sub"

    # Control — no fence: discovery escapes and the write lands in the fake root.
    run env -u GIT_CEILING_DIRECTORIES bash -c "cd '$fx' && git rev-parse --show-toplevel"
    [ "$status" -eq 0 ]
    [ "$output" = "$fr" ]
    env -u GIT_CEILING_DIRECTORIES bash -c "cd '$fx' && git config user.email t@t"
    grep -q 't@t' "$fr/.git/config"
    git -C "$fr" config --unset user.email

    # Fenced: same commands, no repo found, fake root untouched.
    run env -u GIT_CEILING_DIRECTORIES TMPDIR="$fr/tmp" bash -c \
        "source '$FRAMEWORK_ROOT/tests/git_fence.bash' && cd '$fx' && git rev-parse --show-toplevel"
    [ "$status" -ne 0 ]
    run env -u GIT_CEILING_DIRECTORIES TMPDIR="$fr/tmp" bash -c \
        "source '$FRAMEWORK_ROOT/tests/git_fence.bash' && cd '$fx' && git config user.email t@t"
    [ "$status" -ne 0 ]
    run grep -q 't@t' "$fr/.git/config"
    [ "$status" -ne 0 ]

    # A repo created INSIDE the temp dir is still found from its subdirectory.
    git -C "$fr/tmp/fixture" init -q
    run env -u GIT_CEILING_DIRECTORIES TMPDIR="$fr/tmp" bash -c \
        "source '$FRAMEWORK_ROOT/tests/git_fence.bash' && cd '$fx' && git rev-parse --show-toplevel"
    [ "$status" -eq 0 ]
    [ "$output" = "$fr/tmp/fixture" ]
}

@test "test_helper.bash applies the fence to every file that loads it" {
    run env -u GIT_CEILING_DIRECTORIES bash -c \
        "BATS_TEST_DIRNAME='$FRAMEWORK_ROOT/tests/unit'; source '$FRAMEWORK_ROOT/tests/test_helper.bash' && echo \"\$GIT_CEILING_DIRECTORIES\""
    [ "$status" -eq 0 ]
    [[ ":$output:" == *":/tmp:"* ]]
}
