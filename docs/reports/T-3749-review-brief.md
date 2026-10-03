# T-3749 — independent review brief

**Task:** `.tasks/active/T-3749-watchtower-inception-decide-times-out-at.md`
**Commits:** `86a814b78` (code + tests), `30f6332e0` (task file, vendor sync, fabric card), `237cea348` (round-1 fixes), `dd2e02d38` (round-2 fixes)

## The incident

The operator pressed GO on T-3631 in Watchtower. `web/blueprints/inception.py`
ran `fw inception decide … --from-watchtower` through `run_fw_command(timeout=30)`.
The chain ran ~40 s, the subprocess was killed mid-chain, and the page said
"⚠ Your decision is saved. Automatic completion was blocked by a framework gate …
Reason: Command timed out" — false: completion had happened.

## What changed

| File | Change |
|------|--------|
| `web/decide_runner.py` (new) | `launch()` starts `python3 -m web.decide_runner --run …` with `start_new_session=True`, an exclusive per-task `flock` (`.context/working/decide/<task>.lock`) handed to the child via `pass_fds` (second launch → `Busy`), logs to `.context/working/decide/<task>-<ts>/{stdout,stderr,runner}.log`, `status.json` (starting → running → finished(rc) → done(commit_ok)). The runner runs fw with **no timeout**, then commits follow-up writes via `_commit_decision(…, followup=True)`. `classify()` maps (landed, completed, running, rc) to one outcome. `surface()` reports a failed follow-up commit or a runner that died before `done`. |
| `web/blueprints/inception.py` | `record_decision` calls `_run_decide()` (launch + wait up to `DECIDE_WAIT_SECONDS=25` for runner exit or decision+completed/), classifies, commits as soon as the decision landed, words the message per outcome. `_commit_decision` now takes a lock (`.context/working/decide/commit.lock`) around the old body (`_commit_decision_unlocked`). `inception_detail` passes `decide_followup_warning=_dr.surface(...)`. |
| `web/templates/inception_detail.html` | `?notice=` banner and the `?warning=` banner moved OUTSIDE the active-only card (after GO the task is in completed/, where the old banner never rendered); `decide_followup_warning` banner. |
| `lib/design_register.py` | `LazyTaskIndex` — per-id load, same entries as `task_index()`; used by `self_deferrals` and `close_check` when no index is passed. |
| `.gitignore` | `.context/working/decide/` |
| tests | `tests/unit/test_t3749_decide_detached.py` (new, 25 tests); three existing suites moved their mock from `run_fw_command` to `_run_decide`. |
| `tests/scripts/t3749-decide-timing.sh` (new) | measurement harness (clone → synthetic inception → timed decide, optional xtrace). |

## Agent ACs → evidence

1. **Chain measured, per step, in ## Context.** Table of 12 steps in the task's
   `## Context`, from `tests/scripts/t3749-decide-timing.sh --xtrace`. Dominant
   step: self-deferral gate 20.3 s (full task index). After the lazy index:
   task-in-completed/ 3.2 s, exit 18.0–18.3 s (two plain runs).

2. **GO returns well inside its timeout; the chain can't be cut.** No request
   timeout reaches the chain: `launch()` (`web/decide_runner.py`) uses
   `start_new_session=True` and the runner calls fw with no timeout.
   `_run_decide` (`web/blueprints/inception.py`) returns at the primary result.
   Test: `test_slow_chain_outlives_the_wait_and_is_not_killed` — fake fw moves
   the task at 0.3 s then sleeps 3 s; `_run_decide(wait=10)` returns in <3 s with
   `running=True`; the chain then finishes in a different session id;
   `status.json` reaches `done` with rc 0; the lock is released. A runner
   orphaned by its parent (parent `os._exit(0)` right after launch) was also
   checked by hand to reach `done`.
   Deviation from the literal AC wording: the *whole* decide is detached (not
   just the slow side effects) — see the task's `## Decisions` for why
   (update-task.sh guarantees unchanged).

3. **Never "Command timed out" / gate claim for a landed decision that is still
   running.** `classify()` returns `LANDED_RUNNING` / `LANDED_COMPLETING` /
   `PENDING` for every running state; only a FINISHED chain can be
   `LANDED_GATE_REFUSED` (gate wording + real reason, as the brief required) or
   `LANDED_FOLLOWUP_FAILED` ("task is completed. A follow-up step reported a
   problem"). The string "Command timed out" is no longer produced on this path
   (`run_fw_command` is not called by `record_decision`).
   Tests: `test_a_running_chain_is_never_a_gate_refusal`,
   `test_landed_and_still_running_says_so`,
   `test_landed_completion_still_running_is_not_a_gate_claim`,
   `test_not_landed_and_still_running_is_in_progress_not_failure`,
   `test_form_path_landed_running_redirects_with_notice_not_warning`.

4. **Regression test for the message classification.** `test_classify` (11
   parametrised cases) plus the route tests above, plus
   `test_landed_and_done_is_plain_success`,
   `test_landed_and_gate_refused_keeps_gate_wording_with_real_reason`,
   `test_not_landed_and_finished_is_a_failure`,
   `test_second_click_while_running_is_refused_not_restarted`.

## Round 1 → round 2 (commit `237cea348`)

Round 1 (`docs/reports/T-3749-review-codex-r1.md`) returned FAIL on:

| Finding | Fix | Test |
|---|---|---|
| P1 failed chain whose commit succeeded is not surfaced | `surface()` reports any `done` run with `rc != 0`, as well as a failed commit | `test_surface_reports_a_failed_chain_even_when_its_commit_succeeded` |
| P1 response unbounded: request takes the commit lock + git | The request **never commits**. The runner polls its fw child and commits the decision as soon as it lands (`primary_commit_ok`), then again at the end (`commit_ok`). The request reports whatever the runner has recorded; later failures appear via `surface()` | `test_request_does_not_commit`, `test_runner_reported_commit_failure_is_shown`, `test_chain_slower_than_the_wait_through_the_real_route` (asserts `primary_commit_ok` recorded) |
| P1 runner death frees the lock while fw survives | runner records `fw_pid`; `launch()` and `is_running()` also refuse when that pid is alive and its `/proc/<pid>/cmdline` is still `… decide … <task>` (pid-reuse guard) | `test_dead_runner_with_live_fw_still_blocks_a_second_launch` |
| AC3: killed chain (rc −9 / 137 / −1) worded as a gate | `gate_exit(rc)` = `0 < rc < 128`; anything else with the decision written and the task not completed is `LANDED_INTERRUPTED` ("the decide command stopped (exit N) before completing the task"); a killed chain with nothing written says "stopped unexpectedly (exit N)" | `test_only_a_plain_nonzero_exit_is_a_gate_refusal`, `test_landed_and_killed_is_not_a_gate_claim`, `test_not_landed_and_killed_says_it_stopped`, extra `test_classify` rows |
| AC4: wait expiry not exercised | real route + real runner + fake fw that lands the decision 2.5 s in, `DECIDE_WAIT_SECONDS=1`: answers "Decision in progress" in <2.4 s, then the chain finishes, `done`, rc 0 | `test_chain_slower_than_the_wait_through_the_real_route` |

Remaining by design: if the primary result takes longer than
`DECIDE_WAIT_SECONDS` (25 s), the response says the decision is still being
recorded — truthful, not a failure, and the chain keeps going.

## Round 2 → round 3 (commit `dd2e02d38`)

Round 2 (`docs/reports/T-3749-review-codex-r2.md`) returned FAIL on:

| Finding | Fix | Test |
|---|---|---|
| P1 runner dies between starting fw and recording `fw_pid` → lock free, chain alive | the runner passes the task-lock fd to fw (`pass_fds`), so fw and its children hold it; the lock is free only when the whole chain has ended. `fw_pid` check stays as a second line | `test_lock_survives_a_runner_killed_before_it_records_fw_pid` (erases `fw_pid`, SIGKILLs the runner, asserts `Busy`); a mutant with `pass_fds=()` fails it |
| P2 exit 124 classified as a gate | `gate_exit(rc)` is now `0 < rc < 124`: 124 (timeout(1)), 125–127 (could not run), ≥128 (signal), negative, −1, None are all `LANDED_INTERRUPTED` | `test_only_a_plain_nonzero_exit_is_a_gate_refusal`, `test_classify` row 124 |
| P2 `surface()` saw only the newest run | reports every failed / dead run since the last CLEAN run (done, rc 0, committed); a newer running or failed run cannot hide an older failure; a clean run supersedes older ones because it ran the whole chain (archive, episodic, commit) | `test_surface_newer_attempt_does_not_hide_an_older_failure`, `test_surface_a_clean_newer_run_supersedes_older_failures` |
| AC2 wording vs. design | AC text now states the built design explicitly (the dispatch brief prescribed it: detach the decide, wait for the PRIMARY result, respond, keep running) | — |

## Round 3 (commit `382200b80`) — fixed, NOT re-reviewed (3-round cap)

Round 3 (`docs/reports/T-3749-review-codex-r3.md`) returned FAIL on two P2s;
all other checks were MET (no overlapping-launch path, no gate wording for a
timeout or exit 124). Both were fixed after the review:

| Finding | Fix | Test |
|---|---|---|
| DEFER still running said "Task completed" | LANDED_RUNNING wording depends on the decision: go/no-go "Task completed…", defer "The task stays open (deferred)…" | `test_defer_still_running_does_not_claim_completion` |
| missing episodic on a completed task read as a clean run (update-task.sh exits 0 on that failure) | runner checks `.context/episodic/<task>.yaml` after fw exits and records `episodic_ok`; `surface()` treats `false` as not clean and names the recovery command | `test_surface_reports_a_missing_episodic_on_an_otherwise_clean_run`; slow-chain test asserts `episodic_ok: false` end to end |

## Commit / uncommitted-state handling (current)

- The runner commits the decision as soon as it lands (task in completed/ for
  go/no-go), while the chain continues; and again when fw exits
  (`followup=True`), capturing the post-move writes. Commits across runs go
  through one lock (`_commit_decision`), held only by runners.
- If a commit fails, `status.json` records it and `surface()` puts a banner on
  `/inception/<id>` (the slow-chain test's scratch repo has no HEAD, so it
  asserts this end to end).
- If the chain exits non-zero, or the runner dies before `done`, `surface()`
  reports it.

## Known, not changed

- Post-move components auto-populate (≈11 s, grep/sed per fabric card) is left
  as is: it no longer blocks Watchtower, and update-task.sh's close guarantees
  were out of scope to change.
- `tests/unit/test_operator_facing_stderr.py::test_every_stderr_render_site_is_sanitized`
  fails on `web/blueprints/approvals.py:741`, which is unmodified here and
  present at HEAD before this task (introduced by T-3694, `749067324`).

## Questions for the reviewer

- Can a detached decide leave the task half-archived or uncommitted with no signal?
- Can two GO clicks start two chains?
- Does any message still claim a gate blocked a timeout?
