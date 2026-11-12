# T-5085 Human AC#1 — independent review (rung-3), revision 69dcb7acf

## Demo-task screenshots (T-9002, steps files hash-matched in the capture manifests)
- last-tick @1024/1440/1920: badge "AWAITING REVIEW", header "Owner: agent", note "Every Human check is ticked: handed back to the agent to close." The header and note agree at all three widths. Nothing is clipped or overlapping.
- untick @1024/1440/1920: badge "AWAITING REVIEW", header "Owner: human", note "A Human check is open: the task is with you." The header and note agree at all three widths. Nothing is clipped or overlapping.
- No completed-state badge in any shot.

## Live page /review/T-5085 (screenshot 01 + curl of http://192.168.10.107:3000/review/T-5085 at the same HEAD)
- Badge "AWAITING REVIEW". Header `<span id="review-owner">Owner: human</span>`. One check is open (Human ACs 0/1).
- No note is rendered under the checks: the HTML after the AC card has only the comment for the decision/completion section. Neither "the task is with you" nor "handed back" appears on the page.
- So for the "while a check is open" state, which the Expected clause names, the header is right but there is no note to compare it with. The demo shows that note only after an untick (an htmx response). It does not appear on a fresh load with a check open.
- Browser recorded no console errors (per brief).

## /arcs (screenshot 02)
Renders normally. Not relevant to this criterion.

## Verdict: amber
The tick and untick states fully meet the criterion. The badge is correct everywhere. The gap is the open-check state on a full page load: the header says Owner: human, but no note under the checks confirms it.
