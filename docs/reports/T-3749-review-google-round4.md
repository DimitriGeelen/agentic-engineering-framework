The pytest execution for `test_t3749_decide_detached.py` has been launched in the background to verify test results. I will wait for it to complete.
I have launched the full test suite from the task verification block to determine whether all verification tests pass. I will wait for the execution to finish.
# Independent Adversarial Review: Round 4

**Task:** [.tasks/active/T-3749-watchtower-inception-decide-times-out-at.md](file:///opt/999-Agentic-Engineering-Framework/.tasks/active/T-3749-watchtower-inception-decide-times-out-at.md)  
**Evaluated At:** HEAD (`df7c66835`), including round-3 fix commit [`382200b80`](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L311-L328)  
**Mode:** READ-ONLY (no repository files modified)

---

## 1. Status of Round-3 Findings

### Finding 1: P2 — DEFER falsely reports completion
- **Round-3 State:** `classify("defer", landed=True, completed=False, running=True)` returned `LANDED_RUNNING`. Its message in `still_running_note` reported **“Task completed”**, even though `DEFER` leaves the task active.
- **Round-3 Fix in `382200b80`:** In [web/blueprints/inception.py:615-621](file:///opt/999-Agentic-Engineering-Framework/web/blueprints/inception.py#L615-L621), `still_running_note[_dr.LANDED_RUNNING]` was changed to conditionally state:
  > *"The task stays open (deferred). Follow-up steps are still finishing in the background — nothing needed from you."*
  Pinned by [`test_defer_still_running_does_not_claim_completion`](file:///opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py#L159-L174).
- **Round-4 Audit:** **STILL OPEN ON ERROR / FOLLOW-UP PATHS**.
  The patch addressed only `LANDED_RUNNING`. It missed the sibling outcome [`LANDED_FOLLOWUP_FAILED`](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L55).
  In [web/decide_runner.py:221-233](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L221-L233):
  ```python
  completes = decision in ("go", "no-go")
  if landed:
      if completes and not completed:
          ...
      if running:
          return LANDED_RUNNING
      return LANDED_DONE if rc == 0 else LANDED_FOLLOWUP_FAILED
  ```
  Because `completes` is `False` for `defer`, any non-zero exit (`rc != 0`, including killed runs `rc=-9`, `rc=137`, or script errors `rc=1`) falls through to `LANDED_FOLLOWUP_FAILED`.
  At [web/blueprints/inception.py:686](file:///opt/999-Agentic-Engineering-Framework/web/blueprints/inception.py#L686), `LANDED_FOLLOWUP_FAILED` unconditionally renders:
  ```python
  f'⚠ Your decision is saved and the task is completed. A follow-up '
  f'step reported a problem — no action needed from you unless it persists.'
  ```
  Executing `dr.classify("defer", landed=True, completed=False, running=False, rc=1)` produces `landed_followup_failed`, which explicitly tells the operator: **“the task is completed”**. A deferred task is parked in `.tasks/active/` with `horizon: later`, never completed.

### Finding 2: P2 — Missing episodic memory can appear clean in Watchtower
- **Round-3 State:** `update-task.sh` captures episodic-generation failures as warnings and exits 0. The runner recorded `state="done", rc=0, commit_ok=True`, which caused [`surface()`](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L236) to treat the run as clean and suppress follow-up warnings.
- **Round-3 Fix in `382200b80`:**
  1. In [web/decide_runner.py:321-323](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L321-L323), `_run` checks if `.context/episodic/{task_id}.yaml` exists for `go` and `no-go` tasks, writing `episodic_ok=ep.is_file()` into `status.json`.
  2. In [web/decide_runner.py:252-260](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L252-L260), `surface()` treats `st.get("episodic_ok") is False` as an unclean run and appends:
     > *"no episodic memory was generated — recover with: bin/fw context generate-episodic {task_id}"*
  3. Pinned by [`test_surface_reports_a_missing_episodic_on_an_otherwise_clean_run`](file:///opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py#L176-L183).
- **Round-4 Audit:** **FIXED**.

---

## 2. Agent Acceptance Criteria Evaluation

| Agent AC | Result | Evidence |
|---|---|---|
| **AC 1:** Chain measured, wall time per step recorded in `## Context` | **MET** | [Task Context](file:///opt/999-Agentic-Engineering-Framework/.tasks/active/T-3749-watchtower-inception-decide-times-out-at.md#L97-L132) documents all 12 steps before the fix (39.6 s total, dominant self-deferral step 20.3 s) and after the fix (3.2 s to completed/, 18.0–18.3 s total exit). The measurement script is present in [tests/scripts/t3749-decide-timing.sh](file:///opt/999-Agentic-Engineering-Framework/tests/scripts/t3749-decide-timing.sh). |
| **AC 2:** GO returns well inside timeout; primary decision synchronous, slow effects detached and logged | **MET** | The request in [`_run_decide`](file:///opt/999-Agentic-Engineering-Framework/web/blueprints/inception.py#L838-L886) polls for primary landing (`_task_in_completed` and `_decision_recorded_in_task`) up to `DECIDE_WAIT_SECONDS = 25` (~3 s measured) and returns without waiting for post-completion side effects. Subprocess is detached via `start_new_session=True` with no timeout. The request never acquires git locks or runs git commands synchronously ([test_request_does_not_commit](file:///opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py#L275)). Runs log to `.context/working/decide/<task>-<ts>/`. Covered by [`test_slow_chain_outlives_the_wait_and_is_not_killed`](file:///opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py#L355) and [`test_chain_slower_than_the_wait_through_the_real_route`](file:///opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py#L404). |
| **AC 3:** Landed decisions never say "Command timed out" / "Automatic completion was blocked"; message says what landed and what is still running | **NOT MET** | False gate and timeout wording are resolved for request wait expiry and exit 124. However, the message fails to state what landed truthfully when a DEFER decision encounters a follow-up failure or abnormal termination (`rc != 0`):<br>1. [`web/blueprints/inception.py:686`](file:///opt/999-Agentic-Engineering-Framework/web/blueprints/inception.py#L686) renders **“Your decision is saved and the task is completed”** when `outcome == LANDED_FOLLOWUP_FAILED`. This falsely claims task completion for a deferred task.<br>2. [`web/decide_runner.py:229`](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L229) classifies killed or abnormal exits (`rc=-9`, `rc=137`) for DEFER as `LANDED_FOLLOWUP_FAILED` rather than `LANDED_INTERRUPTED`, masking process interruption with a false completion claim. |
| **AC 4:** Regression test covers message classification (landed + timed-out side effect → success wording) | **MET** | Parametrized classification coverage in [`test_classify`](file:///opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py#L36-L60), route wording tests in lines 146–304, and end-to-end wait expiry test [`test_chain_slower_than_the_wait_through_the_real_route`](file:///opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py#L404-L440). |

---

## 3. Adversarial Invariant Checks

### 1. Can a detached decide leave the task half-archived or uncommitted with no signal?
**No.**
- **Half-archived state:** If `fw` exits non-zero before or after moving the task to `.tasks/completed/`, `rc` is recorded in `status.json`. [`surface()`](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L236) inspects all runs since the last clean run and surfaces an alert banner on `/inception/<task_id>` (`"the decide command exited with code <rc> — check that the task is where you expect it"`). If episodic generation was skipped/failed, `episodic_ok: false` is flagged (`"no episodic memory was generated — recover with: bin/fw context generate-episodic <task_id>"`).
- **Uncommitted state:** Primary commit failures are reported immediately in the response banner (`"⚠ Decision recorded but not committed: ..."`). Follow-up commit failures are recorded in `status.json` (`commit_ok: false`) and surfaced persistently by `surface()` on `/inception/<task_id>` (`"its writes are not committed: ..."`).
- **Runner crash/SIGKILL:** If the runner dies before writing `state="done"`, `surface()` detects that `st.get("state") != "done"` and displays `"a decide run stopped before it finished (state: ...; log: ...)"`.

### 2. Can two GO clicks start two chains?
**No on the primary locking path.**
- In [`launch()`](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L178-L218), an exclusive non-blocking `fcntl.flock` is taken on `.context/working/decide/<task_id>.lock`.
- The file descriptor `lock_fd` is handed to the runner via `pass_fds=(lock_fd,)`, and the runner passes it directly to `fw` via `proc = subprocess.Popen(..., pass_fds=lock_fds)`.
- Because the kernel file lock is held by the open file description, it remains locked across the entire process lifetime of the runner and `fw`. Any overlapping click raises [`dr.Busy`](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L74), returning the swappable fragment `"A decision for <task> is already being recorded by an earlier click; this one was not started."`
- **Secondary fallback defect noted:** The secondary fallback guard [`_pid_is_decide`](file:///opt/999-Agentic-Engineering-Framework/web/decide_runner.py#L130-L149) contains a defect: on Linux systems with `yama.ptrace_scope=1` or container sandbox restrictions, reading `/proc/<pid>/cmdline` returns 0 bytes (`b""`) without raising `OSError`. Consequently, `_pid_is_decide` evaluates `b"decide" in argv` as `False` instead of falling back to liveness, failing [`test_dead_runner_with_live_fw_still_blocks_a_second_launch`](file:///opt/999-Agentic-Engineering-Framework/tests/unit/test_t3749_decide_detached.py#L441-L461). However, the primary `flock` inherited via `pass_fds` remains effective.

### 3. Does any message still claim a gate blocked a timeout or claim completion that did not happen?
- **Gate blocked a timeout:** **No.** Neither wait expiry nor process termination with code 124 triggers gate-refusal wording.
- **Claim completion that did not happen:** **YES.** In [web/blueprints/inception.py:686](file:///opt/999-Agentic-Engineering-Framework/web/blueprints/inception.py#L686), `LANDED_FOLLOWUP_FAILED` explicitly states:
  > *"⚠ Your decision is saved and the task is completed. A follow-up step reported a problem — no action needed from you unless it persists."*
  When the decision is `defer`, this message is emitted for any non-zero exit or killed process, falsely claiming task completion.

---

## 4. Verification Suite Execution

Running the test line specified in the task's `## Verification` block ([line 309](file:///opt/999-Agentic-Engineering-Framework/.tasks/active/T-3749-watchtower-inception-decide-times-out-at.md#L309)):
```bash
python3 -m pytest tests/unit/test_t3749_decide_detached.py \
  tests/unit/test_inception_decide_htmx_error.py \
  tests/web/test_inception_decide_hardening.py \
  tests/web/test_inception_decide_e2e.py \
  tests/unit/test_decide_commit.py \
  tests/unit/test_inception_decide_warning_widen.py \
  tests/unit/test_t3694_design_register.py -q -p no:cacheprovider
```
Result: **3 failed, 98 passed**.
- `FAILED tests/unit/test_t3749_decide_detached.py::test_dead_runner_with_live_fw_still_blocks_a_second_launch` (AssertionError: `_pid_is_decide` fails when `/proc/<pid>/cmdline` reads empty under Yama ptrace / sandbox restrictions).
- `FAILED tests/unit/test_t3694_design_register.py::test_self_deferral_reproduces_t3691` (`PermissionError: [Errno 13] Permission denied: '/opt/999-Agentic-Engineering-Framework/tests/fixtures/t3694/T-3691-as-closed.md'`).
- `FAILED tests/unit/test_t3694_design_register.py::test_self_deferral_t3691_control_with_real_owners` (`PermissionError: [Errno 13] Permission denied`).

---

VERDICT: FAIL
