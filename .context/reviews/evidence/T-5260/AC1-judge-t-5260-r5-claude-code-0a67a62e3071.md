# T-5260 Human AC#1 — evidence report (panel seat claude-code, dispatch judge-t-5260-r5-claude-code-0a67a62e3071)

Revision reviewed: 93b674aa9e00a40c5aa50ba4508cc6fb9cf53751

## What I checked
Cannot reproduce: I did not re-run the fixture Watchtower on 127.0.0.1:3977 or the capture (the brief
says to judge the supplied images). The brief's automatic capture failed, but the three supplied
screenshots exist, I opened each one, and their sha256 match .context/visual/T-5260/project-page.capture.json
(url http://127.0.0.1:3977/hosts, widths 1024/1440/1920). Copies cited here:

- project-page@1024-judge-t-5260-r5-claude-code-0a67a62e3071.png
- project-page@1440-judge-t-5260-r5-claude-code-0a67a62e3071.png
- project-page@1920-judge-t-5260-r5-claude-code-0a67a62e3071.png

For "normal Watchtower header/footer" I compared against a framework page, the T-5261 capture of /cron on the
real Watchtower (.context/visual/T-5261/menu-no-extension@1024.png), cropped to:
- framework-cron-header@1024-judge-t-5260-r5-claude-code-0a67a62e3071.png
- framework-cron-footer@1024-judge-t-5260-r5-claude-code-0a67a62e3071.png

## Findings, per width (checklist: header, menu, status strip, table, footer)

| control | 1024 | 1440 | 1920 |
|---|---|---|---|
| header (logo + Watchtower wordmark) | visible, unclipped | visible, unclipped | visible, unclipped |
| menu (Work, Knowledge, Architecture, Govern, Docs, search, settings, theme toggle) | all visible, no overlap; theme toggle wraps to a 2nd row | all on one row | all on one row |
| status strip (No focus / Session / Audit / 0 items need attention / t5260-fixture) | visible, unclipped | visible | visible |
| own content: "Hosts" heading, marker line, 3-column table (alpha/bravo/charlie) | renders inside the content column, no clipping, overflow or overlap | same | same |
| footer ("Watchtower dev — t5260 fixture", "Found a framework bug? fw upstream report ...") | visible, centred, unclipped | same | same |

The 1024 theme-toggle wrap: the framework's own /cron page at 1024 shows the identical wrap (toggle on a second
row under "Work", same header height, status strip at the same y). So it is the normal framework header at that
width, not a break caused by the project page; the task's Visual Verification note says the same and I
confirmed it from the image rather than taking it on trust. The framework footer has the same structure
(rule, version line, "Found a framework bug?" line) as the project page's.

Not checked from images: dropdown-open states and interactive behaviour (not part of the criterion).

## Verdict
not-evaluated (recorded), because the ledger refused the green I first tried to record:
`REFUSED: no required page was recorded for this render criterion` (lib/verdict_ledger.py:2862).
Review run run-t-5260-21453973a7 recorded no required page for AC#1 (the brief says "SCREENSHOT CAPTURE
FAILED: no page could be derived from the task or criterion text"), so no seat in this run can leave a
green on this render criterion. I did not bypass the gate.

My judgement of the supplied images, for whoever evaluates next: they show the criterion met. The project
page carries the normal Watchtower header, menu, status strip and footer, and its own content renders
without layout breaks at 1024, 1440 and 1920 px. Nothing is needed from the producer on the page itself.

What is needed: the run must record the criterion's page (http://127.0.0.1:3977/hosts, the fixture
Watchtower, which has to be serving when the run captures it) so a capture result exists, then re-dispatch.

Observation outside this criterion (not a finding against T-5260): the framework header wraps the theme
toggle to a second row at 1024 px on every page.
