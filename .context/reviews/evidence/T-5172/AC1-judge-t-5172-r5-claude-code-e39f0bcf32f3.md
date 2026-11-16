# T-5172 Human AC#1 — evidence report (panel seat claude-code, dispatch judge-t-5172-r5-claude-code-e39f0bcf32f3)

Revision reviewed: 1c8d7d309699d1539c6b6a7bef1f2ca463b915ae
Criterion: a file in a declared folder opens at /file/scripts/agent-listeners.sh with syntax
highlighting and line numbers; long lines scroll sideways inside the code box rather than widening the page.

## What I checked

1. **Declaration.** `.framework.yaml:49` has `VIEWABLE_DIRS: scripts`. The /config screenshot
   (02-config) renders without errors.
2. **Screenshots read (all five).**
   - 01-file-scripts-agent-listeners-sh (1280 wide): heading "scripts/agent-listeners.sh", code box with
     line numbers 1-232 in a left gutter, coloured tokens (green italic comments, red strings, bold
     green keywords, blue variables).
   - script-file@1024: same; lines 124, 198, 222, 226 run to the right edge of the code box and are
     cut off there; the box and page stay within the 1024 viewport (nav, heading, footer unshifted).
   - script-file@1440 and @1920: same content, every line fits, nothing clipped, no overlap.
3. **Live page, own browser check** (headless Chromium via Playwright, HTTP 200, no console or page errors
   at any width):

   | width | pre overflow-x | pre scrollWidth / clientWidth | scrollLeft after scrolling right | document scrollWidth / clientWidth |
   |-------|----------------|-------------------------------|----------------------------------|-------------------------------------|
   | 1024  | auto           | 1151 / 918                    | 233                              | 1024 / 1024                         |
   | 1440  | auto           | 1168 / 1168                   | 0 (nothing to scroll)            | 1440 / 1440                         |
   | 1920  | auto           | 1418 / 1418                   | 0 (nothing to scroll)            | 1920 / 1920                         |

   So at 1024 the long lines scroll sideways inside the code box (233 px) and the page is not widened.
   232 `span.line` elements (matches `wc -l scripts/agent-listeners.sh` = 232), line numbers drawn by a
   CSS counter (`::before { content: counter(line) }`), 9 distinct token colours.
4. **Scope of "declared".** `/file/bin/fw` (a folder not declared) returns 404, so the page is served
   because of the declaration.

## Visual Verification checklist (state script-file, control /file/scripts/agent-listeners.sh)

| width | visible | reachable | unclipped | no overlap |
|-------|---------|-----------|-----------|------------|
| 1024  | yes | yes | long lines scroll inside the box, as the criterion expects | yes |
| 1440  | yes | yes | yes | yes |
| 1920  | yes | yes | yes | yes |

The task's own note says lines "124/198/228" overrun at 1024; in the screenshot the overrunning lines are
124, 198, 222 and 226. A slip in the note, not in the page.

## Verdict: green
