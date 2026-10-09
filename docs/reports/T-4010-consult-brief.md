# T-4010 — consult brief: reviewer seats in consumers with an untracked vendored framework

## The problem

`fw reviewer judge` dispatches independent review "seats". Whether a seat may register is decided by
`lib/verdict_ledger.py:launchable_kinds()`, which reads `DISPATCH_WORKER_KINDS` from
`agents/termlink/termlink.sh` **as committed in git** (`_committed_blob`), never from the working tree.
The same holds for the backend registry `policy/review-backends.yaml`.

Why "as committed" (T-3580 round 7): every agent runs as the same OS user with write access to the
repo. If the working tree counted, an agent could edit `termlink.sh` (or the registry) to add a
worker kind it controls and get it counted as an independent reviewer. Reading the committed blob
means such an edit only counts once it is committed — visible in history, attributable, auditable.

`_committed_blob` looks in this order:
1. the project's own `agents/termlink/termlink.sh` at the reviewed revision;
2. the vendored copy `<project>/.agentic-framework/agents/termlink/termlink.sh` at that revision;
3. the framework repo's own git HEAD — **only when the framework lives outside the project root**.

In a consumer project (framework vendored under `.agentic-framework/`) whose git does NOT track
`.agentic-framework/`, (1) and (2) find nothing, (3) is skipped → no launchable kinds → no seat
registers → no review can run. Reported by consumer dimitri-mint-dev (their G-010). As of v1.8.8 the
judge at least exits 3 and names the cause instead of exiting 0.

## Options under consideration

**A. Pin the hash in the consumer's committed `.framework.yaml`.** `fw upgrade` writes the sha256 of
the vendored `termlink.sh` (and any other "as committed" file) into `.framework.yaml`, which consumers
commit. The judge accepts the vendored working copy only when its hash equals that committed pin.
An uncommitted edit to `termlink.sh` no longer matches → refused. Cost: consumers must commit
`.framework.yaml` after each upgrade; one more thing `fw upgrade` writes.

**B. Require consumers to commit `.agentic-framework/`.** No code change beyond the clear error. Strict
and simple, but each consumer's operator must decide to track the vendored tree (repo size, noisy
diffs on every upgrade); dimitri-mint-dev has not.

**C. Trust the vendored working copy when it is not tracked.** Works immediately everywhere, but
drops the "as committed" property in consumers: an uncommitted edit could add a launchable kind.

## Questions for you

1. Which option would you choose, and why? Is there a better one we have not listed?
2. For A: does the pin actually preserve the property, given the same user can also edit
   `.framework.yaml`? (It must be committed to count — is that equivalent to B's guarantee?)
3. Any failure mode we are missing (upgrade without committing, partial upgrades, symlinked
   vendored trees, worktrees)?

Please answer in under 300 words. You are not asked to change anything.
