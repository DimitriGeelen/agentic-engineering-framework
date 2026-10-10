# T-4032 fix review round 3 — codex (2026-10-10)

Read-only review of 661c026f3^..15ac86646. Final answer only.

**Verdict: SHIP-WITH-CHANGES.** The Stop classifier now handles the measured bookkeeping correctly. Fix the natural-exit restart regression below before shipping; the remaining shutdown-safety gaps do not justify retaining v1.8.8’s immediate cutoff.

Reviewed `661c026f3^..15ac86646`. References are to `15ac86646`.

Round-2 findings:

1. **FIXED — Cross-session readiness.** `bin/claude-fw:462` matches the supervised PID or TermLink session instead of the project-wide flag.

2. **PARTIAL — Restart-request expiry.** Refresh before forced termination remains correct (`bin/claude-fw:569,1056`). However, natural exit bypasses that refresh; see regression below.

3. **PARTIAL — Durable idle boundary.** `bin/claude-fw:474–489` now examines transcript content, rejects inaccessible transcripts, recognizes rejected Stop summaries, and detects subsequent user/assistant entries. Attachment, last-prompt and cost-state writes at +0.2–5.3 seconds no longer invalidate genuine idle. The final check and termination remain non-atomic (`:554–571`).

4. **FIXED — TermLink immediate-termination bypass.** `bin/claude-fw:1034–1058` applies classification, settling, handover, recheck and signal refresh.

5. **PARTIAL — Ceiling/freshness weaknesses.** Monotonic timing is implemented (`bin/claude-fw:494,541`); ceiling exceptions are disclosed (`agents/context/budget-gate.sh:418,627`). Observed signal deletion still resets the deadline (`bin/claude-fw:510,1065`), and the ceiling still permits active-turn termination.

6. **PARTIAL — Early handover.** `bin/claude-fw:549,1047` tightens acceptance to the later of first signal and Stop minus 30 seconds. A handover followed by 20 seconds of final decisions still qualifies. The ceiling retains the first-signal threshold (`:564,1054`).

7. **FIXED — Pre-signal handover regression.** The threshold now floors at first-signal time (`bin/claude-fw:549,1047`), restoring the previous protection, subject to its existing integer-second precision.

8. **FIXED — Vacuous rejected-Stop test.** `tests/unit/t3918_terminator_handover.bats:155–158` creates readiness after the signal, so transcript continuation now determines survival.

**(a) NEW finding: worse than v1.8.8**

- **High — Natural completion can lose an accepted restart.** Scenario: a headless session receives a critical signal, wraps up for six minutes without another signal write, then exits normally. The parent immediately cancels the watcher (`bin/claude-fw:1096–1102`), before its refresh at `:569`. The parent rejects the stale signal at `:1120,1292–1299` and exits instead of restarting. TermLink’s natural-exit marker also bypasses refresh (`:1079–1081`). v1.8.8 would have terminated and restarted while the signal was fresh. Preserve accepted restart intent through the parent’s natural-exit path; add integration coverage.

**(b) Residual gaps: improved over v1.8.8’s immediate cutoff**

- A prompt arriving between the final readiness check and SIGTERM can still be interrupted.
- A qualifying handover can omit the last 30 seconds; a ceiling handover can omit more.
- Missing records, rejected Stops, or long-running work can reach the ceiling. These now receive wrap-up time instead of termination on first signal sight.

Read-only validation: all three shell files passed syntax checks. In-memory execution of the actual classifier returned idle with bookkeeping, busy with continuation, and busy with a rejected Stop. Bats was not run because it writes files; no files or handover were created.
