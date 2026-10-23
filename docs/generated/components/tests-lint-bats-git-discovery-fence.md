# bats-git-discovery-fence

> T-3610 — a bats file that installs framework hooks or runs `fw init` must fence git discovery, so the write cannot land in a repo ABOVE its temp dir.

**Type:** script | **Subsystem:** tests | **Location:** `tests/lint/bats-git-discovery-fence.bats`

## What It Does

T-3610 — a bats file that installs framework hooks or runs `fw init` must fence
git discovery, so the write cannot land in a repo ABOVE its temp dir.
ORIGIN. On 2026-09-30 this host's stray /.git (T-2787) was written twice:
22:30:22  /.git/config gained [user] email=t@t name=T — a consumer project's
hook test ran `git init; git config user.email t@t` with its output
piped to `head -20`; git init died of SIGPIPE before creating .git,
and the silent `git config` walked up to /.git.
22:30:59  /.git/hooks/{commit-msg,pre-commit,post-commit,pre-merge-commit,
pre-push} rewritten — tests/unit/init_head_bootstrap.bats, run on
its own, called `fw init` on a /tmp fixture; with /.git above it

---
*Auto-generated from Component Fabric. Card: `tests-lint-bats-git-discovery-fence.yaml`*
*Last verified: 2026-09-30*
