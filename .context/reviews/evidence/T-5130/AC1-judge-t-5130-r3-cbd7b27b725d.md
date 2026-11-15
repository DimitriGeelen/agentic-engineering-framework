# T-5130 Human AC#1 — evidence report (judge-t-5130-r3-cbd7b27b725d)

Reviewed revision: 9ab0e6f94311fe60c99f709b4a408db902412f20. Rung: rung-3-termlink-single-reviewer.
Verdict: **not-evaluated** (the brief's Visual Verification gate does not pass; a render criterion may not be returned green on it).

## Why not-evaluated

The dispatch brief states: "`## Visual Verification` has no checklist table with `state` and `control` columns" and forbids green for a render criterion.

Cause, checked in the source: `agents/context/visual_checklist.py` `parse_table()` reads only the FIRST pipe table in the section and
returns nothing if that table's header lacks `state`/`control`. In the task file (line 316 onward) the first table is the click-through table
(`| step | from → to | result | page check | console errors |`); the checklist table
(`| state | control | 1024 | 1440 | 1920 | note |`, rows bvp / terminal / tasks, all ok) is the SECOND table, so the gate never reaches it.
The per-width shots it needs do exist: `.context/visual/T-5130/{bvp,terminal,tasks}@{1024,1440,1920}.png`.

## What I did observe (input for the next reviewer, not a vote)

1. Change is present: `web/templates/base.html` lines 1004-1027, an `htmx:beforeSwap` handler that turns a GET navigation into #content
   into a full load when the response carries a `<script src>` this document has not loaded.
2. Dispatch screenshots (direct loads, copies in this directory): 01-fabric, 02-bvp (scatter drawn at page bottom), 03-terminal
   ("Connected", Bash-1 running), 04-tasks (board, top of page only), 05-docs-generated, 06-settings, 07-settings-models
   (an unstyled model-name list: a fragment endpoint, not part of this criterion), 08-settings-appearance. Capture notes: 0 console errors on all 8.
   These are direct loads, so on their own they do not exercise the criterion (in-app navigation).
3. My own in-app click-through, Playwright/Chromium 1440x900 against http://192.168.10.107:3000, real clicks on the top-nav links,
   a `window` marker set before each click to tell a full load from an htmx swap:

   | step | click | full load? | page check | console/page errors |
   |------|-------|-----------|------------|---------------------|
   | 1 | /fabric → nav → /bvp | yes | `typeof d3` = object; `#scatter-quadrant` 900x520 with 273 circles, all non-zero size; site nav has 37 links | 0 |
   | 2 | /bvp → nav → /terminal | yes | `typeof io` = function; 1 xterm; "Connected", "Bash-1 (running)", shell prompt drawn | 0 |
   | 3 | /terminal → nav → /tasks | no (htmx swap, marker kept) | h1 "Tasks", board columns populated | 0 |

   Shots: own-click-1-bvp-scatter, own-click-1-bvp-top, own-click-2-terminal, own-click-3-tasks (suffix -judge-t-5130-r3-cbd7b27b725d.png).
   This agrees with the producer's `.context/visual/T-5130/clickthrough.json` (full load, full load, swap; no errors, only font-preload warnings).

Nothing I saw contradicts the Expected clause. The verdict is withheld only because the visual-evidence gate named in the brief fails.
