Reviewed tip `63eb125aa0b082ddabe2934981376c6e1285e0a1` against `b82294243`.

1. **RESOLVED — silent decision reversion.** For both plain `mv` and `git mv`, an ordinary commit immediately after the decision commit preserves the decision in HEAD. A competing ordinary commit inside the pre-commit hook fails on Git’s index lock. Unrelated staged work remains staged and excluded from the decision commit.

2. **NOT RESOLVED — follow-up healing has a remaining pathspec failure.** Healing succeeds for both move types when the working tree already equals HEAD. However, I reproduced failure with a plain move, an old scratch-index decision commit, and an additional follow-up write:
   ```
   error: pathspec '.tasks/active/T-9300-decide-me.md' did not match any file(s) known to git
   ```
   At `web/blueprints/inception.py:1128–1164`, `wanted` retains the obsolete active path after `git add` removes its last index entry. `commit --only` then rejects it. The original decision remains committed and the index is repaired, but the follow-up write remains uncommitted.

3. **RESOLVED — misleading timeout description.** The helper now documents four 30-second attempts plus 1.5 seconds of backoff. An injected timeout probe confirmed `[30, 30, 30, 30]` and sleeps `[0.25, 0.5, 0.75]`: approximately **121.5 seconds per helper invocation**, not four seconds. This is not an overall function bound. Held-index-lock tests return visible failure, preserve working-tree content, and succeed on follow-up after release.

The separate `git add` window is **acceptable for decision integrity**, but its stated behavior is incomplete. Injecting an ordinary commit immediately after staging preserves the complete move for both move types; Watchtower returns “nothing to commit.” However, adding a subsequent working-tree update before Watchtower continues makes **both move types fail with the obsolete-active-path error above**, rather than committing the remaining difference. I observed no decision reversion or corruption.

Required correction: rebuild the commit path list after staging, excluding paths absent from HEAD, index, and working tree. Handle concurrent disappearance with a bounded revalidation/retry, preserving genuine deletions still present in HEAD. Add regressions for healing with additional writes and competing commits followed by additional writes, for both move types; synchronize the vendored implementation.

Validation: **67 focused tests passed**; additional temporary-repository reproductions produced the results above. All three implementation/vendor pairs pass `cmp`; `git diff --check` passes. Baseline scope includes the related audit detector, its integration, tests, and VERSION; no unrelated code expansion found.

SHIP-WITH-CHANGES — decision-loss race fixed; correct stale commit pathspecs with bounded revalidation/retry, add the missing follow-up/concurrency regressions, and update the vendored copy.