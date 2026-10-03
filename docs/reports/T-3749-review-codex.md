Found two remaining message/reporting defects.

- **P2 — DEFER falsely reports completion.** `classify("defer", landed=True, completed=False, running=True)` returns `LANDED_RUNNING`. Its message says **“Task completed”**, although DEFER leaves the task active. Evidence: [classification](/opt/999-Agentic-Engineering-Framework/web/decide_runner.py:219), [message](/opt/999-Agentic-Engineering-Framework/web/blueprints/inception.py:615). Confirmed by executing the classifier in memory.
- **P2 — Missing episodic memory can appear clean in Watchtower.** The completion script captures episodic-generation failure and prints a warning without propagating failure. The runner can consequently record `done`, `rc=0`, `commit_ok=True`, which suppresses the follow-up banner. Evidence: [generation handling](/opt/999-Agentic-Engineering-Framework/agents/task-create/update-task.sh:2786), [clean-run condition](/opt/999-Agentic-Engineering-Framework/web/decide_runner.py:252). The warning survives in logs, so this is **UI silence**, not total absence of a signal.

Each Agent AC:

| AC | Result | Evidence |
|---|---|---|
| Chain measured per step in Context | **MET** | [Task Context](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3749-watchtower-inception-decide-times-out-at.md:111) records twelve steps, including reviewer, episodic, and BVP applicability; the cited timing harness supports tracing. Measurements were not rerun. |
| GO returns within its wait; detached chain continues and logs outcomes | **MET** | [Request wait](/opt/999-Agentic-Engineering-Framework/web/blueprints/inception.py:835) returns on the primary result or deadline. The runner uses a separate session and invokes `fw` without a timeout. [Regression tests](/opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py:329) cover early response and actual wait expiry. |
| Landed decisions receive truthful completion/running wording | **NOT MET** | Timeout classification is fixed, but the DEFER path incorrectly says “Task completed,” as described above. |
| Regression test covers landed decision plus slow side effects | **MET** | [Message test](/opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py:146), [detached-chain test](/opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py:329), and [wait-expiry route test](/opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py:375) cover the intended timeout regression. |

Answers to the requested adversarial checks:

- **Half-archived or uncommitted without a signal?** Runner death, nonzero chain exit, and failed commits are surfaced on the inception page. However, missing episodic memory can produce a clean UI result; its signal exists only in logs.
- **Can two GO clicks start overlapping chains?** No overlapping-launch path found. The exclusive task lock passes from launcher to runner to `fw`, including the startup window before `fw_pid` is recorded. The dedicated kill-window regression covers this.
- **Does a message still call a timeout a gate refusal?** No such path found for request wait expiry or exit 124. Running states and abnormal exits receive distinct wording. Genuine gate-refusal wording remains intentionally.

Validation: executed **18 classification cases and two invariant checks successfully**. Full pytest execution and the required handover commit were unavailable because this session permits no filesystem writes.

**VERDICT: FAIL**