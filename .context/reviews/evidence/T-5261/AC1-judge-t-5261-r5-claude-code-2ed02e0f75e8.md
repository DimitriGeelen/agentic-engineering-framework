# T-5261 Human AC#1: Project menu entries look like the framework's own

Seat: rung-5-panel:claude-code. Revision a169c3382. Judged on the supplied images (cannot reproduce: the capture was not re-run, per the brief).

## What I opened
All 12 shots in `.context/visual/T-5261/` (4 states x 1024/1440/1920; for the 3 full-page `menu-no-extension` shots I read the top 400 px, the header) and the 4 judge-evidence pages (copies in this directory).

## Style: same as framework entries
- **New group "Ring20"** (menu-ring20-open, all widths): the summary has the same font, size, colour, chevron and spacing as Work/Knowledge/Architecture/Govern. Its active shading is the same grey-green pill the framework's own Govern shows on /cron in `menu-no-extension`. The dropdown panel (white card, shadow, item font and olive colour, bold + tinted row for the current page) is the same as the Knowledge and Govern panels.
- **Appended item "Host notes"** (menu-knowledge-open): sits last, after Learnings, Graduation, Patterns, Decisions; same typeface, colour, row height and left alignment. It differs only by the current-page state (bold, tinted row), which is the framework's own.
- **Appended sub-section "RING20" + "Host audit"** (menu-govern-open): the sub-heading is the same small mono, letter-spaced capitals as APPROVALS & DECISIONS / ENFORCEMENT / HEALTH / OPERATIONS; it comes after Operations; the item matches its neighbours.
- Code cross-check: the task's commit (a4fba7ef2) changed no CSS; `web/templates/base.html` renders project items through the same nav macro as framework items (only the href and the aria-current test changed), so one style is expected, not coincidence.
- Framework order is unchanged: Work, Knowledge, Architecture, Govern, then Ring20, then Docs.

## Fit
- **1440, 1920:** everything on one header row, all three states; nothing clipped, hidden or overlapping. Dropdowns are fully inside the viewport.
- **1024:** the header is two rows. Row 1: Work, Knowledge, Architecture, Govern, Ring20, Docs (Docs ends near x=972 of 1024, not clipped). Row 2: search, settings, theme toggle. Without extensions (`menu-no-extension@1024`) the header is ALREADY two rows of the same height (status bar at y~166 in both); only the theme toggle is on row 2 there. So the fifth group moves two more icons (search, settings) down, it does not add a row or change the header height, and every control stays visible and reachable. The Ring20 dropdown (right edge x~950) and the Govern dropdown (bottom y~880 of 1000) are inside the viewport.
- Open dropdowns cover the row-2 icons or page text beneath them, as any open dropdown does.

## Things I saw that are not this task's
- Three groups (Knowledge, Govern, Ring20) are shaded at once. The fixture points one item in each at /hosts, the page shown (nav.yaml, nav_append.yaml, nav_govern.yaml), so this is the fixture, not a styling fault. A real project that lists one page in several groups will see the same.
- The framework's own sub-heading "APPROVALS & DECISIONS" runs about 18 px past the right edge of the Govern panel at all three widths. No CSS changed in this task, so it predates it; worth its own small task.
- The no-extension baseline is a different page (/cron on the real Watchtower) than the fixture shots (/hosts on 127.0.0.1:3977). The header is comparable; the body is not, and does not need to be.
- Judge-evidence pages (/docs/generated, /settings/, /settings/appearance at 1280): four framework groups, unchanged, one row. /settings/models is an unstyled text fragment with no menu (a partial), so it says nothing about the menu either way.

## Verdict
green. Margin at 1024 is thin: a longer group name or a second project group would push Docs to row 2 as well.
