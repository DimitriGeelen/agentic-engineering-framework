# T-5212: Batch task creation

**Status:** inception, exploring. Trigger: 1409 (sidecar 131579aa, 0e42d876, 8ba662ce, f3e548ce,
2026-11-17).

## The need

1409 gives every municipality the same governance: one arc and 13 step tasks, generated from one
class file (their `ontologie/klasse/kommunescan.yaml`, template arc `tpl-arc-001`). Their tool calls
`agents/task-create/create-task.sh` once per task. Measured: 14 calls per unit, about 3.7 s each,
52 s per unit, 43.3 minutes for a wave of 50. The operator (theirs) wants the whole pattern created
at once, with ids reserved, "foolproof" and with "reconciliation".

## What exists (AEF, 2026-11-17)

- `generate_id` (agents/task-create/create-task.sh:266) union-scans `.tasks/{active,completed}` of
  every git worktree (`fw_task_view_dirs`, T-100202, the guard against minting a duplicate from a
  lagging view), then takes the max with each view's `.id-highwater` (T-4189, never reissue a
  deleted top id). Ids above a gap > `FW_ID_QUARANTINE_GAP` (1000) are a quarantined band.
- One allocation lock anchored at the main worktree: parallel creates are safe, but serialised.
- With 24 worktrees (50,763 files) the scan costs 2.0-2.5 s per call; through one view, 0.27 s.
- No batch verb, no reservation, and no ID side worker exist. 1409's operator remembers deciding
  on one; no record found here (asked 1409 for a task id or date).

## Shape agreed in conversation (to be decided)

1. **Reserve:** one call, one scan, one lock, returning a contiguous block of task ids plus an arc id.
   A **reservation ledger** records range, purpose, time and state (reserved -> created/complete).
2. **Reconcile:** a reserved id without a file is reported as an incomplete arc and never reissued.
   An id above the counter, or a duplicate, is an error. The union scan stays as the check and may
   only raise the counter.
3. **Quarantine:** the gap rule reads the ledger, so a large, partly unused block never pushes later
   ids into quarantine.
4. **Create:** one verb creates an arc and its tasks from a template plus parameters, with files
   identical to create-task's. Per-call side effects run once per batch where safe.
5. **Scan cost (separate, smaller):** a per-view cached scan, invalidated on change.

A framework verb is preferred over a sanctioned "the project writes task files itself" contract:
one writer of task files keeps the format, hooks and audit in one place.

## 1409's prototype

1409 is measuring a prototype in a copy (no change to their vendored framework or their tasks)
against six checks: 20 concurrent processes, a crash mid-block, a stale view, a deleted top id, the
old outlier band, and equality with the single path. They will send patch, tests and numbers as a
proposal, to be reviewed rather than merged as is.

### Prototype results (1409 sidecar a8eb045c, 2026-11-17 21:22Z)

The proposal lives in 1409's repo, which this session cannot read; the text has been requested over sidecar.
- **Shape:**
  - the authoritative counter is `<main>/.tasks/.id-highwater`, under the existing lock, and only ever moves up;
  - `fw_id_allocate N` hands out blocks of at most 100;
  - a ledger, `.id-ledger.jsonl`, records reserve, created and heal;
  - `fw task create-batch` uses one writer (`render_task.py`) for both the single and the batch path;
  - `fw task id-abgleich [--heal]` reconciles.

  The union scan stays as the check: once per reservation, when the counter is missing, and in reconciliation.
- **Checks, all green on a full-size replica (about 50k task files, 24 views):**
  - Single and batch paths write identical files: 42/42.
  - 2,020 concurrent allocations from 20 processes gave 0 duplicates and 0 overlaps.
  - `kill -9` after a reservation, and after the 5th file, reused nothing, and reconciliation reported the arc as incomplete.
  - The other cases also passed: a stale view, a counter that is missing, too low or too high, a deleted top file, the T-99971/T-100202 band, and 12 aborted 100-blocks against the quarantine gap.
- **Measured at load 67-88:**
  - Per id: 4.32 s before; 0.37 s with the check and 0.15 s without it, about 0.06 s per id in a block. 1409's own target of < 0.05 s was not met.
  - Per unit (arc + 13 tasks): 95.2 s became 2.6 s.
  - A wave of 50 units takes 3.3 min.
- **Measured limit:** an OLD `generate_id` running beside the new allocator would, after more than 1,000 aborted reserved ids, hand out an id from a reserved block. That makes "one allocator per repository" a hard rule.
- **Differences from the agreed shape:** there is no arc-id reservation, because 1409's arc ids are fixed names; the arc is still created by its own `fw arc create`.
- **Side findings, filed:**
  - T-5213: lib/objectives-seed.sh has a second allocator with no lock, no views and no high-water. Confirmed.
  - T-5214: an exported FRAMEWORK_ROOT makes another copy's fw run the exporting copy's code. Not yet reproduced.
- **Meanwhile on 1409's side:** their operator archived 23 old worktrees, which brought the scan from 2.91 s to 0.51 s per call. They are no longer blocked.

## Dialogue Log

- 2026-11-17: the operator chose to open this inception ("1 yes").
