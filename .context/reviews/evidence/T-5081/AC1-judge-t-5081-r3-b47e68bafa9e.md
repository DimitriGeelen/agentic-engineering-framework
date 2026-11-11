# T-5081 Human AC#1 — hand-back note reads clearly (reviewer judge-t-5081-r3-b47e68bafa9e)

Revision reviewed: c2bcaaa1f6d6f8f6df2370a2f86d85897a8424c7

## What I checked
- Code at the revision: `web/blueprints/tasks.py:_owner_after_human_tick` (note returned in the tick
  response, shown next to the box on the task page / approvals list: "Every Human check is ticked:
  handed back to the agent to close." / "A Human check is open again: back with you.").
- `web/templates/_review_acs.html` + `web/blueprints/review.py`: the review page discards the tick
  response (hx-swap="none") and re-renders the AC fragment; it shows a status panel BELOW the check
  list from task state: "Every Human check is ticked: handed back to the agent to close. Untick a
  check to take it back." / "A Human check is open: the task is with you. When every check is
  ticked it goes back to the agent to close."
- Steps-captured shots (capture manifests last-tick/untick.capture.json, demo task T-9002) at
  1024/1440/1920: both notes are visible, unclipped, no overlap, at all widths.
- Judge capture of /review/T-5079 and /tasks.

## Findings
1. Wording: clear and plain in both states. Tick -> green "handed back to the agent to close" with
   the undo hint; untick -> "the task is with you". Meets the intent of the Expected clause.
2. Contradiction on the same screen: the header "Owner:" line is not refreshed by the fragment
   reload. last-tick shots show "Owner: human" directly above "handed back to the agent"; untick
   shots show "Owner: agent" above "the task is with you". An operator reading the page sees two
   opposite owners until reload. The task's own Visual Verification row admits this ("the header's
   Owner: line refreshes only on reload"). This undermines "reads clearly".
3. Criterion literal out of date:
   - Step 1 example T-5079 is no longer waiting for review (closed 2026-11-11 23:01, commit
     4a87a5e96; file in .tasks/completed/), so it cannot be used to tick a last open check.
   - On the review page the note is not "next to the box": it is a panel under the check list
     (it is next to the box only on the task page / approvals list).
   - The untick note reads "the task is with you" (review page) / "back with you" (task page).
4. Side observation (not this criterion): the judge capture of /review/T-5079 (a closed task)
   shows a "Complete Task" button; the code at the revision would render "Task completed" for a
   task in completed/. The live :3000 Watchtower may not be running the reviewed code.

## Verdict: amber
