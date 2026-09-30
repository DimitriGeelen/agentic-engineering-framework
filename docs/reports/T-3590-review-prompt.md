You are an INDEPENDENT REVIEWER (not the builder). EVALUATE, do not rubber-stamp. Verdicts: green / amber / red / escalate, with guidance. Repo /opt/999-Agentic-Engineering-Framework: read-only. Do NOT POST to the live batch-complete endpoint (it would close T-3147, a real task). Do not create tasks.

## What changed
The previous review (docs/reports/T-3586-T-3587-review.md, part A) found that /approvals offered to batch-complete T-2200 and T-2202, which were not ready, because two parsers disagreed. T-3590 fixed it: commits c1a6fc275, 65b3780e8 and 4a4f2bca6; spec .tasks/active/T-3590-*.md. There is now one canonical predicate, `is_ready_for_batch_completion` in web/shared.py, and the form posts the displayed task ids, which the handler re-checks on POST.

## Judge
1. **Correctness.** Is there one predicate, used everywhere a decision is made (the batch button, its count, the per-card "Complete Task" button, the handler)? Does the fixture test really reproduce T-2200's shape? Read T-2200's task file and compare.
2. **Live page.** It offers only T-3147. Read T-3147's task file: is it genuinely ready (partial-complete, every real Human criterion ticked, template-comment examples not counted)? Are T-2200 and T-2202 still shown as pending review rather than hidden?
3. **Handler safety.** It completes only the posted ids and refuses the rest, and an empty post completes nothing. Check with the Flask test client on fixtures, never against the live server.
4. **Render.** Screenshot /tmp/playwright-mcp/review/t3590-approvals.png, plus the live page via curl. Does the batch area read correctly (it names the task in the confirmation), and did anything else on /approvals break?
5. **T-3586's criterion "Watchtower batch-complete still completes a ready task"** was proven by the last review through the real handler, BEFORE T-3590 changed that handler. Re-prove it against the NEW handler, with the Flask test client and a fixture: a posted ready id completes.

Write docs/reports/T-3590-review.md with VERDICT / WHAT I CHECKED / GUIDANCE, one section covering T-3590 and one line on T-3586's criterion. Print only the verdict line and the T-3586 line.
