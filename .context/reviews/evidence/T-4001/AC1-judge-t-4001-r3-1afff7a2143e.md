# T-4001 Human AC#1 — Reviewer PASS/FAIL badges read green/red (light + dark)

Reviewer: judge seat (rung-3-termlink-single-reviewer). Revision: d514fe6afea739c5b90c4208e05302977f1171af.

## What I checked
- Screenshot `01-arcs.png` (copy in this directory): it is the `/arcs` INDEX page (value/cost
  matrix + kanban), light mode only. It shows no arc detail page, no "Proposed scoped drivers"
  section and no "Reviewer: PASS"/"Reviewer: FAIL" badge. No dark-mode capture was supplied.
- Code at the reviewed revision, `web/templates/arc_detail.html:445-454`:
  PASS badge = `background: color-mix(in srgb, var(--wt-success) 22%, transparent); border: 1px solid var(--wt-success); color: var(--wt-text, var(--pico-color))`;
  FAIL badge = same with `--wt-danger`.
  `web/static/css/foundations.css` defines `--wt-success` (green family) and `--wt-danger`
  (red family) for every palette in light and dark.
- Note: T-4001's own commit (b5476ec48) set solid `--wt-success/--wt-danger` with `#fff` text;
  later T-4009 (95eafd51c) changed it to a 22% tint with theme text colour. So at the reviewed
  revision the AC's "white text" expectation no longer literally applies — the text is the theme
  text colour on a light green/red tint.

## Finding
Cannot evaluate: the AC is a visual judgement (green/red legibility in light AND dark mode) and
no rendered capture of the badges was provided. Statically the tokens are green/red in all
palettes, but I did not see the badges, so I do not vote.
