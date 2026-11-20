# T-5262 Human AC#1 — evidence report (panel seat claude-code)

Revision reviewed: fb1a7870c7e5d402dd89034a0093900b8c097d1d. Judged from the supplied images only;
cannot reproduce (the app and capture were not re-run, per the brief). The producer's "answer to red verdict"
text in the task file was not used as evidence; every statement below is from my own reading of each image.

## What I opened (all 11 images, each viewed)

| image | logo | Work | Knowledge | Architecture | Govern | Docs | search | settings | theme toggle | clipping / overlap |
|---|---|---|---|---|---|---|---|---|---|---|
| home-header@1024 | yes | yes | yes | yes | yes | yes | yes | yes | yes, second header row, left under "Work" | none |
| home-header@1440 | yes | yes | yes | yes | yes | yes | yes | yes | yes, same row | none |
| home-header@1920 | yes | yes | yes | yes | yes | yes | yes | yes | yes, same row | none |
| approvals-header@1024 | yes | yes | yes | yes | yes (highlighted, current page) | yes | yes | yes | yes, second header row | none |
| approvals-header@1440 | yes | yes | yes | yes | yes (highlighted) | yes | yes | yes | yes, same row | none |
| approvals-header@1920 | yes | yes | yes | yes | yes (highlighted) | yes | yes | yes | yes, same row | none |
| 01-root.png (1280) | yes | yes | yes | yes | yes | yes | yes (x~908) | yes (x~948) | yes (x~992) | none in the header |
| 02-approvals.png (1280) | yes | yes | yes | yes | yes (highlighted) | yes | yes (x~908) | yes (x~948) | yes (x~992) | none in the header |

Footer (/approvals), at 1024, 1440 and 1920: two centred lines, "Watchtower v1.8.16-be.60-175-g1235bb179 —
Agentic Engineering Framework" and "Found a framework bug?  fw upstream report --title "..." --attach-doctor".
Complete at every width, not clipped, no overlap.

## Findings

- Every framework menu element named in the criterion is present on both pages at 1024, 1440 and 1920 px, and
  in the two 1280 px judge captures. Home and /approvals headers are identical apart from the Govern highlight
  on /approvals (current-page marker).
- No element beyond the framework menu is visible in the header or footer: four groups plus Docs, three icons.
  No project group or extra link, consistent with no project extension/exemption being drawn.
- At 1024 px the theme toggle sits alone on a second header row. T-5261's checklist (completed task file,
  state menu-no-extension and the note on menu-ring20-open) records that as the layout without extensions, so
  it is the existing layout, as the criterion states.
- Browser record for both pages: no console or page errors.
- Body content in the 1280 px captures (home arcs list, /approvals brake form and counters) renders normally;
  the /approvals form is drawn with its button, no error page.

## Limits

- No pre-change screenshots were supplied, so "the same" is judged against the criterion's Expected list and
  T-5261's recorded layout, not by a pixel comparison.
- "no project exemption is registered here" is not something an image can show beyond the absence of any added
  element; I did not verify the register's contents.
- The home page footer was not captured (the criterion asks only for the /approvals footer).
- Minor, not part of the criterion: in 01-root.png the home FOCUS line reads "...exemption list: owned b",
  a truncated task title in page content, not a menu or footer element.

Verdict: green.
