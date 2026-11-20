# T-5260 Human AC#1: framework pages unchanged by the project-page loader

Seat: rung-5-panel:claude-code. Revision reviewed: e7bd29d2aaf8d211bb70846d22785c8b45bdd038.
Judged from the supplied images (cannot reproduce: I did not re-run the app or the capture, as the brief instructs).

## What I opened (all 17 images, copies in this directory)
- 01-root.png (top of `/`, 1280 px; page is 55,267 px tall so viewport only), 02-cron.png (full `/cron`, 1280 px)
- home-header, cron-header, home-footer, cron-footer at 1024 / 1440 / 1920
- project-page at 1024 / 1440 / 1920 (fixture; context only, judged under T-5261)
- Comparison image named in the task's checklist note: `.context/visual/T-5241/no-questions@1024.png`

## Findings, control by control

| control | 1024 | 1440 | 1920 |
|---|---|---|---|
| logo + "Watchtower" wordmark (/ and /cron) | visible, unclipped | visible, unclipped | visible, unclipped |
| menu: Work, Knowledge, Architecture, Govern, Docs, search, settings, theme toggle | all present, no overlap; theme toggle sits on a second row | all on one row | all on one row |
| extra / missing menu items | none | none | none |
| /cron active state (Govern highlighted) | present | present | present |
| footer: version line + "Found a framework bug? fw upstream report ..." | centred, unclipped, both pages | same | same |

- 01-root.png: header, status strip (T-332 / Session / Audit / items need attention / project name), page title, focus card, arcs list, tokens strip all render normally; no overlap or clipping.
- 02-cron.png: header, breadcrumb, "Scheduled Jobs" table through to "How this works" and footer; columns aligned, no break.
- Menu is exactly the five framework items plus the three icons on both pages: no project-page entry was added (this project registers none) and none is missing.
- Capture notes: no console or page errors on `/` or `/cron`.

## The 1024 px second header row (checked, not taken on trust)
At 1024 px the theme toggle wraps under the menu on both pages. Is it caused by this task?
- `.context/visual/T-5241/no-questions@1024.png` has mtime 2026-11-19 23:52:18; its footer reads
  `v1.8.16-be.60-13-g47853f73e`. The T-5260 loader commit 722718588 is dated 2026-11-20 00:21:48 and the
  current shots read `v1.8.16-be.60-141-g722718588`. So that image was served by a build before the loader.
- It shows the identical wrap (toggle on a second row under "Work", same header height).
- `git show --stat 722718588` touches web/app.py, web/project_extensions.py, lib/extensions.py, bin/fw, tests
  and fixtures: no base template or stylesheet.
So the wrap predates T-5260: "renders as before" holds at 1024 too.

## Not seen
- The lower part of `/` between the first viewport and the footer (01-root is viewport only); the footer crop covers the end of the page.
- Dropdown-open states (not asked by the criterion).

## Verdict
green. Both framework pages show the normal header, menu and footer at 1024, 1440 and 1920 px, with no extra
or missing menu items and no layout change attributable to the loader.

Observation outside this criterion: the framework header wraps the theme toggle to a second row at 1024 px on
every page; it predates this task and would be its own task if the operator wants it fixed.
