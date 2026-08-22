# T-3111 — `fw` re-execs the authority's binary from a linked worktree (R7 leg L2)

**Task:** T-3111 · **Design:** `docs/design/task-corpus-concurrency-model.md` §R7
**Siblings:** L1 T-3110 ✅ · L3 T-3112 ✅ · L4 T-3113 ✅ — R7 closes with this leg.

---

## The gap

R1–R6 assume the rules are enforced. They are enforced by code. That code is
tracked content, so it forks with the branch — and the replica then supplies the
code that is supposed to constrain the replica.

Measured in this repo before starting, in `.claude/worktrees/t100196-vendor-fix`:

```
$ FW_NO_REEXEC=1 .claude/worktrees/t100196-vendor-fix/bin/fw --version
fw v1.6.67
Commit:    d95b5f150 (t100196-vendor-fix)
```

`v1.6.67` against master's `v1.6.152`. A session opened there allocates task IDs
the pre-T-100202 way — which is how T-2505, T-2506 and T-2428 were each minted
twice on 2026-07-01 and stayed invisible for seven weeks.

## What shipped

`_fw_reexec_authority` in `bin/fw`, called immediately after `PROJECT_ROOT`
resolves and before `FRAMEWORK_ROOT` is resolved at all. When the checkout in
play is a linked worktree it `exec`s the main checkout's `bin/fw` with the same
argv.

**Two subjects, one hazard.** A replica reaches the running process by two
independent routes, and checking only one misses real cases:

| Subject | How the replica gets in | Missed if unchecked |
|---|---|---|
| `PROJECT_ROOT` is a worktree | `resolve_framework()` prefers the project's own vendored tree (T-498), so even the *authority's* binary loads the replica's `lib/` and `agents/` | global shim run with cwd inside a worktree |
| `FW_BIN_DIR` is in a worktree | the replica's binary was invoked directly by path | `.claude/worktrees/x/bin/fw …` run from a session rooted at the main checkout |

**What moves and what does not.**

- `FRAMEWORK_ROOT` **moves**, in the same step as the `exec`. It has to: `fw`
  honours an inherited `FRAMEWORK_ROOT` over its own location (the T-2099
  fork-bomb fix). Exec the authority's binary while a replica-scoped
  `FRAMEWORK_ROOT` is still exported and the authority politely loads the
  replica's libraries — output byte-identical to having changed nothing. T-2845
  measured that exact trap. Test 9 pins it.
- `PROJECT_ROOT` **stays**. The worktree is still the project the operator is
  standing in; moving it would silently redirect `fw git commit` to master's
  tree. Allocation is fixed regardless, because the authority's allocator
  union-scans every view (T-100202/T-3104) including this one — the fix rides in
  with the *code*, not with the working directory.

**Loop guard.** `FW_REEXEC_DEPTH=1` is exported before the `exec` and checked
first, before any git call, so the authority never bounces back and a redirected
process pays nothing for the check.

**Escape hatch.** `FW_NO_REEXEC=1`, checked *after* detection rather than first —
a bypass is only a bypass once something was actually going to happen. Placed
earlier it would log every main-checkout invocation as a skipped redirect, which
is how a Tier-2 log stops being read. Entries name the replica and the authority.

## What checking the ACs found

AC 1 says *use `lib/paths.sh:fw_is_linked_worktree`, no new detector*. `bin/fw`
cannot source `lib/paths.sh` — it resolves and exports `FRAMEWORK_ROOT`,
`PROJECT_ROOT` and `TASKS_DIR` as a side effect of being sourced, which is
precisely what has not happened yet at the redirect. `bin/fw`'s doctor had
already resolved that tension the only way available to it: an inline copy
(T-2435). Adding a second copy — in the code that decides which binary runs —
is T-3113's disease with the largest available blast radius.

So the definition moved to `lib/worktree-identity.sh`: side-effect-free by
contract, sourced by `lib/paths.sh` (every existing caller unchanged), by the
redirect, and by doctor in place of its inline copy. Net one copy fewer.

**And the predicate was wrong.** It compared `--git-dir` to `--git-common-dir`
textually. git does not answer the two questions in one form — from a
*subdirectory* of the main checkout it returns the first absolute and the second
relative:

```
$ git -C <root>/bin rev-parse --git-dir           → /…/root/.git
$ git -C <root>/bin rev-parse --git-common-dir    → ../.git
```

Prefixing the relative form with the query directory yields
`<root>/bin/../.git`, which is textually different from `<root>/.git` and the
same directory. The predicate reported **every subdirectory of the main checkout
as a linked worktree**. It had been correct in practice since T-2435 only because
every caller happened to pass a repo root; L2 is the first to pass `bin/`. Both
sides are now canonicalised through `readlink -f`. Test 16 pins all four cases.

Three legs in a row where the copy count, not the logic, was the defect.

## The honest limit

Future-facing only, by construction: the redirect must already be in the
replica's own `bin/fw` to fire, so it does nothing for the worktrees that
produced the incidents. Test 13 asserts that limit rather than leaving it as
prose. This is why L1 — the shared `pre-commit` corpus guard, which lives in
`.git/hooks` and therefore does not fork — is the keystone, and why L3 and L4
report the gap that L2 can only close going forward.

## Verification actually run

- `tests/unit/t3111_worktree_reexec.bats` — **16/16**, against a real
  `git worktree add` fixture whose two checkouts disagree about their `VERSION`
  and whose authority binary can be swapped for an argv/env reporter.
- `tests/unit/t3112_worktree_hook_parity.bats` + `t3113_upgrade_worktree_advisory.bats`
  re-run after the predicate move.
- `tests/lint/*.bats` — structural invariants, unchanged.
- `bin/fw doctor --quick` from the main checkout: unchanged output.
