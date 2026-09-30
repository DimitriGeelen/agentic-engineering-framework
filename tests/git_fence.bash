# tests/git_fence.bash — stop git discovery from escaping a test fixture (T-3610)
#
# Loaded by tests/test_helper.bash, and directly (`load ../git_fence`) by any
# bats file that does not use the shared helper but writes git state.
#
# WHY. git finds "the repo" by walking up from cwd until it meets a .git. A
# fixture dir under /tmp that is not itself a repo — because `git init` was
# never run, failed, or was killed (SIGPIPE when output is piped to `head`) —
# therefore resolves to whatever repo sits ABOVE the temp dir. On this host
# that was a stray /.git, and on 2026-09-30:
#   - `git config user.email t@t` in such a dir wrote /.git/config (22:30:22);
#   - `fw init <fixture>` treated the fixture as a subdirectory of / and
#     installed the framework hooks into /.git/hooks (22:30:59).
# Nothing failed loudly: both commands succeeded, against the wrong repo.
#
# WHAT. GIT_CEILING_DIRECTORIES stops the walk before it can climb into the temp
# root or anything above it. A repo created INSIDE a temp dir is still found
# from its subdirectories; only the temp root itself and its ancestors are off
# limits. Directories outside the temp roots (the framework checkout that tests
# read from) are unaffected, because a ceiling only applies to its descendants.
#
# A file that sets its own narrower GIT_CEILING_DIRECTORIES keeps it: the fence
# appends, it does not replace.

fence_git_discovery() {
    local c cur="${GIT_CEILING_DIRECTORIES:-}" d
    for d in /tmp "${TMPDIR:-}" "${BATS_RUN_TMPDIR:+$(dirname "$BATS_RUN_TMPDIR")}"; do
        [ -n "$d" ] || continue
        d="${d%/}"
        [ -n "$d" ] || continue          # never "/" — that would fence nothing useful
        case ":$cur:" in *":$d:"*) continue ;; esac
        c="${c:+$c:}$d"
    done
    GIT_CEILING_DIRECTORIES="${cur:+$cur:}${c:-}"
    export GIT_CEILING_DIRECTORIES
}

fence_git_discovery
