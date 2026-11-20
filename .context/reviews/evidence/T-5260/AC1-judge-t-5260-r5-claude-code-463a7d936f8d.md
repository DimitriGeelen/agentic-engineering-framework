# T-5260 Human AC#1 — evidence report (panel seat claude-code, dispatch judge-t-5260-r5-claude-code-463a7d936f8d)

Revision reviewed: 44a71ffc92a09410983d53bd8bbcf537763f557b
Criterion: framework pages (/ and /cron) are unchanged by the project-page loader: normal header,
menu and footer, no extra or missing menu items, no layout breaks at 1024, 1440 and 1920 px.

Cannot reproduce: I did not re-run the app or the capture; I judged the supplied images, and read
the task's diff to check what "as before" rests on.

## What the images show

| image | width | header | menu items | layout |
|---|---|---|---|---|
| home-header@1024 | 1024 | logo + Watchtower, normal | Work, Knowledge, Architecture, Govern, Docs, search, settings, theme toggle | no clipping or overlap; the theme toggle sits on a second header row |
| home-header@1440 | 1440 | normal | same eight controls, one row | ok |
| home-header@1920 | 1920 | normal | same eight controls, one row | ok |
| cron-header@1024 | 1024 | normal, Govern marked active | same eight controls | same second-row theme toggle as / |
| cron-header@1440 | 1440 | normal, Govern active | same, one row | ok |
| cron-header@1920 | 1920 | normal, Govern active | same, one row | ok |
| 01-root (1280, top 900 px only) | 1280 | normal, status strip below it | same | page title, focus, arcs list and tokens row render without breaks |
| 02-cron (1280, full page 7600 px) | 1280 | normal, status strip, breadcrumb Govern > Cron | same | jobs table intact to the end; footer rule, "Watchtower v1.8.16-be.60-141-g722718588 — Agentic Engineering Framework" and the framework-bug hint, centred and unclipped |
| project-page@1024/1440/1920 (fixture, 127.0.0.1:3977/hosts) | all three | same header as the framework pages, incl. the same second-row toggle at 1024 | same eight controls, nothing added | status strip, table and footer intact at each width |

No menu item is extra or missing on either page at any width: the five menu entries and three
icons are identical across all six header crops and both full screenshots. The capturing browser
recorded no console or page errors on / or /cron.

## "As before"

No pre-loader screenshot was supplied, so I checked the claim in the code:
- the build commit 722718588 changes no template and no stylesheet; in web/ it adds
  project_extensions.py and 12 lines in app.py that register project pages after the framework's;
- this project has no .framework-extensions.yaml, so the loader registers nothing here;
- between the commit before the build and the reviewed revision, web/templates and web/static
  differ only in two nav-macro lines of base.html (T-5261: a menu entry may be a path), which do
  not alter markup for the framework's endpoint entries.
So the theme toggle wrapping at 1024 is the framework header's own behaviour at that width, not
something the loader introduced; it is identical on /, /cron and the fixture page.

## Limits of what I saw

- The footer of / is in no image (the page is 55,267 px tall; the screenshot is its top). The
  framework footer is seen on /cron at 1280 px and, from the same base.html block, on the fixture
  page at 1024, 1440 and 1920 px. It is one block in base.html (footer.site-footer, centred text,
  no width-dependent rule) that the task did not touch, which is what I rest the / footer on.
- The body of / below the first 900 px is not shown at any width.

## Verdict: green
