# T-5130 Human AC#1 — In-app navigation to the BVP and terminal pages

Reviewer: reviewer-judge-t-5130-r3-868cee85c2e5 (rung-3-termlink-single-reviewer), revision 98967f6b3ac76f65ac92f8bb3d3acdb542ab8f91

## Verdict: not-evaluated

## Why I could not evaluate

1. The task file (.tasks/active/T-5130-htmx-boosted-navigation-runs-a-pages-inl.md) has no
   `## Visual Verification` section (headings present: Context, Acceptance Criteria, Verification,
   RCA, Evolution, Recommendation, Decisions, Decision, Updates, Reviewer Verdict). The Visual
   Verification evidence therefore does not pass, and a render criterion may not be returned green.
2. The criterion is about IN-APP navigation (/fabric -> nav -> /bvp -> nav -> /terminal -> /tasks,
   first visit, no blank area; full load for the two pages, instant swap for ordinary ones). The
   screenshots I was given are one capture per URL; nothing in them or in capture-notes.json shows
   that the pages were reached by clicking the top navigation. A direct load of /bvp and /terminal
   worked before T-5130 too (the defect was only on the htmx-boosted path), so these captures do
   not show the behaviour the criterion asks for. I did not see the navigation sequence.

## What I did see (input for the next reviewer, not a verdict)

- 02-bvp: direct capture of /bvp; the quadrant scatter is drawn at the bottom of the page (axes, points), no blank area. No console errors recorded.
- 03-terminal: /terminal shows "Connected", tab Bash-1 (running), a terminal pane with a cursor. No console errors recorded.
- 01-fabric, 04-tasks (top of page only; page is 39,827 px), 05-docs-generated, 06-settings, 08-settings-appearance: render normally.
- 07-settings-models: an unstyled plain list of model names without the site chrome. Looks like an htmx fragment endpoint opened directly; not part of this criterion, noted only.
- Code: web/templates/base.html lines 1004-1027 hold the T-5130 `htmx:beforeSwap` handler: for a GET swap into #content whose response has a `<script src>` not yet in document.scripts, it sets shouldSwap=false and does window.location.assign(responseURL). By reading, this matches the described design (full load for /bvp and /terminal, swap elsewhere). Reading the code is not seeing the navigation.

## What is needed

- Add a `## Visual Verification` section to the task with the checklist table and `fw ux shots` at every configured width.
- Evidence of the click-through itself: start on /fabric, click nav to /bvp, then to /terminal, then to /tasks, with a screenshot after each click and the console log (no "d3 is not defined" / "io is not defined"), plus a sign that /bvp and /terminal did a full load and /tasks a swap.

## Screenshots cited (copies)
- .context/reviews/evidence/T-5130/01-fabric-judge-t-5130-r3-868cee85c2e5.png
- .context/reviews/evidence/T-5130/02-bvp-judge-t-5130-r3-868cee85c2e5.png
- .context/reviews/evidence/T-5130/03-terminal-judge-t-5130-r3-868cee85c2e5.png
- .context/reviews/evidence/T-5130/04-tasks-judge-t-5130-r3-868cee85c2e5.png
- .context/reviews/evidence/T-5130/05-docs-generated-judge-t-5130-r3-868cee85c2e5.png
- .context/reviews/evidence/T-5130/06-settings-judge-t-5130-r3-868cee85c2e5.png
- .context/reviews/evidence/T-5130/07-settings-models-judge-t-5130-r3-868cee85c2e5.png
- .context/reviews/evidence/T-5130/08-settings-appearance-judge-t-5130-r3-868cee85c2e5.png
