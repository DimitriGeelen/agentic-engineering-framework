# T-5262 Human AC#1 — evidence report (seat claude-code, dispatch judge-t-5262-r5-claude-code-d31c648e5eaf)

Revision reviewed: 70ce1b131992f00fff0f1967b3daf0e5facf8eca. Criterion digest: 5758b9ffbcd7.
Cannot reproduce: I did not re-run the app or the capture; I judged the supplied images as given.

## What I opened (all 11 images, copies in this directory as <name>-judge-t-5262-r5-claude-code-d31c648e5eaf.png)

| image | width | what it shows |
|-------|-------|---------------|
| home-header@1024 | 1024 | logo + "Watchtower", Work, Knowledge, Architecture, Govern, Docs, search icon, settings gear on row 1; theme toggle (moon) on a second row under Work. Nothing clipped, nothing overlapping. |
| home-header@1440 | 1440 | all nine elements on one row, in order; no clipping or overlap. |
| home-header@1920 | 1920 | same as 1440. |
| approvals-header@1024 | 1024 | same layout as home@1024; Govern highlighted (the active group for /approvals); toggle on second row. |
| approvals-header@1440 | 1440 | all nine on one row, Govern highlighted. |
| approvals-header@1920 | 1920 | same as 1440. |
| approvals-footer@1024/1440/1920 | all | "Watchtower v1.8.16-be.60-175-g1235bb179 — Agentic Engineering Framework" and "Found a framework bug? fw upstream report --title \"...\" --attach-doctor", centred, complete, unclipped at every width. |
| 01-root | 1280 | top of /: header with all nine elements on one row, status strip, WATCHTOWER heading, focus line, arcs list, tokens strip. No added element (no banner, notice or extra menu group). |
| 02-approvals | 1280 | top of /approvals: same header (Govern active), breadcrumb, "Approvals (239 pending)", brake panel with its button, count tiles, Inception Decisions. Forms page renders; no added element. |

Capturing browser recorded no console or page errors on either page.

## Parts of the Expected clause

- Every framework menu element present at every width: yes (table above).
- Footer text present: yes, at 1024, 1440 and 1920.
- No clipping or overlap: none seen in any shot.
- The change adds no visible element: header holds exactly the four framework groups + Docs + three icons; no fifth group, banner or notice on either page.
- No project exemption registered here: `.framework-extensions.yaml` (the register web/project_extensions.py reads) does not exist in this project, so there are no csrf-exemption entries.
- 1024 px toggle on a second row is existing layout: T-5261's Visual Verification table has the state menu-no-extension ("real Watchtower /cron, no extensions registered") and its note on menu-ring20-open says the theme toggle "already sits there without extensions". The T-5261 baseline shot at 1024 is a 13,310 px full-page image, too small in my view to read the header pixel by pixel, so I rely on the criterion's own statement and the T-5261 record for this point; it is not a difference I count against the change.

## Limits

No before-change shots of / or /approvals were supplied, so "the same" is judged as the Expected clause defines it (elements present, unclipped, nothing added), not by pixel comparison.

Verdict: green.
