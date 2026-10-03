**The timeout fix works on the normal path, but the failure guarantees still have gaps.**

1. **P1 — Two GO clicks can start overlapping chains if the runner dies during child startup.** The runner starts `fw`, then separately records `fw_pid`. It does not pass the task lock to `fw`. Death between those operations releases the lock and leaves a live child whose PID recovery cannot find; the next GO can launch another chain. The existing orphan test supplies an already-recorded PID, so it misses this window. Evidence: [decide_runner.py:283](/opt/999-Agentic-Engineering-Framework/web/decide_runner.py:283), [PID recovery:149](/opt/999-Agentic-Engineering-Framework/web/decide_runner.py:149).

2. **P2 — A timeout exit is still classified as a gate refusal.** `gate_exit()` accepts every code from 1 through 127, including timeout code **124**. I executed `classify("go", landed=True, completed=False, running=False, rc=124)` and obtained `landed_gate_refused`. The route consequently renders “Automatic completion was blocked by a framework gate.” The parametrized test explicitly expects this incorrect classification. The original request timeout has been removed, but the classifier still cannot substantiate its gate claim. Evidence: [classifier:62](/opt/999-Agentic-Engineering-Framework/web/decide_runner.py:62), [message:643](/opt/999-Agentic-Engineering-Framework/web/blueprints/inception.py:643), [tests](/opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py).

3. **P2 — An unresolved failed run can lose its visible warning.** `surface()` checks only the newest run. Starting another attempt immediately hides an earlier dead-runner or failed-commit warning, without verifying recovery. A later successful run also suppresses it without checking whether missing archival side effects were repaired. An in-memory reproduction with an older interrupted run and a newer successful run returned `None`. Logs remain, but the operator-facing signal disappears. Evidence: [surface:241](/opt/999-Agentic-Engineering-Framework/web/decide_runner.py:241).

Each Agent AC in [T-3749](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3749-watchtower-inception-decide-times-out-at.md):

| Agent AC | Result | Evidence |
|---|---|---|
| Chain measured, wall time per step recorded in Context | **MET** | Context contains twelve measured steps, explicitly accounts for BVP and outcome backprop, and records before/after totals. The cited timing harness supports the measurement approach. Timings were not independently rerun. |
| GO returns inside timeout; primary decision/completion synchronous, slow effects detached and logged | **NOT MET** | The implementation detaches the **whole** chain and can return before the decision exists after its 25-second wait. That is a documented deviation, not the stated synchronous guarantee. Normal request-timeout isolation and logging are implemented; the startup crash window above remains. |
| Landed decisions never get timeout/gate wording; message states what landed and remains running | **NOT MET** | Running states are handled correctly, but finished exit 124 is explicitly classified and rendered as a gate refusal. |
| Regression test covers message classification for landed decision plus slow/timed-out side effect | **MET** | Tests cover landed-and-running success wording, a detached slow chain, and real-route wait expiry without killing the chain. This coverage does not establish correct timeout-exit classification; its 124 expectation preserves the defect. |

Direct answers: **ordinary simultaneous clicks are locked out; runner-startup failure permits overlap. Interrupted or uncommitted runs normally produce warnings, but later attempts can mask unresolved failures. Gate wording remains reachable for timeout exit 124.**

Validation was read-only inspection plus in-memory probes; I did not run the filesystem-writing integration suite. The read-only environment also prevents the required `fw handover --commit`.

VERDICT: FAIL