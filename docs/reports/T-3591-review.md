# T-3591: independent review (rung 1: parent session, not the producer)

**VERDICT: GREEN.**

**WHAT I CHECKED (live server, after restart):**
- `/tasks/T-2200` and `/tasks/T-2202` (unticked Human criteria past an intervening `## ` heading): 0 `/api/task/<id>/complete` forms. Before the fix, each page showed the button.
- `/tasks/T-3147` (partial-complete, both real Human criteria ticked): 0 forms. That is correct by the pre-existing T-640 rule at web/blueprints/tasks.py:870: the detail page never offers Complete for a task already in `work-completed`; those finish through /approvals, which T-3590 fixed.
- Diff 9bfb6bded: the change is minimal. `can_complete` adds `human_unchecked == 0` from `count_human_acs`, the same scoping as `is_ready_for_batch_completion`; nothing else changes.
- The positive control is covered by `tests/web/test_t3591_task_detail_complete_button.py::test_all_ticked_control_shows_complete_button`. The worker reports that 2 of its 4 new tests fail with the fix removed.

**GUIDANCE:** none required. Impact is low (it removes a button that could not succeed), so rung 1 is proportionate per IW-7. Cost logged as internal/unmetered.
