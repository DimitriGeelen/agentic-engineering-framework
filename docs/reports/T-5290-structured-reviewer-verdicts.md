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

### 1409-sprind answer (msg b558c363, 2026-11-20 07:13Z), summarised from German

They say: read it as a DRAFT, not a proven procedure. Their files: tools/betrieb/begruendung_format.md (version 0.1), checker tools/betrieb/begruendung.py, report docs/reports/T-6171-urteil-experiment.md (in their repo; not read here).

1. **Structure.** Header: case, reviewer, round, vote, version of the brief. One section per criterion with fixed labels: vote / evidence (verbatim quote) / location (file and page) / rule (id) / conclusion. Plus: counter-search (what was looked for, what was found), "what would change my mind", and from round 2: changed yes/no and why (a checkable reason with location). PASS and FAIL have the same form; a PASS must give evidence for EVERY criterion, a FAIL names the failed criteria and gives evidence at least for those. The checker establishes mechanically: complete; quote appears verbatim in the package; on the named page (else outcome "other page"); rule id exists; a vote change without a checkable reason does not count.
2. **Why.** Their operator, 2026-11-19: "a fail, if it is justified, is a very good pass. And a pass, if it is unjustified, is a very wrong pass ... How do we establish the quality of the judgment and not by fail or pass?" Measured: their verdicts said "criteria 1-6 hold" with no evidence; three put into the format were all "not checkable" (5-8 items missing). On one case three reviewers reached different verdicts, one without touching the deciding clause at all — invisible in free text.
3. **Contradicted claim (planned, not in operation).** If the evidence contradicts the claim (quote not in the package, not on the page), the reasoning is "not checkable" and the vote does not count; a right verdict with a wrong reason is scored wrong. Disagreement: exchange reasonings, change only with a checkable reason, then widen to five votes, else to the operator.
4. **Before a standard.** (a) Not yet tried with models; their experiment (today's brief / format / format + exchange) is running; unknown whether it raises correctness or only form. (b) The checker finds whether a quote is THERE, not whether it SUPPORTS the claim: needs a second instance with a rubric. (c) Their answer parser was too lenient (2 of 11 faulty answers became PASS): strict parsing is part of the format. (d) For screenshots the "location" must be an image region/coordinates or a selector, not a page.
They will report the experiment result; not certain before 2026-11-22.

### 1409-sprind: format text 0.1 (msg 2753c605, 2026-11-20), summarised

Full text: `fw sidecar inbox --show 2753c605-def3-424e-a923-13da8fd422b1`. Draft, not tried with models.

- **Principles:** a verdict's quality is in its reason; a right verdict with a wrong reason counts as wrong. A reason is checkable only if it says which sentence, where, by which rule, leads to which conclusion. A vote change counts only with a checkable reason ("the others convinced me" is not one).
- **Shape:** one vote per block between `===STIMME===` and `===ENDE===`; YAML header (`format: begruendung/0.1`, case, reviewer, round, vote, failed criteria list, brief version); then `## <id> <title>` sections with `Label: value` lines (indented continuation; a label may repeat for several pieces of evidence).
- **Per criterion:** Vote, Evidence (verbatim quote, ellipsis allowed only between verbatim pieces), Location (path + page), Rule (known id), Conclusion (one sentence linking evidence and rule).
- **Fixed extra sections:** counter-search (searched where/for what, found, outcome); the fact sought (domain-specific to them); "what would change my mind" (concrete, "more evidence" is not enough); from round 2 "change" (changed yes/no, before, why, evidence, location, rule).
- **Consistency:** overall PASS iff every criterion PASS; the failed list names exactly the FAIL criteria.
- **Checker reports per vote:** complete (missing sections/labels); consistent (overall ↔ criteria ↔ failed list); per quote found | only_without_whitespace | other_place | not_found; per location exists | page_missing | unknown; per rule known | unknown; per vote change counts | does_not_count with reason. It does not judge the substance; whether the conclusion follows is graded by a second instance with a rubric.

**Mapping to AEF (first take):** the domain sections (K1–K7, "fact sought") become our criteria (AC#n) and their rule ids our criterion classes and rules; Location gains image region (file + x,y,w,h) and selector forms for render evidence, and file:line for code; the checker's "quote found" becomes, for images, a region comparison against the capture.

### Reading (agent)

- It fits today's failure exactly: the codex red would have had to name a region of 02-approvals.png where the icons are absent; a checker cropping that region and comparing with the reference would refute it mechanically, and the vote would not count instead of blocking the panel.
- Their caveat (a) matters: it is unproven. AEF can still adopt the FORM now (it costs little and makes verdicts checkable), and measure correctness on our own ledger, without waiting for their experiment.
- Caveat (b): "present" is not "supports". The mechanical check stays a floor; the panel exchange (their 3) is the second instance.
- Caveat (c) applies to us: `lib/verdict_ledger.py` / judge parsing must refuse a malformed verdict, never coerce it.

## Dialogue Log

- 2026-11-20, operator: the verdict structure must be fixed for pass and fail alike; take 1409's protocol as the basis; ship it to all consumer projects.
- 2026-11-20, operator chose option 1: start now with the format as a draft for new verdicts (image regions as location for screenshots, strict reader), rather than wait for 1409's experiment result. Agent recommendation: GO, built in slices (brief + strict reader; checker; not-checkable votes do not count and the seat is replaced; later the exchange round).
