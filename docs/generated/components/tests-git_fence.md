# git_fence

> tests/git_fence.bash — stop git discovery from escaping a test fixture (T-3610)

**Type:** script | **Subsystem:** tests | **Location:** `tests/git_fence.bash`

## What It Does

tests/git_fence.bash — stop git discovery from escaping a test fixture (T-3610)
Loaded by tests/test_helper.bash, and directly (`load ../git_fence`) by any
bats file that does not use the shared helper but writes git state.
WHY. git finds "the repo" by walking up from cwd until it meets a .git. A
fixture dir under /tmp that is not itself a repo — because `git init` was
never run, failed, or was killed (SIGPIPE when output is piped to `head`) —
therefore resolves to whatever repo sits ABOVE the temp dir. On this host
that was a stray /.git, and on 2026-09-30:
- `git config user.email t@t` in such a dir wrote /.git/config (22:30:22);
- `fw init <fixture>` treated the fixture as a subdirectory of / and

---
*Auto-generated from Component Fabric. Card: `tests-git_fence.yaml`*
*Last verified: 2026-09-30*
