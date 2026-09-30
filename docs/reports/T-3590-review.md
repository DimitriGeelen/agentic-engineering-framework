# T-3590 independent review: one canonical batch-ready predicate on /approvals

**Reviewer:** t3590-review-263c5a423c84 (independent, not the builder) · 2026-09-30
**Scope:** c1a6fc275, 65b3780e8, 4a4f2bca6 (the spec is in `.tasks/active/T-3590-*.md`). I also re-proved T-3586's batch-complete criterion against the new handler.
**Live Watchtower:** http://192.168.10.107:3002 (pid 3934130). `bin/fw watchtower current` reports it as current. I made read-only GETs only and sent no POST.

---

## VERDICT

**GREEN.** The false-ready defect from the T-3586 review is fixed at the root. One predicate, `is_ready_for_batch_completion` (web/shared.py:1418), decides the batch count, the posted ids and the handler's re-check. The handler completes only the ids that were posted and are still ready. It refuses everything else and names each refused id. An empty post completes nothing. On the live page the batch area offers only T-3147, which is genuinely ready. T-2200 and T-2202 still appear as pending review, not hidden. I found no blocking defects. The guidance below lists three minor follow-ups.

**T-3586 criterion "Watchtower batch-complete still completes a ready task": RE-PROVEN on the new handler.** A posted ready fixture was completed by the real `fw task update` subprocess under `CLAUDECODE=1`. A non-ready id posted in the same request was refused.

## WHAT I CHECKED

1. **One predicate, used for every decision.**
   - `is_ready_for_batch_completion` returns true only when all three hold: status is `work-completed`, the task has at least one Human criterion, and none is unticked. It counts with `count_human_acs`, which uses the same T-3139 scoping as `count_unchecked_human_acs`: every `### Human` block, with HTML comments stripped.
   - `_load_batch_ready_tasks` (approvals.py:474) builds `ready_count` and `batch_ready` from it. `complete_batch` (approvals.py:1014) re-reads each posted id from disk and re-judges it with the same predicate.
   - The sort priority (`has_unchecked_review_ac`), the badge count and the card's Complete condition (`unchecked_count`) now use the canonical scoping.
   - `_parse_acceptance_criteria` remains on /approvals only for the display list. A grep-level test pins this (`test_approvals_makes_no_decision_with_the_display_parser`).
   - **Per-card "Complete Task" button.** It does not call the predicate. It is gated on `unchecked_count == 0`, and admission to the card list requires `unchecked_count > 0`, so it can never render on /approvals. The live page has 0 such buttons. That is consistent, not a gap: readiness is offered only through the batch path. Its handler (`tasks.py:1098`) does not pass `--skip-acceptance-criteria`, so the gates would fire anyway.
   - The vendored copy of `is_ready_for_batch_completion` is byte-identical.

2. **The fixture really has T-2200's shape.** Real T-2200 has `### Agent` (ticked), then `## Status: COMPLETED 2026-06-09` with prose and ticked bullets, then `### Human` with one unticked `[REVIEW]`, then the template comment containing the `[REVIEW]` and `[REVIEWER]` example stubs. `T2200_SHAPE` reproduces the structurally relevant parts: the intervening `## Status:` heading, the unticked Human block after it, and the display parser seeing zero Human criteria. The fixture omits the template comment, but `NO_HUMAN` covers comment stripping, and the real files confirm it.
   - I ran the predicates on the real files:

     | Task | status | `count_human_acs` | ready |
     |---|---|---|---|
     | T-2200 | started-work | (1, 1) | False |
     | T-2202 | started-work | (1, 1) | False |
     | T-3147 | work-completed | (2, 0) | True |

   - Across all 513 active tasks, the only ready task is `['T-3147']`.

3. **T-3147 is genuinely ready.** It is `status: work-completed` with `owner: human`, so it is partial-complete. It has 7 of 7 Agent criteria ticked and 2 of 2 real Human `[REVIEW]` criteria ticked (D5 and D1 rulings). The two unticked `- [ ]` lines at file lines 174 and 183 are the template examples inside `<!-- … -->`, and the count correctly excludes them (total 2, not 4).

4. **T-2200 and T-2202 are still shown.** On the live /approvals page both are listed as pending cards. Each carries the new note "1 unticked Human criterion sit outside the Acceptance Criteria section and are not shown here — open the task". Neither has a Complete button, and neither is in the batch form.

5. **Handler safety.** I tested with the Flask test client against a **throwaway `git clone` of HEAD in /tmp/t3590-rev** with its origin remote removed. `PROJECT_ROOT` pointed at the clone, and `CLAUDECODE=1` was set. The real subprocess and gates ran, and nothing touched the repo. I grepped the repo `.context` and `.tasks` for the fixture ids afterwards and found nothing.

   | Posted ids | Result |
   |---|---|
   | (none) | Refused: "no task ids posted". Nothing completed. |
   | T-2200, T-2202, T-9952 (started-work, all Human ticked), T-9953 (work-completed, T-2200 shape), T-0001, `../x` | All six refused and named: "not ready" or "not an active task". Nothing completed. The path-traversal id is rejected by the `^T-\d+$` check. |
   | T-9951 (partial-complete, all Human ticked) + T-2200 | "Completed 1 task(s): T-9951" and "T-2200: refused". T-9951 moved to `.tasks/completed/` and its episodic record was generated. T-2200 stayed in active/. |

   - The rendered /approvals page in the clone offered exactly `['T-3147', 'T-9951']` (the unedited clone copy of T-3147 plus my fixture), with the confirmation "Complete 2 task(s) with all Human ACs checked: T-3147, T-9951?".
   - The builder's own route tests (`test_post_completes_only_posted_ready_ids_and_refuses_the_rest`, `…_no_ids…`, `…never_reaches_beyond_the_posted_list`) cover the same ground with a faked subprocess. My clone run adds the real subprocess.
   - The builder's suite and the neighbouring approvals suites (`test_t3590_batch_ready_predicate.py`, `test_approvals*.py`, `test_approvals_expand_overflow.py`) all pass: **44 passed** in 171s.

6. **Render.** In the screenshot (`/tmp/playwright-mcp/review/t3590-approvals.png`), the batch button "Complete 1 Ready Task" sits under the "Human Acceptance Criteria" header, with the id `T-3147` beneath it.
   - The live curl shows the form posts exactly `task_id=T-3147`, and `hx-confirm` reads "Complete 1 task(s) with all Human ACs checked: T-3147?". The confirmation names the task.
   - The live HTML contains no traceback or server error. The filter chips, the BVP proposal cards, the verification cards and the header count ("360 across 329 tasks") render normally, and nothing else on the page looks broken.

## GUIDANCE

None of these block the verdict.

1. **(Minor, render)** The batch area shows the ready task only as a bare id (`T-3147`) under a full-width button. T-3147 has no card on the page, because it is not pending, so the operator is confirming a close for a task whose name they cannot see. Render each id as a link to `/tasks/<id>` with its name; `batch_ready` already carries `name`.
2. **(Minor, copy)** "1 unticked Human criterion **sit**" should read "sits" in the singular. The pluralisation logic already exists for "criterion/criteria"; extend it to the verb.
3. **(Follow-up, other surface, same root cause)** `_parse_acceptance_criteria` is still used for decisions on `/tasks/<id>`. At tasks.py:865, `can_complete = all(ac["checked"] …)`, and the live `/tasks/T-2200` and `/tasks/T-2202` pages each show a "Complete Task" button. This is not dangerous: `update-task.sh:249-257` refuses a `### Human` block that sits outside `## Acceptance Criteria`, so a click errors instead of closing the task. It is still a button that should not be offered. Either apply guidance item 2 from the T-3586 review (fix the parser's scoping) or point `/tasks` at the canonical count. File it as its own bug task.
4. **(Note)** Status-`work-completed` tasks re-enter update-task through the partial-complete recheck path, so the batch's `--skip-sovereignty` and `--skip-verification` were not consumed and left no bypass-log rows for T-9951. This is expected under T-3586's "only consumed flags need a reason" rule. It does mean the batch leaves no bypass-log trace for ready tasks; the task file and episodic record are the audit trail.

**Cleanup:** my only artefacts are `/tmp/t3590-rev` (a throwaway clone), `/tmp/t3590-drive.py`, `/tmp/t3590-live.html`, `/tmp/t.html` and this report. I created no task in the repo, sent no POST to the live server, and did not touch T-3147.
