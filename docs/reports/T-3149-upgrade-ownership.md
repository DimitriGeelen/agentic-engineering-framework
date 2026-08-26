# T-3149 — `fw upgrade` silently overwrites project-authored governance

**Status:** GO (operator, 2026-08-26). Slices T-3150..T-3153 filed.
**Reporter:** 001-CashWeb (consumer). **Mechanism confirmed in framework source.**

## Problem

`lib/upgrade.sh` step [1/10] rebuilds a consumer's `CLAUDE.md` by keeping only what sits
above the literal line `## Core Principle` and replacing everything below with framework
governance:

```sh
project_header=$(sed -n '1,/^## Core Principle$/{ /^## Core Principle$/d; p; }' "$project_claude")
governance=$(sed -n '/^## Core Principle$/,$ p' "$template_file")
```

Both expressions are correctly anchored. **The defect is the contract, not the regex.**

## The durable finding (peer, adopted)

Being outside `.agentic-framework/` is *not* the test for project ownership. **Whether the
framework WRITES the file is.** Four framework-written files are known — `CLAUDE.md`,
`.claude/settings.json`, `.tasks/templates/*`, `policy/designer-pin.yaml` — and the rest are
unenumerated (IW-2, deferred to T-3153).

Second peer finding, which reordered the recommendation: the split is a **content-shaped
contract**. The safe zone depends on where an author happened to put a heading, so

> The more coherently they organise their governance, the more they lose.

That inverts the usual assumption that careful authors are safer. A **marked region** costs
the same as the positional one and would have prevented all three CLAUDE.md losses with no
assertion list at all — hence marked region is slice 1 (T-3150), assertion phase slice 2.

## Empirical confirmation — 001-CashWeb T-144 assertion run, 2026-08-26

They built the prototype, snapshotted 14 assertions to disk *before* upgrading (deliberately
not in session memory: if the session does not survive the upgrade, the evidence must still
exist), then ran `bin/fw upgrade`.

**Result: 9 of 14 assertions reverted, 6 of 7 watched files rewritten.**

### The split, measured rather than asserted

| Section | Position vs `## Core Principle` (line 116) | Outcome |
|---|---|---|
| KEY DIRECTIVE (C#/React stack) | above | survived |
| G-028 (MCP reads in a worktree) | above | survived |
| G-032 (worktree guard) | above | survived |
| `### Carrier Discipline` | below | **destroyed** |
| G-047 correction | below | **destroyed** |

### Three findings new relative to the original report

1. **An upgrade to the version you already run is not a no-op.** The log said
   `Pinned: v1.6.29 (current)` — nothing to upgrade — and the full vendored tree was
   re-copied anyway, killing nine assertions. *Every* invocation is destructive, including
   the one with nothing to do. This is the most dangerous shape, because a no-op is exactly
   the case where nobody thinks a check is needed. → new AC on **T-3151**.

2. **The upgrade does not merely lose, it regresses.** `CLAUDE.md`: 52 lines removed, 7
   added — and the 7 reset the context-budget thresholds to hard-coded absolutes, undoing
   their T-085 fix that expressed them as percentages of `CONTEXT_WINDOW`.
   **Confirmed as ours:** `lib/templates/claude-project.md:469-478` ships `120K/150K/170K`
   while the framework uses `225K/255K/285K` against a 300K window. Every consumer is handed
   a `CLAUDE.md` that contradicts its own `budget-gate.sh`. → **T-3155**.

3. **`fw doctor` has a blind spot.** In the same run that set `agents/designer/designer.sh`
   from 755 to 644, post-upgrade doctor reported `OK  All agent scripts executable`.
   **Confirmed as ours:** `bin/fw:1891` iterates a hardcoded list of seven agents;
   `designer/designer.sh` is not among them. The predicate is "these 7 are executable"; the
   word *All* is the false part. → **T-3154**.

   Git showed the file as `0 insertions, 0 deletions` — a mode change with no content diff,
   so nothing keyed on content can see this class (IW-4).

### The sharpest line in the thread (peer, verbatim in substance)

> The warnings exist but do not cover the losses that mattered — and that is worse than no
> warning, because their presence suggests coverage.

Step 1/10 *does* warn that 42 lines are missing, and *does* take a backup. But the example
lines it prints are the budget rules, not Carrier Discipline; step 5/10 names a different
hook than the one actually removed; the designer pin, the three templates and the exec bit
are not mentioned at all. A warning that misses the losses reads as coverage.

This is the same family as our port-3000 anti-pattern: documented from T-1376, **violated
371 times across 277 tasks**, because a green line that asserts nothing is indistinguishable
from one that asserts everything. Only a gate stopped it.

## Open Questions — dispositions

| ID | Disposition | Basis |
|---|---|---|
| IW-1 | answered | Operator GO: upgrade owns both files; consumers get a named seam |
| IW-2 | deferred | The framework-written-file list does not exist → T-3153 |
| IW-3 | answered | Framework-side; see below |
| IW-4 | deferred | Not reproduced here; peer evidence is an absence (no content diff) |

### IW-3, settled on correctness rather than cost

Every consumer-side registration point is a file the upgrade owns. A consumer-side check is
therefore deletable by the run it exists to catch, and fails silently exactly when needed.

> **A guard that the guarded event can delete is not a guard.**

Hence: framework-side mechanism, consumer-supplied assertions at a path the framework never
writes, default set derived from what the upgrade just rewrote. The load-bearing test on
T-3152 is the one that proves the property — deleting the consumer's `CLAUDE.md` and
`.claude/settings.json` must **not** disable the runner. If that test cannot fail, the
mechanism is consumer-side again by accident.

## Scope of the GO

| Slice | Deliverable |
|---|---|
| T-3150 | Marked `<!-- project-owned: begin/end -->` region replaces the positional split |
| T-3151 | Refuse-with-diff when a managed file is locally modified (incl. same-version runs) |
| T-3152 | Framework-side assertion phase, consumer-supplied assertions |
| T-3153 | Enumerate the framework-written file set (IW-2) |

Recorded machine-readably: `inception_decisions:` on T-3149, `unlocks_inception_decision:`
on each slice, so the GO is checkable in both directions.

**G-047 stays open** until the framework-side phase actually runs. The peer is explicit that
their list is detection — not prevention, not mitigation, and it does not run by itself. Our
slices must not close it early either.

## Not claimed

- Whether T-3051's exec-bit gate runs in the `fw upgrade` path — **not checked here**.
- The designer silent downgrade (903600 vs 966087 bytes, no error, because the 0.8.0
  artefact was still on disk so the reverted pin resolved cleanly with no sha mismatch).
  A pin that resolves cleanly to the wrong artefact is the same family; not yet homed.
- Their G-048 (two arcs both claiming `id: arc-001`, so `fw bvp arcs` silently omits one).
  Arc id uniqueness is framework-owned, so this is likely ours. Not filed separately.

## Dialogue Log

- **Peer report 1** — four project-authored things reverted by one `fw upgrade`;
  `.framework.yaml version:` unchanged throughout. Reframing offered: authorship, not
  location, is the ownership test.
- **Framework side** — mechanism located in `lib/upgrade.sh:1265-1272` and `:1632`.
  Confirmed the regexes are correctly anchored, so this is *not* the T-3148 sed-range class.
  Filed as inception with IW-1..IW-4; recommendation GO with assertion-list first.
- **Peer report 2** — settles IW-3 on correctness grounds ("a guard the guarded event can
  delete is not a guard"); adds the content-shaped-contract insight. **This reordered the
  recommendation**: marked region first, assertion phase second.
- **Operator, 2026-08-26** — GO on IW-1. Slices filed.
- **Peer report 3 (T-144 assertion run)** — prototype built and run; three new findings, two
  confirmed as framework bugs within minutes (T-3154, T-3155); split table measured.
