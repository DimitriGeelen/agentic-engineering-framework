# T-5083 Human AC#1: hand-back note after the last tick (judge-t-5083-r3-1f5faf10caee)

Revision reviewed: 02781000ab4f9f0055062eb5e994199a6182a692

## About the brief's "capture failed" banner
The brief's banner says no page could be derived. But the brief also lists six screenshots that `fw ux shots` captured from steps files (URL /review/T-9002, a demo task). I opened and viewed all six. Both capture.json files record the steps sha256 that the brief registered (49ed3b9e…, 1c210b0a…), and every PNG's sha256 matches its capture.json entry. So I did see the rendered page.

## What I checked
I viewed every screenshot at 1024, 1440 and 1920 for both states. I also viewed the .context/visual/T-5081 shots that the criterion names. last-tick and untick@1440 are byte-identical to the T-5083 copies. T-5081 untick@1024 and @1920 differ in bytes, but they look the same as the T-5083 copies.

- **last-tick (all widths):** Human ACs 2/2 and both cards ticked. Under the check list, a green-bordered note reads in bold "Every Human check is ticked: handed back to the agent to close." and then "Untick a check to take it back." The header shows "Owner: agent". The note has no clipping or overlap. At 1920 the bold line wraps onto two lines, which is fine.
- **untick (all widths):** Human ACs 1/2 and "Second human check" is unticked and expanded. The hand-back note is gone. In its place is a neutral grey note: "A Human check is open: the task is with you. When every check is ticked it goes back to the agent to close." The header shows "Owner: human". The note has no clipping or overlap.

## Source cross-check
At the reviewed revision, web/templates/_review_acs.html:109-122 has #task-handed-back-marker and #task-with-operator-marker, in exclusive if/elif branches, with exactly the wording above.

## Verdict recorded: not-evaluated (my reading of the screenshots: met)
After the last tick, a clear note under the check list says the task is handed back to the agent to close and says how to take it back (untick). After unticking, that note is gone. Its replacement is a different note that says the task is with the operator, which goes beyond the criterion rather than against it.

## Why the recorded outcome is not-evaluated
`fw reviewer verdict record --outcome green` refused with "no required page was recorded for this render criterion" (lib/verdict_ledger.py:2610). Run run-t-5083-edba2c4393 has no required page registered for AC#1 because the brief's page capture failed: no page could be derived from the task or criterion text. Under the brief and T-3986, a render criterion with no recorded page is not-evaluated. The screenshots I viewed show the criterion met. The block is that the run's page registration is missing, not the work.
