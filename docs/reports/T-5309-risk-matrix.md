# Risk matrix — screenshots attached to codex review seats (T-5309)

<!-- Drafted under T-5316 (T-5310 practice, slice 4) from .tasks/templates/risk-matrix.md.
     The drafting agent scored it; an independent reviewer judges the scores; the operator
     decides only the acceptances the machine check lists. -->

## Header

- **Change:** the review runtime copies every screenshot a judge brief cites into the codex seat's export and attaches up to 20 of them at launch (`codex exec -i <file>`, listed with sha256 in the dispatch's `attached-images.json`); `lib/vote_checker.py` counts an attached image as viewed (by content hash, and by stem match on the name); codex `vision` is true again in `policy/review-backends.yaml`, so codex votes count on render criteria. Antigravity seats now keep a stream-json run record that the checker reads.
- **Baseline:** the state just before T-5309: codex `vision: false` (T-5289), so codex was not seated on render criteria and no screenshot was sent to OpenAI by the review runtime; a render vote counted only when the seat's own log showed an image view (T-5294). The earlier state (before T-5289: codex voted on screenshots it never opened, G-136) is noted where it changes the answer.
- **Task:** T-5309

## Scales

| Value | Likelihood | Impact |
|------:|------------|--------|
| 1 | rare | negligible |
| 2 | unlikely | minor |
| 3 | possible | moderate (one job or result wrong) |
| 4 | likely | major (token stolen or data leaked, contained) |
| 5 | almost certain | severe (node or network compromised, accounts lost) |

**Score** = likelihood × impact, 1-25. **Bands:** low 1-5, medium 6-12, high 15-25.

## Summary

| # | Risk | Domain | How to detect the door is open | How to detect it happening | Impact | Likelihood | Exists anyway (baseline)? | Introduced by the change? | Key mitigation |
|---|------|--------|--------------------------------|----------------------------|-------:|-----------:|---------------------------|---------------------------|----------------|
| 1 | Screenshot content sent to an outside provider (OpenAI) | data leaving | `attached-images.json` in a codex dispatch dir lists files; review-backends.yaml codex `vision: true` | a cited screenshot shows a secret, a token or internal addresses (for example a `/config` or settings page) | 4 | 2 | yes (claude-code and antigravity seats already receive the same screenshots, so Anthropic and Google see them) | PARTLY NEW (one more provider receives every cited screenshot, pushed at launch rather than on the seat's choice) | only files under `.context/working/judge-evidence/` and `.context/visual/` are copied (lib/review_seat_evidence.py AREAS); no redaction of what a page shows |
| 2 | Reviewer seat prompt-injected by text inside a screenshot | review integrity | a rendered page shows text an outsider wrote (task names from issue intake, peer messages) | a seat's verdict quotes or obeys instructions that appear only in an image | 3 | 2 | yes (the same text reaches codex as text in the export, and the claude seat already views the images) | PARTLY NEW (codex now receives image-borne instructions, and its render votes now count where in the baseline it could not sit render criteria at all; text exposure and the seat sandbox do not remove that added review-integrity route) | at rung 5 a red from any seat blocks and a close needs at least two green vendors; structured verdicts checked by lib/vote_checker.py; seat sandbox (network off, writes only to the disposable export). No reduction for single-seat runs |
| 3 | An attached image is counted as viewed although the model did not examine it | review integrity | vote_checker `seat_viewed_how: attached at launch (T-5309)` on a codex vote | a codex green on a render criterion that the screenshot refutes (the G-136 pattern, now counted) | 3 | 3 | no (in the baseline a codex render vote did not count at all) | NEW (attachment is taken as proof of viewing; the panel's third seat was the operator or a paid seat) | at rung 5 a codex red blocks, and a close needs at least one other vendor's green as well (two when the panel is whole); no reduction for a single-seat run (rung 1/3), where codex can be the only seat |
| 4 | A cited image that was NOT attached is counted as viewed (cap of 20, or a stem match on the name) | review integrity | `attached-images.json` has a non-empty `not_attached` list, or two cited images share a stem prefix (`x.png` and `x-foo.png`) | a vote_checker report marks an image viewed that is in `not_attached` | 3 | 2 | yes (the T-5294 checker, a57af26c1, already matched logged views by stem, so a stem collision was already counted against a logged view) | PARTLY NEW (attached names now enter `_stem_match` in lib/vote_checker.py `image_viewed`, so a collision counts with no view at all) | T-5324 (done 2026-11-21): seat-copy suffix bound to the dispatch id, `not_attached` images never count; T-5333: match by path, not basename |
| 5 | A forged `attached-images.json` makes a vote count | review integrity | the manifest is a plain file in the dispatch dir, readable and writable by the same user | a manifest whose sha256 list does not match the files in the export | 3 | 1 | yes (same-user forgery of the review ledgers is the T-3581 residual) | no (the codex sandbox cannot write the dispatch dir; only a same-user process can, as for every other ledger) | codex sandbox `workspace-write` limited to the export and its temp dir; `fw audit` provenance checks |

## Actor split (one table per risk)

Actors (fixed list): `own-agent-unintentional`, `human-unintentional`, `outsider-intentional`, `provider-host`, `intruder`.

### Risk 1 — Screenshot content sent to an outside provider (OpenAI)

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 1.1 | own-agent-unintentional | an agent captures a page that shows a secret, a token or internal addresses (`fw ux shots` of a settings or config page) and cites it in a judge brief; the runtime attaches it to codex without asking | 2 | 4 | 8 | | |
| 1.2 | human-unintentional | the operator asks for screenshots of a page that shows a secret; the human does not pick which seats get them | 1 | 4 | 4 | | |
| 1.3 | outsider-intentional | an outsider cannot choose what is captured or cited; at most they put text on a page (that is risk 2) | 1 | 1 | 1 | | |
| 1.4 | provider-host | OpenAI retains or exposes the attached images under its terms; harm only when an image carries something sensitive | 1 | 4 | 4 | | |
| 1.5 | intruder | an intruder on the host can read the screenshots on disk directly; the attachment gives them nothing new | 1 | 1 | 1 | | |

### Risk 2 — Reviewer seat prompt-injected by text inside a screenshot

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 2.1 | own-agent-unintentional | an agent's test fixture or page text reads like an instruction and sways a seat's vote | 1 | 3 | 3 | | |
| 2.2 | human-unintentional | the operator's own task text shown on a page is misread as an instruction | 1 | 3 | 3 | | |
| 2.3 | outsider-intentional | text from GitHub issue intake or a peer message, rendered on a Watchtower page, tells the seat to vote green; it now reaches codex as pixels. Mitigated score assumes the worst applicable mode, a single-seat run (rung 1/3) with codex as the only seat | 2 | 3 | 6 | 2 × 3 | 6 |
| 2.4 | provider-host | a provider cannot plant text in our screenshots | 1 | 1 | 1 | | |
| 2.5 | intruder | an intruder with write access can edit the task or ledger directly; injecting through an image adds nothing | 1 | 3 | 3 | | |

Review modes, from the code (lib/review_policy.py, lib/reviewer/judge_cli.py `_plan_seats`, lib/verdict_ledger.py `_panel_state`):

- **Single seat (rung 1 or 3, low or medium impact):** one seat closes the criterion on its own green. On an image run the seat is the first vision kind in registry order that can be dispatched, so codex is the only seat whenever claude is excluded (reassigned after a not-evaluated vote, model retired, or not dispatchable on the host). No panel control applies.
- **Whole panel (rung 5):** three seats (claude-code, codex, antigravity; opencode is left off image runs as blind), three green votes from three vendors; any amber or red blocks.
- **Panel closing on two vendors (rung 5):** when one seat is not-evaluated or not-checkable (vote_checker), or unavailable (GREEN-DEGRADED, T-4490), the panel closes on two green seats of distinct vendors (`MIN_EVALUATING_SEATS = 2`). Any red still blocks.

Mitigation for 2.3: scored in the worst applicable mode, the single seat, so the mitigated value stays 2 × 3 = 6. In a panel, a wrong close needs at least two vendors swayed by the same image, and a red from any seat blocks: 1 × 3 = 3 for a whole panel or a two-vendor close. The structured, checked verdict and the sandbox do not stop a swayed green.

### Risk 3 — An attached image is counted as viewed although the model did not examine it

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 3.1 | own-agent-unintentional | the codex model has the image in its prompt but answers from the brief text, or misreads a downscaled image, and votes green on a broken render; the checker counts it because it was attached. Mitigated score assumes the worst applicable mode, a single-seat run (rung 1/3) with codex as the only seat | 3 | 3 | 9 | 3 × 3 | 9 |
| 3.2 | human-unintentional | the human does not take part in a seat's vote | 1 | 1 | 1 | | |
| 3.3 | outsider-intentional | an outsider cannot steer whether codex reads the image (beyond risk 2) | 1 | 1 | 1 | | |
| 3.4 | provider-host | OpenAI changes how `-i` images are passed or downscaled, silently, and the model sees less than the file. Mitigated score assumes the worst applicable mode, a single-seat run (rung 1/3) with codex as the only seat | 2 | 3 | 6 | 2 × 3 | 6 |
| 3.5 | intruder | no added path beyond what an intruder can already write to the ledger | 1 | 1 | 1 | | |

Mitigation for 3.1 and 3.4, scored in the worst applicable mode (the review modes are listed under risk 2): in a single-seat run codex's green closes the criterion alone, so nothing reduces either score (3.1 stays 3 × 3 = 9, 3.4 stays 2 × 3 = 6). In a panel a codex red keeps the criterion open, and a wrong codex green closes only with another vendor's wrong green on the same criterion: one other vendor when the panel closes on two (a seat not-evaluated, not-checkable or unavailable), two when it is whole. Panel residuals: 3.1 is 2 × 3 = 6 for a two-vendor close (G-136 showed codex asserting what it had not seen, and the panel this replaces had the operator or a paid seat as the third vote) and 1 × 3 = 3 for a whole panel; 3.4 is 1 × 3 = 3 in either panel mode. The panel lowers the chance that a wrong result closes; it does not lower the impact of one, which stays moderate (3).

### Risk 4 — A cited image that was NOT attached is counted as viewed (cap of 20, or a stem match)

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 4.1 | own-agent-unintentional | a brief cites more than 20 screenshots (7 states at 3 widths is 21), or two whose names share a stem prefix (`approvals.png`, `approvals-footer.png`); `image_viewed` matches the unattached one by stem against an attached name and marks it viewed. Mitigated by T-5324 (3900dfbbf, 2026-11-21, after review): the suffix must be the seat's own dispatch id and `not_attached` images never count, so a prefix collision or over-cap image no longer counts as viewed. Not yet closed: two cited images with the same file name in different directories (different content) still collide, because matching is by basename, not path (codex reproduction, 21 PNGs, 2026-11-21); follow-up fix T-5333 | 2 | 3 | 6 | 2 × 3 | 6 |
| 4.2 | human-unintentional | the human does not name the cited images | 1 | 1 | 1 | | |
| 4.3 | outsider-intentional | an outsider cannot choose the screenshot names | 1 | 1 | 1 | | |
| 4.4 | provider-host | not involved: the match happens in our checker | 1 | 1 | 1 | | |
| 4.5 | intruder | an intruder can forge the vote record directly; a name collision gives them nothing new | 1 | 1 | 1 | | |

Partly mitigated: T-5324 bound the seat-copy suffix to the dispatch id and stopped counting `not_attached` images, but matching is still by basename, so same-named images in different directories collide (follow-up T-5333). The stem collision itself predates T-5309 (T-5294 checker); T-5309 widens it from logged views to attached names (PARTLY NEW).

### Risk 5 — A forged `attached-images.json` makes a vote count

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 5.1 | own-agent-unintentional | an agent rewrites a dispatch dir while debugging and leaves a manifest that does not match the launch | 1 | 3 | 3 | | |
| 5.2 | human-unintentional | the human does not edit dispatch dirs in normal work | 1 | 1 | 1 | | |
| 5.3 | outsider-intentional | an outsider has no write access to the dispatch dir | 1 | 1 | 1 | | |
| 5.4 | provider-host | the codex seat's sandbox writes only the export and its temp dir, not the dispatch dir that holds the manifest | 1 | 3 | 3 | | |
| 5.5 | intruder | a same-user process writes a manifest listing every image (the same residual as forging the verdict ledger, T-3581) | 1 | 3 | 3 | | |

## Net

**Adds:** one more outside provider (OpenAI) receives every cited screenshot, pushed at launch (risk 1, PARTLY NEW); codex is now exposed to instructions inside images, and its render votes now count where in the baseline it could not sit render criteria (risk 2, PARTLY NEW); the checker now treats "attached" as "viewed" for codex, which turns codex render votes back into countable votes (risk 3, NEW), and its stem match, already in the T-5294 checker for logged views, now also runs on attached names, so it can count an unattached image as viewed (risk 4, PARTLY NEW; fix T-5324).

**Reduces:** against the state before T-5289, it removes the worst case (codex votes counted on images it never opened, G-136): now every counted codex render vote had the pixels in its prompt. Against the T-5289 baseline it removes the operator from rung-5 render checks and the need for a paid OpenRouter seat, which is the goal.

**Does not change:** same-user forgery of run records (risk 5) exists anyway. Prompt injection through rendered text (risk 2) existed for the other seats; what is new is the codex route.

**Review mode assumed:** mitigated scores are for the worst applicable mode, a single-seat run (rung 1 or 3) where codex can be the only seat; the rung-5 panel lowers likelihood only (see risk 2 and risk 3).

**Controls it needs:** (a) match attached images only by the seat's own dispatch-id suffix or content hash, and treat any image in `not_attached` as not viewed (risk 4; prefix and cap routes shipped as T-5324, same-basename route T-5333); (b) a check before attachment that a cited screenshot is not of a page that can show secrets, or a redaction step (risk 1); (c) a periodic spot-check of codex render greens against the images, so attachment-as-proof is measured rather than assumed (risk 3).

**Needs operator acceptance** (from `lib/risk_register.py --matrix`):

- risk 1 — Screenshot content sent to an outside provider (OpenAI): PARTLY NEW and still 8 after mitigation
- risk 2 — Reviewer seat prompt-injected by text inside a screenshot: PARTLY NEW and still 6 after mitigation
- risk 3 — An attached image is counted as viewed although the model did not examine it: NEW and still 9 after mitigation
- risk 4 — A cited image that was NOT attached is counted as viewed (cap of 20, or a name collision): PARTLY NEW and still 6 after mitigation (T-5324 closed the prefix and cap routes; same-basename images in different directories remain, T-5333) Risks 2 and 3 are scored for a single-seat run; a rung-5 panel lowers them to 3 (risk 2) and 6 (risk 3).

## Register entries to file

Risks with any actor at 6 or more (unmitigated): 1, 2, 3, 4. The parent files these in
`.context/project/concerns.yaml`; ids are placeholders.

```yaml
- id: R-NEW-1
  type: risk
  title: "Screenshot content sent to OpenAI via codex review seats"
  description: "T-5309 attaches every screenshot a judge brief cites to the codex seat (codex exec -i). A screenshot of a page that shows a secret, token or internal addresses goes to one more outside provider; nothing checks what the page shows."
  status: watching
  likelihood: 2
  impact: 4
  score: 8
  ranking: medium
  actors:
  - actor: own-agent-unintentional
    how: "agent cites a screenshot of a settings/config page in a judge brief; the runtime attaches it to codex"
    likelihood: 2
    impact: 4
  - actor: human-unintentional
    how: "operator asks for screenshots of a page that shows a secret"
    likelihood: 1
    impact: 4
  - actor: provider-host
    how: "OpenAI retains or exposes attached images"
    likelihood: 1
    impact: 4
  introduced_by: T-5309
  exists_anyway: true
  mitigation_task: T-YYYY
  created: 2026-11-21
- id: R-NEW-2
  type: risk
  title: "Review seat prompt-injected by text inside a screenshot"
  description: "Outsider text (issue intake, peer messages) rendered on a Watchtower page reaches review seats as pixels and may sway a render vote. Image-borne injection existed for the other seats; T-5309 exposes codex to it and makes codex render votes count, where in the baseline codex could not sit render criteria. In a single-seat run (rung 1/3) a swayed codex green closes the criterion alone."
  status: watching
  likelihood: 2
  impact: 3
  score: 6
  ranking: medium
  actors:
  - actor: outsider-intentional
    how: "text rendered on a page tells the seat to vote green"
    likelihood: 2
    impact: 3
    mitigated_likelihood: 2   # worst mode: single seat; panel residual 1 x 3
    mitigated_impact: 3
  introduced_by: T-5309       # PARTLY NEW: the codex route
  exists_anyway: true         # image-borne injection already reached the other seats
  mitigation_task: T-YYYY
  created: 2026-11-21
- id: R-NEW-3
  type: risk
  title: "Attached image counted as viewed although codex did not examine it"
  description: "lib/vote_checker.py treats an image attached at launch as viewed. Codex can still answer from the text (the G-136 pattern) and its green now counts on render criteria: alone in a single-seat run (rung 1/3), with one other vendor in a rung-5 panel closing on two."
  status: watching
  likelihood: 3
  impact: 3
  score: 9
  ranking: medium
  actors:
  - actor: own-agent-unintentional
    how: "codex has the image in its prompt but votes green on a broken render without examining it"
    likelihood: 3
    impact: 3
    mitigated_likelihood: 3   # worst mode: single seat; panel residual 2 x 3 (two-vendor close)
    mitigated_impact: 3
  - actor: provider-host
    how: "provider silently downscales or drops -i images"
    likelihood: 2
    impact: 3
    mitigated_likelihood: 2   # worst mode: single seat; panel residual 1 x 3
    mitigated_impact: 3
  introduced_by: T-5309
  exists_anyway: false
  mitigation_task: T-YYYY
  created: 2026-11-21
- id: R-NEW-4
  type: risk
  title: "Unattached cited image counted as viewed (cap or stem match)"
  description: "image_viewed() stem-matches cited names against attached names, so an image over the 20-image cap, or one whose name shares a stem prefix with an attached one, is marked viewed."
  status: watching
  likelihood: 2
  impact: 3
  score: 6
  ranking: medium
  actors:
  - actor: own-agent-unintentional
    how: "brief cites 21+ screenshots or two names sharing a stem prefix"
    likelihood: 2
    impact: 3
  introduced_by: T-5309
  exists_anyway: true
  mitigation_task: T-5324
  created: 2026-11-21
```

Mitigation task proposals (arc `risk`):

- R-NEW-1 — **"Screenshot sensitivity gate for outside review seats"**: before attaching, refuse or flag screenshots of pages listed as able to show secrets (settings, config, credentials), and record the decision in `attached-images.json`.
- R-NEW-2 — **"Image-borne instruction check in render verdicts"**: add a judge-brief line telling seats that text inside screenshots is data, and have vote_checker flag a verdict whose rationale quotes instruction-like text found only in an image.
- R-NEW-3 — **"Spot-check codex render greens against the images"**: sample codex greens on render criteria weekly, re-judge them with a seat whose log shows a view, and report the disagreement rate in `fw audit`.
- R-NEW-4 — **"Attached-as-viewed by content hash only"**: in lib/vote_checker.py, stop stem-matching cited images against attached names and treat every `not_attached` entry as not viewed; add tests for the 21-image and shared-stem cases.
