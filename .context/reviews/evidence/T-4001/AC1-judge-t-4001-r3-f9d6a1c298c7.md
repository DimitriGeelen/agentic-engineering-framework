# T-4001 Human AC#1: Reviewer PASS/FAIL badges read green/red (reviewer judge-t-4001-r3-f9d6a1c298c7)

Revision reviewed: 54c581fc2aed3295a4f4f2116636c3df3bd4bf25

## Light mode (screenshots supplied by the judge harness, copied here)
- 01-arcs-value-prioritisation-judge-t-4001-r3-f9d6a1c298c7.png: in "Proposed scoped drivers", Sovereignty Preservation shows "Reviewer: PASS"
  with a pale green tint and a green border. Adoption Friction shows "Reviewer: FAIL — scorable" with a pale red
  tint and a red border (checked in a zoomed crop). The text is dark and readable.
- 02-arcs-parallel-execution-aef-judge-t-4001-r3-f9d6a1c298c7.png: Disjoint Write Set Discipline and Wire Evidence Falsifiability both show
  "Reviewer: PASS" with a green tint, a green border and readable dark text (checked in a zoomed crop).
- 03-arcs-judge-t-4001-r3-f9d6a1c298c7.png: the /arcs index. It has no reviewer badges, so it is cited only as a required page.

## Dark mode (rendered by me; the supplied screenshots are light-only)
Rendered with headless Chromium + Playwright against the live Watchtower on localhost:3000. I checked that it
serves the reviewed template, because its HTML contains the color-mix(...var(--wt-danger) 22%...) badge style
from web/templates/arc_detail.html:446-454. I set data-theme="dark"; the palette was "stone".
Computed styles:
- PASS: bg rgba(90,138,58,0.22), border rgb(90,138,58) (green), text rgb(232,231,223) (light)
- FAIL: bg rgba(164,74,45,0.22), border rgb(164,74,45) (red/rust), text rgb(232,231,223) (light)
Header crops:
- dark-value-prioritisation-pass-judge-t-4001-r3-f9d6a1c298c7.png: green-tinted PASS badge, readable
- dark-value-prioritisation-fail-judge-t-4001-r3-f9d6a1c298c7.png: red-tinted FAIL badge with a red border, readable
- dark-parallel-execution-pass-judge-t-4001-r3-f9d6a1c298c7.png: green-tinted PASS badge, readable

## Source
arc_detail.html sets the text colour to var(--wt-text). foundations.css defines --wt-text for every light and dark
palette, so the text contrasts with the background in both themes, and the tint and border follow
--wt-success / --wt-danger.

## Note (not blocking)
In dark mode the FAIL border (#a44a2d on the stone palette) is a muted rust-red rather than a bright red. It still
reads clearly as red/danger, and differently from the green PASS badge.

Verdict: green
