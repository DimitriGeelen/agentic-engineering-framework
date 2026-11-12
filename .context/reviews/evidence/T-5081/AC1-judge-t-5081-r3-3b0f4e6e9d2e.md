# T-5081 Human AC#1 — reviewer judge-t-5081-r3-3b0f4e6e9d2e (revision 0430d7e86)

Judged by the restated title (accepted 2026-11-12, V-20261111-199aed98): note shown *below the check list*.

## Code (at 0430d7e86)
- web/templates/_review_acs.html:106-121: `handed_back` branch renders "Every Human check is ticked: handed back to the agent to close. Untick a check to take it back."; `with_operator` branch renders "A Human check is open: the task is with you. When every check is ticked it goes back to the agent to close." Both sit after the AC list.
- web/blueprints/tasks.py:1312-1335 `_owner_after_human_tick`: last Human tick -> owner agent; untick on a review-waiting task -> owner human.

## Screenshots (demo task T-9002, two Human checks, served by this repo's code; steps manifests checked)
- last-tick @1024/1440/1920: Human ACs 2/2, both struck through, Owner: agent; green-bordered note below the list reads "Every Human check is ticked: handed back to the agent to close." Visible, unclipped, no overlap at all widths (wraps to two lines at 1920, still clean).
- untick @1024/1440/1920: Human ACs 1/2, second box open with its steps, Owner: human; grey note below the list reads "A Human check is open: the task is with you." Visible, unclipped, no overlap.
- Capture manifests: last-tick clicks "Second human check" then waits for "handed back to the agent to close"; untick starts from that state, clicks again, waits for "the task is with you" — i.e. real tick/untick interactions.
- Visual Verification table in the task: both rows ok at all three widths; consistent with what I see.

## Page screenshots
- 01-review-t-5079: T-5079 is now work-completed (Task completed marker); no console errors. Not a waiting task anymore, so the demo task is the relevant evidence; the example URL in Steps is merely "e.g.".
- 02-tasks: board renders, T-5081 in Awaiting review; no console errors. Not material to this AC.

## Verdict: green
Both notes read clearly and say exactly what the restated criterion asks.
