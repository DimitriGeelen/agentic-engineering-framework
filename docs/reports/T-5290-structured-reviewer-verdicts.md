# T-5290 — Structured reviewer verdicts

**Status:** EXPLORING. Inception, opened 2026-11-20.

## Trigger

T-5262 (project form-safety exemption list) touched `web/app.py`, so its close needed a render criterion judged by a rung-5 panel. Two rounds:

- claude-code seat: green both times.
- codex seat: red both times (judge-t-5262-r5-codex-8742b556a1e8, -cc747b0f5d67): "02-approvals.png (1280 px) lacks the search and settings icons".
- Checked: in the judge's own captures, the icon zone (x 895-960, y 45-70) of 02-approvals.png and 01-root.png has the same 187 dark pixels; a zoomed crop shows search, settings and the theme toggle. The claim is false. Filed T-5289.

The verdict was free text (VERDICT / WHY / GUIDANCE). Nothing in its form tied the claim to a place in the evidence that could be checked, so the only ways out were a gate bypass or re-running until green.

## Operator, 2026-11-20 (verbatim)

"Okay, we need to enhance the review protocol, so please have a chat with 1409 where we have really improved the protocol to. A reviewer, a fail or a pass should have a certain set structure, and 1409 already has defined that structure. And I want us to implement this in the framework so that all the vendor projects also get this."

## Related

- ring20 (T-4649 consultation, b3): "a structured verdict format as a framework option would replace their addendum".
- 1409 (T-4649 consultation, b4): they attach fixed target questions in their own tool.

## Consultation

- 2026-11-20 → 1409-sprind (client_msg_id 60304ee3): their structure (fields, evidence per claim, pass vs fail), why they built it, what happens when a claim contradicts its own evidence, what they would change for a framework default. Revisit 2026-11-22.

## Dialogue Log

- 2026-11-20, operator: the verdict structure must be fixed for pass and fail alike; take 1409's protocol as the basis; ship it to all consumer projects.
