# T-4032 fix review — codex (2026-10-10)

Read-only review of commit 661c026f3. Prompt: .context/working/t4032-review-prompt.md. Final answer only.

**VERDICT: DO-NOT-SHIP.** The delay improves the original behavior, but still permits mid-turn termination and introduces a kill-without-restart path.

1. **High — Another session can authorize killing this one.** `bin/claude-fw:445,465` reads the project-wide ready flag without checking session or Claude PID. Session A reaches critical; a TermLink worker or session B finishes afterward and writes `ready: true`; A is killed while still wrapping up. `lib/sidecar/hooks.py:90` explicitly identifies this file as “display summary only.” Use the existing session-specific record, validated against the supervised child.

2. **High — Waiting can expire the restart request.** `bin/claude-fw:459,469` retains an accepted signal beyond 300 seconds, but the parent still requires freshness at `:997` and exits on stale signals at `:1169`. Example: one block, no further blocked calls, a ten-minute wrap-up, then Stop. The watcher kills Claude; the wrapper deletes the stale request and exits. The 900-second fallback has the same failure. T-3989’s handover may refresh the signal once, but does not keep it fresh indefinitely. Carry the accepted request through to the restart decision.

3. **High — Stop does not establish a durable idle boundary.** `bin/claude-fw:465,481,486`. The configured `stop-driver.sh:251` can return `decision: block`, continuing execution, while the sibling sidecar hook unconditionally writes ready. That continuation need not involve UserPromptSubmit clearing the flag. Separately, a user can submit another prompt during the potentially 180-second handover; readiness is never rechecked before SIGTERM. Coordinate Stop continuation with shutdown and prevent new turns once shutdown is accepted. Ordinary tool completion is not itself evidence of Stop; the concrete issue is a rejected Stop. No equivalent subagent-Stop wiring was found in the reviewed settings.

4. **High — TermLink mode retains the immediate termination path.** `bin/claude-fw:936` still injects `/exit` upon the first fresh signal, waits two seconds, and proceeds without the new readiness check or handover prerequisite. This is pre-existing, but leaves the stated claude-fw guarantee incomplete. Apply the same shutdown protocol to both modes.

5. **Medium — The ceiling and freshness checks are weaker than advertised.** `bin/claude-fw:450,466,469`; `agents/context/budget-gate.sh:416,624`.
   - Missing consumer hooks mean waiting until the ceiling, then potentially killing live work; the block message omits that exception.
   - Integer-second mtimes accept an older ready write from the same second. Separate `grep` and `stat` can also observe different atomic replacements.
   - A wall-clock jump changes the effective timeout; use monotonic elapsed time.
   - Signal rewrites preserve `seen`, correctly. Observed deletion resets it; repeated deletion/recreation can postpone termination indefinitely. Wrapper disappearance intentionally ends watching.
   
   Thus 900 seconds is a fallback policy, not a safe-turn guarantee or strict total deadline: handover and kill grace follow it.

6. **Medium — Early auto-handover can omit the wrap-up.** `bin/claude-fw:481`, `_ensure_handover_before_kill` at `:367`. T-3989 can generate LATEST immediately after the first block. The agent then spends minutes recording decisions; the terminator accepts that early handover because it postdates `first_mt`. Require a final capture covering the completed wrap-up.

**Tests:** `tests/unit/t3918_terminator_handover.bats:101–158` provides useful local regression coverage. By inspection, busy, stale-idle, and ceiling tests fail against the old watcher; the idle-transition test also passes old code because it never asserts survival before `_idle`. The subshell correction properly prevents `set +e` leaking into assertions. Tests lack full restart-loop coverage, session ownership, Stop continuation, signal churn, missing hooks, and an upper timeout bound.

Review was read-only; tests were not executed because they create files. Prioritize session-bound shutdown coordination and preserving accepted restart intent, then add integration coverage.
