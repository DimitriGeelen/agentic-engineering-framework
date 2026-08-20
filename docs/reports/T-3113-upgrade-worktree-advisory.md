# T-3113 — `fw upgrade` names which worktrees are behind (R7 leg L4)

**Task:** T-3113 · **Design:** `docs/design/task-corpus-concurrency-model.md` §R7
**Siblings:** L1 T-3110 ✅ · L3 T-3112 ✅ · L2 T-3111 (next)

---

## The gap

Measured before starting: `grep -c worktree lib/upgrade.sh` → **0**.

The command whose entire job is propagating the framework was blind to the
replicas of the framework sitting beside it. `fw upgrade` refreshed the main
checkout and said nothing about the linked worktrees, each still running whatever
enforcement code it forked with.

This matters more than the equivalent gap in `doctor` because vendored
propagation is **pull-only**. No leg of R7 reaches a project that never upgrades.
The moment it *does* upgrade is the last moment available to say anything.

## What shipped

`_t3113_emit_worktree_advisory <target_dir>` in `lib/upgrade.sh`, called from
`do_upgrade`'s live path after the T-2094 doctor advisory. Extracted as a helper
for the same reason `_t2094_emit_doctor_advisory` was: so a test can exercise it
without driving ten upgrade steps.

Real end-to-end run against a synthetic consumer with one stale worktree:

```
  Linked worktrees (advisory):
  STALE  wt (1 commit(s) behind, absent)
         …/consumer-t3113/wt

  1 of 1 linked worktree(s) run older enforcement than this project.
  Land and remove:  fw integrate run master --push  (then fw worktree gc)
  Or refresh in place: fw upgrade <worktree-path>
```

**Two facts, both reported.** Either alone misleads:

- *commits behind the authority's HEAD* — tracked content: `bin/fw`, `lib/`, hook
  templates. A worktree 2000 commits behind runs 2000-commit-old enforcement.
- *hook delta vs the authority's `.claude/settings.json`* — a different question
  entirely. Settings drift independently of commit distance. Measured on this
  repo: `t100196-vendor-fix` is a **merged** worktree — zero commits behind — and
  is still missing `check-worktree-governance-write`.

A commit-distance check alone would have reported that worktree perfectly
healthy. Test 3 in the suite is exactly this case.

## The third copy

AC 4 said "`lib/upgrade.sh` holds zero copies of the predicate". Checking it
found `def extract_hooks` at `lib/upgrade.sh:1650` — a **third** inline copy.

T-3112 had consolidated two call sites and asserted *"`bin/fw` holds zero
copies"*. That assertion was true and it was blind: it named one file, and the
copy that mattered was in another. This is the same drift class the
consolidation exists to prevent, caught one leg later only because an AC on a
different task happened to grep a second file.

The fix follows the precedent already in that file — `lib/hook_portability.py`,
whose call sites carry the note *"one module, two call sites (L-399: a contract
shipped on one side only is how this class recurs)"*. So:

| Before | After |
|---|---|
| `bin/fw` inline copy | → `fw_hook_parity_delta` (T-3112) |
| `lib/hook-parity.sh` inline python | → `lib/hook_parity.py` |
| `lib/upgrade.sh:1650` inline copy | → `from hook_parity import extract_hooks` |

Repo-wide scan now returns exactly one definition, and a test asserts the scan
result *as a file list* rather than a count in one named file — so the next copy
cannot hide in a file nobody thought to check.

**Two parse policies, deliberately kept.** The copies were not identical:

- `strict=False` (upgrade) — unparseable file yields an **empty set**, so
  `missing` = everything, so `needs_regen` fires and the broken `settings.json`
  gets regenerated. That is T-2912's shipped behaviour and the correct response.
- `strict=True` (doctor) — unparseable file yields `None` → verdict
  `parse-error`. A health check must never print `missing 34:` for a file it
  merely failed to read; that is a diagnosis, not a measurement.

Collapsing them to one "obvious" policy would have silently stopped repairing
broken consumers. Both are pinned by tests 13 and 14.

## Verification actually run

- `tests/unit/t3113_upgrade_worktree_advisory.bats` — **14/14**
- `tests/unit/t3112_worktree_hook_parity.bats` — re-run after the refactor
- Real `bin/fw upgrade` against a synthetic consumer with a stale linked
  worktree: exit 0, step 5 correctly reported `missing 1 hook(s):
  PreToolUse:check-worktree-governance-write` through the imported predicate,
  advisory fired as shown above.

## Honest limits

The advisory is non-blocking by construction — it always returns 0. An advisory
that can fail an upgrade is one operators learn to route around.

It reports; it does not act. A named worktree stays stale until someone lands or
refreshes it. And it only speaks during `fw upgrade` — a project that never
upgrades still never hears it. That is not a fixable property of this leg; it is
the reason a **release channel** (stable vs experimental) is R7's natural
companion decision, tracked in T-3114.
