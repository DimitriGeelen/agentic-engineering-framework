# T-5081 Human AC#1: hand-back note on last tick — reviewer judge-t-5081-r3-fe2ca0244c27

Revision: 00d7be1fbc2384d7ac9b47f61afa970d7b345f1a

## What I checked
- Screenshot 01-review-t-5079.png (/review/T-5079): shows the page in its initial state, Human ACs 0/1, check unticked. No hand-back note is visible, because the note only appears after the tick. The ticked and unticked-again states the criterion asks about were never captured.
- Screenshot 02-tasks.png (/tasks): top of the page only (39,459 px page, cut at 16,000 px). It does not show the tick interaction.
- Visual Verification evidence: .context/visual/T-5081/ does not exist. The state 'last-tick' is missing at 1024, 1440 and 1920. The dispatch brief says a render criterion must not be passed without it.
- Source at the reviewed revision, web/blueprints/tasks.py:1332-1333:
  - after the last tick (owner -> agent): "Every Human check is ticked: handed back to the agent to close."
  - after unticking (owner -> human): "A Human check is open again: back with you."
  The wording matches the Expected clause on paper. I could not see where it renders "next to the box", or how it reads in place.

## Result
not-evaluated. I did not see the rendered note in either state, and the required visual evidence is missing.
