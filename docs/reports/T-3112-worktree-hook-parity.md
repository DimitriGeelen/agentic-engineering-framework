# T-3112 — `fw doctor` audits worktrees for enforcement drift (R7 leg L3)

**Task:** T-3112 · **Arc context:** R7, `docs/design/task-corpus-concurrency-model.md`
**Siblings:** L1 T-3110 (landed), L2 T-3111, L4 T-3113

---

## The gap this closes

`fw doctor` has audited consumer projects for hook drift since T-616. For every
one of 31 consumers it answers: *does this replica carry the hooks the authority
carries?*

It asked that question of **zero worktrees**.

A linked worktree is the same shape of replica as a vendored consumer — its own
`.claude/settings.json`, its own `bin/fw`, its own copy of the enforcement code
that is supposed to constrain it. That is the R7 observation: rules are enforced
by code, code is tracked content, so the replica supplies the code meant to
constrain the replica.

The measured state of this repo's own worktrees, from the run that shipped with
this task:

```
Worktrees
WARN  inception-gov-payload-mediation (missing 4: check-active-completed-dup,
      check-onboarding-gate, check-rail-mcp-label, check-worktree-governance-write)
WARN  rca-worktree-push-strand        (missing 4: same set)
WARN  t100196-vendor-fix              (missing 1: check-worktree-governance-write)
WARN  t100199-close                   (missing 4: same set)
      4 of 4 linked worktree(s) drifted from the authority's hook set.
```

Four of four. And the hook missing from all four is
`check-worktree-governance-write` — the one whose absence is the mechanism behind
the T-2505 / T-2506 / T-2428 duplicate-ID incidents. The framework has been
unable to see this about itself for seven weeks.

## What shipped

**`lib/hook-parity.sh`** (new) — three functions:

| Function | Answers |
|---|---|
| `fw_hook_parity_delta <authority> <replica>` | `ok N/M` \| `missing K: names` \| `absent` \| `parse-error` |
| `fw_hook_parity_authority_root [dir]` | which checkout is the authority (via `--git-common-dir`) |
| `fw_hook_parity_linked_worktrees [dir]` | the replica set; **exit 1 when unenumerable** |

**`bin/fw doctor`** — two changes:

1. The Consumer Projects loop's inline `extract_hooks` python block is replaced
   by a call to `fw_hook_parity_delta`. `bin/fw` now holds **zero** copies of the
   predicate; a bats test pins the zero.
2. A new `Worktrees` section, sibling to Consumer Projects, running the same
   predicate over the linked-worktree set.

**`tests/unit/t3112_worktree_hook_parity.bats`** — 14 tests over a real
`git worktree add` fixture.

## Three decisions worth stating

**The predicate moved rather than being copied.** Adding the worktree surface by
duplicating the inline block would have produced two comparisons that drift
independently — which is the same class of bug the worktree audit is being added
to catch. This is the T-3101 one-predicate-many-surfaces shape: one definition,
two subjects.

**`absent` is not `missing <all>`.** A worktree created before the hook set
existed and a worktree whose settings were emptied are different stories with
different remedies. Collapsing them loses the one that matters. The same
reasoning gives `fw_hook_parity_linked_worktrees` an exit-1 *unenumerable* state
distinct from an empty set — T-3105's rule is that a check may only PASS over the
set it actually evaluated, and "could not check" is a WARN, never a PASS.

**Extra hooks in a replica are not drift.** The delta is one-directional:
authority-minus-replica. A consumer or worktree may legitimately add
project-local hooks, and flagging those makes the check noisy enough to be
ignored — which is how a check stops being read. Under-enforcement is the failure
mode with teeth.

## Honest limits

This leg **reports** the drift; it does not close it. A worktree flagged here
still runs its stale `bin/fw` until someone acts. L2 (T-3111) redirects the
binary to the authority; L4 (T-3113) names stale worktrees at upgrade time.

The check compares hook *names* per event, not hook *implementations*. A worktree
whose `settings.json` lists `check-active-task` but whose `bin/fw` cannot execute
it reports `ok`. That is the same limitation the consumer check has always had,
and closing it is L2's job — once the binary re-execs from the authority, the
name is the implementation.

The section is not gated on `FRAMEWORK_ROOT = PROJECT_ROOT` (unlike the consumer
loop), so it runs in consumer projects too — consumers use worktrees as well.
