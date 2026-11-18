# T-5226 Human AC#1 — evidence report (panel seat claude-code, rung 5)

Revision reviewed: de6aafdc2a2da7947aa716530a7d9a9cdcedc8e5
Method: judged the supplied screenshots only (did not re-run the app or the capture: cannot reproduce, by brief).

## Criterion
An inception that is not ready reads plainly as not ready, with no way to decide it.
Expected: /inception/T-5224 says plainly that it is not ready for a decision and what is still owed, and shows no GO / NO-GO / DEFER buttons.

## What the images show

### 01-inception-t-5224 (page /inception/T-5224, 1280 wide)
- Top banner: "Decision pending — exploration in progress".
- "Open Questions" section lists IW-1 .. IW-4 in full.
- "Record Decision" section holds one dashed-border box, heading in bold:
  "Not ready for your decision — the agent still owes:" followed by
  "IW-1: no answer recorded yet", "IW-2: no answer recorded yet", "IW-3: no answer recorded yet", "IW-4: no answer recorded yet",
  and the line "This is agent work, not yours: each open question needs a recorded answer (answered / deferred / dissolved) with a reason before a GO or NO-GO can be recorded."
- No GO, NO-GO or DEFER button, no decision form, no rationale field anywhere on the page. The only button on the page is "Add Assumption". The words GO / NO-GO / DEFER appear only as plain text (Go/No-Go Criteria section, "Recommendation: DEFER", the box's explanatory sentence).
- Owed list is in plain words, not the raw shell form (`disposition=false rationale=false`).

### not-ready@1024 / @1440 / @1920 (Visual Verification checklist: state not-ready, control "Record Decision box")
- 1024: box fully visible inside its card, heading, four owed lines and the closing sentence (wraps to two lines) all readable; no clipping, no overlap, no decision controls.
- 1440: same, closing sentence on one line; no clipping or overlap.
- 1920: same; content column centred, box unclipped; no decision controls.
- Checklist cells (ok / ok / ok) agree with what I see.
- Outside the checklist control: at 1024 the site-wide top navigation wraps (theme toggle drops to a second row). This is the shared nav, not something this page or task introduced, and not the listed control; noted, not counted against the criterion.

### 02-inception (/inception list) and 03-assumptions (/assumptions)
- Both render fully, no broken layout. The list shows ACTIVE / DEFER / GO / NO-GO badges; no EXPLORING badge is visible, which the criterion itself predicts ("no live inception is EXPLORING yet") and places outside the page check (covered by tests/unit/test_t5226_inception_exploring.py). I did not judge that test; the criterion's Expected clause does not ask for it on the page.
- Browser recorded no console or page errors on the three pages (capture note, T-4960).

## Observations that do not change the verdict
- T-5224's own Human AC text on the page still reads "Record decision via the Watchtower form or the command shown alongside the QR code". That is T-5224's task-template wording shown verbatim, not a control; the Record Decision section directly below states it is not ready. A reader could find the two slightly at odds; a possible follow-up, not a failure of this criterion.
- "Agent Recommendation: DEFER" is shown while the page says not ready. It is text, not a way to decide.

## Verdict
green — the page states plainly that it is not ready for a decision, names what is owed (IW-1..IW-4, each without a recorded answer), and offers no GO / NO-GO / DEFER control, at 1024, 1440 and 1920.
