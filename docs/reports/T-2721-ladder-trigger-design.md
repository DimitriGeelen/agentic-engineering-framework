# T-2721 — Escalation-ladder trigger from witnessed failures: design and the operator choice

Arc: `ladder-trigger-producer` (arc-018, status draft). Origin: T-2715 GO item 5 (IW-12).

## 1. Does the gap still exist at HEAD (2026-10-21)?

Yes. Re-measured, not copied from T-2715:

- **No producer of `status: issues`.** `grep` over `lib/ agents/ bin/ web/` finds readers only
  (`agents/audit/audit.sh`, `agents/healing/lib/diagnose.sh:98`, `web/blueprints/core.py`,
  `agents/audit/active-task-scan.py`) and the reactor `agents/task-create/update-task.sh:2679`
  (auto-launches `healing diagnose` on a transition to `issues|blocked`). Nothing writes it.
  The only `issues` transitions in the corpus are a handful of hand-typed ones (T-041, T-1828,
  T-3451, T-3459).
- **`patterns.yaml` stopped growing.** 11 failure patterns (FP-001..FP-011), all hand-recorded;
  the file's last change was 2026-04-08 (T-1061). Nothing the framework witnessed since then
  has been added to it.
- **P-011 failures are witnessed and discarded.** `update-task.sh:1751` prints
  `ERROR: Cannot complete — N/M verification(s) failed` and exits 1. No record is written.
- **Tier-0 blocks are not recorded at all.** `agents/context/check-tier0.sh:667,776` log
  *approvals* to `.context/bypass-log.yaml`; a block writes nothing.
- **The gate-bypass log is mostly not failure.** `.context/working/.gate-bypass-log.yaml`:
  1780 entries; `FW_SWITCH_FOCUS=1` 1037, `--skip-sovereignty` 219 (mostly Watchtower inception
  GO), `--switch-focus` 193, `--skip-render-review` 48. Failure-shaped flags are a small tail:
  `--skip-verification` 12, `--skip-acceptance-criteria` 11, `--skip-rca` 7.
- **Correction to T-2715:** `diagnose.sh:98` does not refuse a task that is not in `issues`; it
  prints a note and continues. Healing can run on a witnessed failure without a status flip.

## 2. The decision the operator has to make

Building the producer is mechanical once three questions are answered. Each changes governance
behaviour, so they are not the agent's call.

### Q1 — What does a witnessed failure write?

| Option | Effect | Cost |
|---|---|---|
| **A. Flip `status: issues`** | Reuses the existing reactor: healing auto-runs, Watchtower already renders `issues`. | The close gate mutates the task it refused. Collides with T-1068 status/horizon invariants and with every agent loop that expects `started-work`; an agent fixing a typo in a Verification line goes `issues` and must flip back. Re-creates the incentive problem T-2715 named, from the other side (noise instead of silence). |
| **B. Append to a witnessed-failure ledger, status untouched** | New append-only `.context/working/witnessed-failures.jsonl` (`ts, task, source, detail, fingerprint`). Healing `diagnose` is invoked on the entry (it already runs without `issues`). Watchtower shows the ledger per task and as a list. | One new file + one Watchtower surface. The `status: issues` reactor stays unused — it becomes the manual channel it already is. |
| **C. Ledger always, flip `issues` on recurrence** | B, plus the status flip when the same fingerprint recurs N times on one task (ladder rung A "don't repeat the same failure"). | Most faithful to the ladder's counting model; needs a fingerprint definition and an N. Conflicts with G-019's single-incident escalation, which is the mechanism that is actually alive. |

### Q2 — Which witnessed sources count?

1. **P-011 verification failure at close** — clean: a real failure, a known moment, the failing
   command in hand. Recommended.
2. **Failure-shaped gate bypasses only** (`--skip-verification`, `--skip-acceptance-criteria`,
   `--skip-rca`, `--skip-register-requirements`) — not focus switches, not Watchtower sovereignty
   GOs. Recommended; feeding the whole bypass log would bury the signal under 1037 focus switches.
3. **Tier-0 blocks** — needs a new producer in `check-tier0.sh`, and a block is usually the gate
   working, not the task failing. Recommend deferring to a separate slice, recorded but not
   escalated.

### Q3 — Does the arc keep the counted ladder or concede to G-019?

T-2715 found G-019 (escalate on blindness-duration or a single incident) displaced the counted
ladder. Option B/C decide this implicitly: B records and diagnoses every instance (G-019-compatible);
C keeps counting.

## 3. Recommendation

**GO on B with sources 1 + 2; Tier-0 blocks as a later, record-only slice.**

Rationale: B makes the headline mechanic true ("a verification fails … the operator sees an
entry appear in Watchtower without any agent having remembered to self-report") with the smallest
governance change. It does not mutate a task from inside the gate that refused it, so it cannot
create a new class of stuck or flapping tasks. C can be layered on later from the same ledger if
recurrence data shows it is worth it — the ledger is the precondition for any counting anyway.

## 4. Build slices if B is chosen

1. `lib/witnessed_failures.py` — append/read with fingerprint; P-011 producer at
   `update-task.sh:1751`; bats + pytest.
2. Bypass producer: append on the four failure-shaped flags where the bypass log is written.
3. Healing hook: `diagnose` reads the ledger entry; `fw healing resolve` writes the FP entry —
   the first FP produced from a witnessed failure rather than by hand.
4. Watchtower: ledger panel on `/tasks/<id>` and a list page (render surface → `[REVIEW]` AC).
5. (Later) Tier-0 block recorder, record-only.
6. Arc close: demo = a real P-011 failure producing a Watchtower entry.
