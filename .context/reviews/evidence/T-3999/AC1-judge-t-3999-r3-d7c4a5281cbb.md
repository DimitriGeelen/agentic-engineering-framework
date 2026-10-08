# T-3999 Human AC#1: arcs matrix reads clearly in light and dark mode
Reviewer: judge-t-3999-r3-d7c4a5281cbb (rung-3-termlink-single-reviewer). Revision: 95eafd51c83cd3e124670fe89ef1cc69024630f2

## What I did
- Read the dispatch screenshot 01-arcs.png (light, full page): copied as 01-arcs-judge-t-3999-r3-d7c4a5281cbb.png.
- Drove http://192.168.10.107:3000/arcs myself with headless Chromium (Playwright, 1400x1000).
  I confirmed the live server renders 95eafd51c's matrix: the served HTML has the `--am-ink` and `am-leader` rules and the leader lines that T-4009 added.
  The footer still says v1.8.7-24-ge8ce912ac because that is the server's start-up describe string; the template content matches the reviewed revision.
- Screenshot of the light matrix section: AC1-light-judge-t-3999-r3-d7c4a5281cbb.png. Hovering arc-020 makes its ring thicker and its label bold (AC1-hover-light-judge-t-3999-r3-d7c4a5281cbb.png).
- Clicked the theme-toggle (moon) button; data-theme became dark. Screenshots: AC1-dark-judge-t-3999-r3-d7c4a5281cbb.png and AC1-hover-dark-judge-t-3999-r3-d7c4a5281cbb.png.
- Did an elementFromPoint hit test at the centre of all 20 dots. Every dot's topmost element is its own <a href="/arcs/<slug>">, so no coincident dot steals another's click.
- Clicked the dot for dispatch-safety. It went to /arcs/dispatch-safety, whose h1 is "Dispatch safety: Worker uncertainty handling" (AC1-click-dest-judge-t-3999-r3-d7c4a5281cbb.png).
- Hover tooltip: every dot has an SVG <title>, e.g. "arc-020 — Cross-agent identity & self-healing circuits | value 0.2815 · cost 3.3 · in-progress · proposed".

## Computed colours
| element | light | dark |
|---|---|---|
| plot bg | rgb(255,255,255) | rgb(28,28,22) |
| dot stroke / labels / leaders | rgb(26,26,23) (~17:1) | rgb(232,231,223) (~14:1) |
| quadrant labels, ticks, median lines | rgb(107,104,94) (~5.8:1) | rgb(160,156,142) (~6.8:1) |
All text is above WCAG AA 4.5:1 in both themes. The dark-mode dot and label ink is no longer the link accent; the earlier finding is fixed.

## Result
Both themes: dots are visible and labelled, quadrant lines and labels are readable, the hover shows a tooltip plus emphasis, and a click opens that arc. Met.

## Cosmetic notes (not blocking)
- The dashed value-median line passes through the "arc-005" and "arc-014" labels, which sit on the median. The labels are still legible in both themes.
- The arc-005/arc-006 and arc-010/arc-001 pairs are tight but separated by leaders, and each dot is clickable on its own.
