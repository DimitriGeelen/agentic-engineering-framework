# T-3101 — worktree visibility (`worktree-unlanded`)

Slice 2 of T-2822 F5. Slice 1 (T-3098) stopped NEW governance strands forming in
linked worktrees. This slice surfaces the ones that already exist.

**Origin.** Two linked worktrees in this repo held 43 unlanded commits (6 + 37)
dormant since 2026-07-01 for five weeks. No surface reported a sibling
worktree's unlanded commit count or age. `lib/branch-hygiene.sh` had a
linked-worktree loop, but it asked only one question — *"is this worktree parked
on something already landed?"* (`worktree-merged`, the deletable case) — and said
nothing about the opposite, far more expensive state.

## The new finding class

```
worktree-unlanded <path> branch=<branch> ahead=<n> days=<d>
```

Emitted only when `ahead > 0`. Same emission slot as before (local branches →
worktrees → remote refs), so the `fw_branch_hygiene_head` one-per-class sampling
contract is unchanged.

## Precedence rule: merged wins

`worktree-merged` is tested first; `worktree-unlanded` lives in the `else` arm.

The two classes are **mutually exclusive by construction**, not by tie-break. A
branch that is an ancestor of TARGET has, by definition, zero commits in
`TARGET..branch`, so the `ahead > 0` guard can never fire for a merged branch.
Verified empirically on a fixture where the worktree branch is identical to
master: `merge-base --is-ancestor` → TRUE, `rev-list --count master..branch` → 0,
and only `worktree-merged` is emitted.

The if/else ordering plus the `ahead > 0` guard is therefore belt-and-braces: if
a future edit loosens the ancestor test (for example to content-equality, the way
`fw worktree gc` compares), the ordering still yields a single verdict per
worktree. Emitting both for one path would print opposite instructions —
*"delete this"* and *"you will lose 37 commits"* — for the same directory.

## Base resolution rule

Unchanged and reused, not reinvented: TARGET is `origin/master` when it verifies,
else `master`, else the whole predicate returns silently (no master lineage =
nothing to judge against). This is the same resolution the `merged-undeleted`,
`behind-threshold` and `diverged-fork` code already uses, resolved once at the
top of `fw_branch_hygiene`.

`days` reuses `_bh_days_since_commit` (T-3094) on `refs/heads/<branch>` — the
branch's own last commit, not the target's. **No recency gate** is applied to
this class: unlanded work is a strand on day 0 as much as on day 50. The count is
the risk; the age is context. (Contrast `behind-threshold` / `diverged-fork`,
where recency is what separates a strand from work in progress.)

An empty `rev-list` result is treated as a sentinel and skipped, not coerced to a
number — a failed count must stay silent rather than manufacture a strand out of
an error. Same reasoning as the T-3092 remote loop.

## Tests

`tests/unit/t3101_worktree_unlanded.bats` — 8 tests, all green. Real `git init`
fixtures and real `git worktree add`; no mocking.

## Mutation results

| # | Mutation | Killed by |
|---|----------|-----------|
| M1 | `[ "$_wt_ahead" -gt 0 ]` → `-ge 0` | **nothing — equivalent mutant, see below** |
| M2 | swap rev-list operands: `$target..refs/heads/$wtb` → `refs/heads/$wtb..$target` | tests 1, 5, 7, 8 |
| M3 | drop the `days=` field from the emitted line | tests 1, 5, 7, 8 |
| M4 | flip precedence: negate the `merge-base --is-ancestor` merged test | tests 1, **3**, 5, 7, 8 |

**M1 is a provably equivalent mutant, not a test gap.** `ahead == 0` ⟺ every
commit of the branch is reachable from TARGET ⟺ the branch is an ancestor of
TARGET ⟺ the merged arm claimed it and the guard was never reached. The `else`
arm is therefore only reachable with `ahead >= 1`, so `-gt 0` and `-ge 0` are
behaviourally identical. Probed directly (fixture above) rather than asserted.
M4 was run as the third *effective* mutation in its place, and is the more
on-point one anyway: it targets the precedence rule this slice had to choose, and
test 3 — the dedicated precedence test — is the one that dies uniquely to it.

## Live output on this repo (verbatim)

```
$ bash -c 'source lib/branch-hygiene.sh; fw_branch_hygiene "$PWD"' | grep worktree
behind-threshold worktree-inception-gov-payload-mediation behind=1513 days=49 (threshold 50)
behind-threshold worktree-rca-worktree-push-strand behind=1728 days=50 (threshold 50)
worktree-unlanded /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation branch=worktree-inception-gov-payload-mediation ahead=6 days=49
worktree-unlanded /opt/999-Agentic-Engineering-Framework/.claude/worktrees/rca-worktree-push-strand branch=worktree-rca-worktree-push-strand ahead=37 days=50
worktree-merged /opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100196-vendor-fix branch=t100196-vendor-fix
worktree-merged /opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100199-close branch=t100199-close
remote-unlanded origin/worktree-inception-gov-payload-mediation ahead=3
```

**Both known strands surface, with the exact numbers T-2822 F5 named: 6 + 37 =
43 unlanded commits, dormant 49 and 50 days.** The two other worktrees
(`t100196-vendor-fix`, `t100199-close`) correctly take the merged arm and are not
double-reported.

Two things the live run additionally shows:

1. `remote-unlanded origin/worktree-inception-gov-payload-mediation ahead=3` next
   to `worktree-unlanded … ahead=6` — the remote carries 3 of the 6, so 3 commits
   exist **only** in that worktree's local branch. The local/remote split T-3092
   built is what makes that visible.
2. This repo currently emits 21 findings against a display cap of 12. Piping the
   live output through `fw_branch_hygiene_head 12` keeps a `worktree-unlanded`
   representative — the class is not truncated away in `fw doctor` or the audit
   block.

## Call-site verification (no edits made)

Both consumers source the single predicate and iterate its lines generically, so
the new class surfaces with no change to either:

- `bin/fw:3221` — `fw_branch_hygiene "$PROJECT_ROOT"`, counts lines, prints each
  through `fw_branch_hygiene_head 12`.
- `agents/audit/audit.sh:2099` — same call, same head helper, `warn()` with the
  count.

Neither file was edited. The only class-specific branch in either is the
`diverged-fork` extra-mitigation `grep`, which is additive.
