# T-5130 Human AC#1: in-app navigation to the BVP and terminal pages
Reviewer: reviewer-judge-t-5130-r3-bfc840345be2 (rung-3-termlink-single-reviewer), revision 0660c8e83a4312556475cc44c28c7b2cb2746fc0, 2026-11-15

## Verdict: green

## What I did myself (not taken from the producer's evidence)
Headless Chromium (Playwright, 1440x900) against the live Watchtower at http://192.168.10.107:3000, following the criterion's steps by clicking the top-navigation links. A marker on `window` set before each click separates a full load (marker gone) from an htmx swap (marker kept); document/xhr requests and console/page errors were recorded.

| step | request seen | marker | result |
|------|--------------|--------|--------|
| /fabric -> nav "BVP" | 1 document request to /bvp, no xhr | gone (full load) | scatter SVG 900x520 with 275 marks drawn on first visit (own-1-bvp-scatter), weight sliders and full site nav (own-1-bvp-top) |
| /bvp -> nav "Terminal" | 1 document request to /terminal, no xhr | gone (full load) | xterm pane 1198x689, "Connected", Bash-1 (running), shell prompt text present (own-2-terminal) |
| /terminal -> nav "Tasks" | 1 xhr with HX-Request: true, no document request | kept (swap) | Tasks board, heading "Tasks", cards drawn (own-3-tasks) |

Console and page errors across the whole walk: 0. No blank area on either page.

The nav links to /bvp and /terminal carry `hx-boost="false"` (T-5146, base.html:539-540), so the menu path is one direct load. The T-5130 `htmx:beforeSwap` handler (base.html:1005-1028) is the fallback for any other boosted link. I exercised it separately: on /tasks I added a boosted link (hx-target #content) to /bvp, then /terminal, and clicked it. Both times: one xhr then one document request, marker gone, `d3` object with 277 circles drawn / `io` function with xterm rows present, 0 console errors. The handler works on the live server.

## Supplied screenshots, read one by one
- 01-fabric: Component Fabric, full nav, subsystem cards and component table drawn.
- 02-bvp: sliders, pending proposals, add-driver form, scatter at the bottom drawn, full nav.
- 03-terminal: nav, "Connected", Bash-1 (running), terminal pane with cursor.
- 04-tasks: nav, board with five columns, cards drawn (top of page only, 40,159 px page).
- 05-docs-generated, 06-settings, 08-settings-appearance: render normally with full nav.
- 07-settings-models: an unstyled list of model names with no site chrome. /settings/models is the fragment the Settings page loads under "Available models", not a page a user navigates to; not affected by this task.

## Visual Verification checklist, control by control
| state | control | 1024 | 1440 | 1920 |
|-------|---------|------|------|------|
| bvp | scatter, weight sliders, site nav | ok | ok | ok |
| terminal | terminal pane, Connected | ok | ok | ok |
| tasks | board (full-page) | ok, see note | ok | ok |
| tasks-viewport | board cards in viewport | ok | ok | ok |

Notes:
- bvp@1024/1440/1920: scatter drawn with axes, quadrant labels and marks (checked on bottom crops at 1024 and 1920), sliders and nav visible, nothing clipped or overlapping.
- tasks@1024: cards below the header are drawn as empty outlines in the full-page capture; tasks-viewport@1024 shows the same cards drawn with id, status and BVP. That matches the task's note (content-visibility: auto skips off-screen cards in a full-page capture). tasks@1440 and tasks@1920 show drawn cards.
- At 1024 the theme toggle wraps to a second nav row and card selects are cramped. Both are existing layout, present on every page at that width, not from this change.

## Outside the criterion (not counted)
- The criterion's "If not" line names only the T-5130 handler. For the menu path the operative change is now the T-5146 `hx-boost="false"` on the link, with the handler as fallback. The Expected clause is met as written, so this does not change the verdict.
- After the swap to /tasks the page is scrolled so #content is at the top (nav above the fold) in own-3-tasks; my script had scrolled /terminal before clicking. Not judged.
