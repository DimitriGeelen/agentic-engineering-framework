# T-5260 Human AC#1 — evidence report (seat claude-code, dispatch judge-t-5260-r5-claude-code-294d2048fb2f)

Criterion: a project page sits in Watchtower like a framework page — normal header, menu and
footer; own content renders without layout breaks at 1024, 1440 and 1920 px.

## What I did
- Opened and viewed all three supplied screenshots (copies in this directory):
  - project-page@1024-judge-t-5260-r5-claude-code-294d2048fb2f.png (sha256 714272df… matches project-page.capture.json)
  - project-page@1440-judge-t-5260-r5-claude-code-294d2048fb2f.png (sha256 2692683c… matches)
  - project-page@1920-judge-t-5260-r5-claude-code-294d2048fb2f.png (sha256 60a3a958… matches)
- Cannot reproduce: I did not re-run the fixture server (127.0.0.1:3977) or the capture; I judged
  the supplied images, as the brief instructs. The reviewer-side page capture failed; the
  images in .context/visual/T-5260/ are what the criterion's Step 1 names and I saw all three.
- Cross-checked the producer's note about the 1024 header against a framework page: cropped the
  top 320 px of .context/visual/T-5261/menu-no-extension@1024.png (real Watchtower, /cron) to
  framework-cron-header@1024-judge-t-5260-r5-claude-code-294d2048fb2f.png.

## What the images show (control by control)
| control | 1024 | 1440 | 1920 |
|---|---|---|---|
| header: Watchtower logo + wordmark | ok | ok | ok |
| menu: Work, Knowledge, Architecture, Govern, Docs, search, settings, theme toggle | ok (toggle on a 2nd row) | ok | ok |
| status strip (focus, session, audit, attention, project name right-aligned) | ok | ok | ok |
| project content: "Hosts" heading, marker line, 3-column table with 3 rows | ok | ok | ok |
| footer: rule, "Watchtower dev — t5260 fixture", framework-bug hint | ok | ok | ok |

No clipping, overlap or horizontal overflow at any width. The content column is centred and
grows with the viewport (about 950 / 1200 / 1450 px wide); the table columns stay aligned and the
footer rule matches the content width.

## The one thing to note: 1024 px header
At 1024 the theme toggle wraps to a second header row, so the header is about 165 px tall
instead of 103 px. The framework's own /cron page at 1024 shows the identical wrap (same toggle
position, same header height, status strip at the same y). So this is the framework header's
behaviour at that width, not something the project page introduces — the project page matches
a framework page there too. It is a pre-existing framework header wart, outside this criterion.

## Limits
- The fixture is a second Watchtower with PROJECT_ROOT=/tmp/t5260-fixture, not the live instance;
  the criterion allows the fixture. The status strip values ("unknown") are fixture data.
- Static screenshots only: no dropdown-open or interaction state was judged (not asked).

## Verdict: not-evaluated (recorded) — the images themselves show the criterion met

I attempted to record green. The ledger refused it: `REFUSED: no required page was recorded for
this render criterion` (lib/verdict_ledger.py `_run_fault`, "unseen-page"). Review run
run-t-5260-352f1106e9 derived no required page for AC#1 (the criterion names a screenshot
directory and "the fixture URL named in the Visual Verification table", not a URL the run could
capture; the fixture server on 127.0.0.1:3977 is a temporary instance). A render green must be
backed by a page the run itself captured, so this seat cannot leave a green row and I did not
work around the gate.

For the operator's reading: on the three supplied screenshots I found nothing wrong — header,
menu, status strip, project content and footer are all present and unbroken at 1024, 1440 and
1920 px, and the 1024 header wrap is identical on the framework's own /cron page.

What is needed: a review run that records a capturable page for AC#1 (fixture Watchtower up with
its URL registered for the run, or the criterion naming a page the run can derive), then
re-dispatch.
