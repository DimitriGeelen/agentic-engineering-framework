# T-3557 — Independent render review, 2026-09-29

(Staged here because the PreToolUse task gate refused a write to `docs/reports/`. Focus was WM-002, and the workflow-management fence blocks non-`.context` writes. Move it to `docs/reports/T-3557-render-review-2026-09-29.md` under T-3557 focus.)

Reviewer: an independent agent reviewer, working under the operator's ruling that low-risk render checks go to an agent. I did not build any of this.
Sources checked:
- the screenshots `approvals-arc-closure.png` and `config-sidecar-row.png`
- the live HTML from `curl http://192.168.10.107:3002/approvals/content` and `/config`
- the template `web/templates/_approvals_content.html:267-370`
- the CSS in `web/templates/approvals.html:51-56`

## Finding that affects both arc criteria: the anchor link cannot be seen

`.headline-mechanic-box` sets `background: var(--pico-primary-background)`. That colour is the solid dark-olive fill used for primary buttons, not a light tint, even though the T-2111 comment calls it "tinted". Links inside the box use the primary link colour, which is almost the same shade. The live HTML contains `<a href="/tasks/T-2718">T-2718</a>` inside the "Not yet reviewable" box. In the screenshot that link is not visible at all. The sentence therefore reads "Write the advisory on  ( ## Recommendation — verdict…": a gap, a stray "(", and a white `<code>` chip. That looks broken, and it hides the one thing the operator needs to click on a blocked card.

This problem was not introduced by T-3552 or T-3553. It comes from the T-2111 box styling combined with the link that T-2986 added. It is still the most visible defect in the section.

A second, smaller defect in the same box: `blocked_reason` is plain text that contains Markdown backticks. The page shows a literal `` `## Recommendation` `` and then shows the same words again as a real `<code>` chip one line later.

## T-3552 — Arc Closure section with the shorter list

**VERDICT: AMBER**

**WHAT I CHECKED**
- The live HTML has exactly 2 cards: `onboarding-shape-detection` and `readme-first-run`. The stat tile shows 2.
- `onboarding-shape-detection` has `data-verdict=""`. It shows a BLOCKED badge instead of a verdict badge, no Approve / Override button, and a blocked reason saying anchor T-2718 has no `## Recommendation`. This is correct.
- `readme-first-run` shows a GO badge, with the Review and Approve / Override buttons. This is correct.
- The section reads as a two-item queue with clear per-card state, not as an error or as breakage. The criterion's main claim holds.

**GUIDANCE (why amber, not green)**
1. Fix the invisible anchor link. Either give `.headline-mechanic-box` a real tint, for example `color-mix(in srgb, var(--pico-primary) 12%, transparent)`, or give links inside the box a contrasting colour. File this as its own bug task: it is a styling defect, not part of T-3552's scope.
2. The heading and tooltips still describe the old rule:
   - The heading says "Arcs ready for review", but one of the two cards says "Not yet reviewable". Rename it to something like "Arc closure queue".
   - The BLOCKED badge tooltip says "Meets the completion threshold", which is the old ≥80% wording. Change it to something like "Meets L1/L2; anchor advisory missing".
   - The stat-tile breakdown says "Close-ready arcs".
   - The template comment at line 267 still says "≥80% complete".
3. A line explaining why arcs left the list is not needed on the page. The subtitle already names the L1/L2 predicate, and a queue should not describe items it no longer contains.
4. Strip the backticks from `blocked_reason`, or render them as code, so `## Recommendation` does not appear twice in two different styles.

## T-3553 — The demo-evidence line on each card

**VERDICT: AMBER**

**WHAT I CHECKED**
- Both cards have a "Demo evidence:" box with inline `border-left-color: var(--wt-warn)` and the text "the arc records no demo_evidence — …". This is confirmed in the live HTML and the screenshot. On the dark-olive background the amber stripe is only faintly different from the default stripe: it is present, but not an obvious signal.
- The subtitle reads "nothing unestimated (L1) and no high-value work left (L2); demo evidence and anchor advisory shown per arc". The phrase "completion ≥80%" is gone. This is correct.
- On the blocked card, "Not yet reviewable." and "Demo evidence:" are two labelled boxes. They state two distinct reasons: the missing anchor advisory and the missing captured demo artefact. They do not read as the same complaint twice. The criterion holds.

**GUIDANCE**
1. Keep the two boxes separate. Do not merge them into one "what's missing" block: they have different remedies (write the Recommendation, or record demo_evidence) and different owners.
2. The actual ambiguity is a third box. Each card also has an unlabelled headline-mechanic box with identical styling. On the blocked card that makes three identical olive boxes, and the unlabelled one reads like a third complaint. Add a label such as "Headline mechanic:" or give that box a neutral style, so warnings look different from description.
3. Tidy up the demo-evidence summary text:
   - it has no final full stop
   - it exposes internal identifiers (`demo_evidence`, `headline_mechanic`, `§ACD`)
   - "that question currently has no subject" is opaque to an operator

   Suggested text: "none recorded — closure asks for a captured artefact showing the headline mechanic working."
4. Once the background is a light tint (T-3552 guidance point 1), the `--wt-warn` stripe will read as a warning on its own.

## T-3544 — FW_SIDECAR_CONSULT_WARN_HOURS row on /config

**VERDICT: GREEN**

**WHAT I CHECKED**
- The live `/config` row has current value **4**, default `4`, and the `default` badge. Its `<td>` structure matches its neighbours (FW_RETIRE_WHEN_ADVISORY, FW_DELEGATION_SURFACE_WARN), and it looks the same in the screenshot.
- The description reads: "…far below the sibling dm: rail's 24 because a consult is a peer blocked on an answer; T-3544 / OBS-567". It explains why the value is lower than 24 without needing the task file.

**GUIDANCE**
- Acceptable as is.
- Optional polish: "the sibling dm: rail's 24" is awkward because of the colon. "the sibling DM rail's 24h" would be clearer.
- The narrow, character-wrapped key column is page-wide and not caused by this row. It is out of scope here.

---

## Re-review after T-3571 (fresh independent reviewer, new screenshot approvals-arc-closure-v2.png)

**T-3552: GREEN.** All four guidance points verified on the live page, not taken from the author's claim.
- Anchor link: T-2718 is visible, green and underlined on the 12% color-mix tint.
- Wording: heading "Arc closure queue"; BLOCKED tooltip "Meets L1 and L2, but the anchor advisory is missing"; stat tile "Meeting L1 + L2"; the template comment no longer says ≥80%.
- Cards: onboarding-shape-detection shows BLOCKED with its reason; readme-first-run shows GO.
- Backticks: gone.

**T-3553: GREEN.** Both cards have a "Demo evidence:" box with operator-readable text ending in a full stop. The amber stripe now reads as a warning. The third box is labelled "Headline mechanic:", so a blocked card shows two distinct warnings plus one description.

**Optional, non-blocking:**
- "( ## Recommendation" chip spacing is slightly redundant with the sentence.
- The headline-mechanic box is still italic.
- The headline text has no full stop (that comes from the arc YAML).
- Dark theme not checked.
