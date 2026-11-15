# T-5140 Human AC#1 — evidence report (reviewer judge-t-5140-r3-2d7cff68015b)

Revision reviewed: 18e9104653c35b96d27beb2906d2c7c39b734191 (HEAD at review time matched).
Criterion: the four pages (/bvp, /reviewer/audit, /reviewer/overrides, /escalation-drift) show the
full site menu (Work, Knowledge, Architecture, Govern) and the menus lead to their pages, the same as on /fabric.

## What I checked

1. **Screenshots supplied (read all 17).** 01-bvp, 02-reviewer-audit, 03-reviewer-overrides,
   04-escalation-drift each show the nav bar with Work / Knowledge / Architecture / Govern, Docs, search,
   settings and theme toggle — the same bar as 05-fabric. The 12 width shots (bvp, reviewer-audit,
   reviewer-overrides, escalation-drift at 1024/1440/1920) show all four groups visible, unclipped and
   not overlapping at every width. Govern is marked active on reviewer-audit, reviewer-overrides and
   escalation-drift; Work on bvp. For the tall bvp shots I cropped the top 500px to read the nav legibly.
   At 1024 the theme toggle wraps to a second nav line (as the task's checklist notes); I measured the
   live nav height at 1024 on /fabric and /bvp to confirm it is the shared layout (see output below).
2. **Live full load (curl, no in-app click)** of all five pages: HTTP 200. The <nav> of each of the four
   pages has 37 links, and the link list is identical, in order, to the <nav> of /fabric
   (no missing, no extra).
3. **Every menu target resolves:** all 37 nav hrefs fetched live: 36 return 200, /designer returns 302
   to /designer/app?browse=1 (its normal redirect, same link as on /fabric).
4. **Real browser click-through (headless Chromium, 1440 wide, fresh context per run = full load):**
   on each of /bvp, /reviewer/audit, /reviewer/overrides, /escalation-drift and /fabric I clicked each
   of the four menu triggers, confirmed the dropdown entry became visible, clicked one entry
   (Work→Tasks, Knowledge→Learnings, Architecture→Fabric, Govern→Concerns /risks) and confirmed the URL
   changed to the target, the target page's h1 rendered (Tasks / Learnings / Component Fabric / Concerns)
   and the destination still had all four menus. 20/20 runs passed with zero console or page errors;
   behaviour on the four pages was identical to /fabric (same visible-entry counts per menu: 11/8/9/21).
   live-bvp-work-menu-open shows the Work menu open on /bvp (Tasks, Arcs, BVP, Inception, Assumptions,
   Timeline, Prompts).
5. **Code:** web/app.py has the context processor `_site_nav_context` returning nav_groups, nav_items
   and nav_full_load.

## Not covered / observations (outside the criterion)

- I clicked one entry per menu per page in the browser, not all entries; the remaining entries were
  verified by identical markup to /fabric plus HTTP status of every href.
- The four pages still lack the status strip and breadcrumb that /fabric has; the task records this as a
  known residual and the criterion is about the menus only.
- /reviewer/overrides: the "Active Overrides" table is cut off by the "Recent feedback-stream events"
  heading (a fixed-height scroll area) and its header says "(99)" beside "Active: 17 Expired: 82".
  Page-body matters, not part of this change or criterion.

## Verdict: green
