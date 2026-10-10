# T-4032 fix review round 2 — codex (2026-10-10)

Read-only review of 661c026f3^..a683cc908. Final answer only.

**Verdict: DO-NOT-SHIP**, including as an emergency hotfix. The combined change improves shutdown behavior but still permits terminating an active turn and restarting from an incomplete handover.

Line references below are for `a683cc908`.

1. **FIXED — Another session’s project-wide ready flag.** `bin/claude-fw:453–460,510` now reads per-session records and matches the supervised child PID; the project-wide flag no longer authorizes foreground termination. TermLink uses a session-name match at `:1011`.

2. **FIXED — Waiting expires the restart request.** `bin/claude-fw:546,1032` refreshes the signal immediately before termination, satisfying the parent’s freshness check at `:1096`. This addresses the reported long-wrap-up and ceiling scenarios under normal filesystem operation.

3. **PARTIAL — Stop is not a durable idle boundary.** Settling and post-handover rechecks help (`bin/claude-fw:519,531–537`), but `:468–471` treats transcript writes within five seconds after Stop as idle and treats an inaccessible transcript as unchanged. Concrete scenario: Stop is rejected, continuation writes at +3 seconds, then waits on a long tool or model response; the ten-second settle expires and kills live work. An in-memory execution of the actual classifier returned `idle` for that scenario. A new prompt can also arrive between the final readiness check and SIGTERM (`:531–548`).

4. **FIXED — TermLink’s immediate termination bypass.** `bin/claude-fw:1009–1034` now applies readiness/ceiling waiting, handover, recheck, and signal refresh before injecting `/exit`. It inherits the shared protocol’s remaining defects; this fixes the specific bypass, not the overall safety guarantee.

5. **PARTIAL — Ceiling and freshness weaknesses.** Fractional signal timestamps and reading one JSON record improve ordering (`bin/claude-fw:455,500`). However, elapsed time remains wall-clock based (`:490,520`), observed signal deletion resets the deadline (`:489`), and the ceiling still kills busy sessions (`:538–548`). The user-facing promise still omits that exception (`agents/context/budget-gate.sh:416–417,624–625`).

6. **PARTIAL — Early handover omits wrap-up.** The idle path now rejects handovers older than two minutes before Stop (`bin/claude-fw:528`), but accepts one written before the final decisions. A first-block handover followed by a 90-second wrap-up still qualifies. The ceiling path retains the original first-signal threshold (`:541`). Neither establishes a final capture.

**New defects introduced by the fix:**

- **Pre-signal handovers can now qualify.** `bin/claude-fw:528,1024` passes `idle_epoch - 120` to the unchanged comparison at `:367`. Example: LATEST predates the critical signal by 60 seconds; Stop follows the signal by 20 seconds. That unrelated handover now passes, whereas the previous first-signal threshold rejected it.
- **The rejected-Stop regression test is vacuous.** `tests/unit/t3918_terminator_handover.bats:142–145` creates the signal, then writes a ready record dated ten seconds earlier. The record fails `up >= since` regardless of transcript movement; deleting the movement check would still pass this test.

Read-only review; no files changed. The classifier probe used mocks in memory. Bats was not run because it writes files.
