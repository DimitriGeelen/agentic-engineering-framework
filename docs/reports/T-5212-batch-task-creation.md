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

## Dialogue Log

- 2026-11-17: the operator chose to open this inception ("1 yes").
