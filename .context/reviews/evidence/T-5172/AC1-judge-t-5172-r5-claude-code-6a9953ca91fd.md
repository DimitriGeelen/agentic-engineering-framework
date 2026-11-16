# T-5172 Human AC#1 — evidence report (judge-t-5172-r5-claude-code-6a9953ca91fd, panel seat claude-code)

Revision reviewed: 170ee2e9fb6a5b952be4b6e9c85a766104bf559a (HEAD at review time matched).

Criterion: a file in a declared folder opens from a review page —
http://192.168.10.107:3000/file/scripts/agent-listeners.sh shows the script with syntax
highlighting and line numbers; long lines scroll sideways inside the code box rather than
widening the page.

## What I checked

1. **Declaration.** `.framework.yaml:49` reads `VIEWABLE_DIRS: scripts`. The /config screenshot
   (02-config-judge-t-5172-r5-claude-code-6a9953ca91fd.png) shows the settings page rendering normally; at its capture scale I could not
   read the individual row, so the declaration is taken from the file, not the screenshot.
2. **Live fetch.** `curl http://192.168.10.107:3000/file/scripts/agent-listeners.sh` -> HTTP 200,
   128561 bytes. Markup: `<div class="file-lines"><pre>` with one `<span id="L<n>" class="line">`
   per source line and token spans (`class="ch"` etc.).
3. **Screenshots read** (all five): 01-file-scripts-agent-listeners-sh, script-file@1024/1440/1920.
   Each shows the title "scripts/agent-listeners.sh", a single code box, right-aligned grey line
   numbers 1-232, and coloured tokens (green italic comments, red strings, bold keywords, blue
   numbers/variables). No overlap, nothing hidden; header and footer intact.
   At 1024 the long lines (124, 198, 225-227) are cut at the right edge of the code box and the
   screenshot is still exactly 1024 px wide; at 1440 and 1920 every line fits.
4. **Own headless-browser measurement** (playwright chromium, live page, not the producer's figures):

   | viewport | pre scrollWidth | pre clientWidth | scrollLeft after scrolling | overflow-x | document scrollWidth | document clientWidth |
   |---|---|---|---|---|---|---|
   | 1024 | 1151 | 918 | 233 | auto | 1024 | 1024 |
   | 1440 | 1168 | 1168 | 0 | auto | 1440 | 1440 |
   | 1920 | 1418 | 1418 | 0 | auto | 1920 | 1920 |

   232 `.line` elements; `::before` content is `counter(line)` (line numbers); 9 distinct token
   colours. At 1024 the code box really scrolls (233 px) and the page does not widen
   (document scrollWidth == clientWidth). CSS: `.file-lines pre { overflow-x: auto }`.
5. **Not opened wider than declared (spot check).** /file/etc/passwd -> 404, /file/.env -> 404.
6. Capturing browser reported no console or page errors on either page (brief, T-4960).

## Visual Verification checklist

| state | control | 1024 | 1440 | 1920 | my reading |
|---|---|---|---|---|---|
| script-file | /file/scripts/agent-listeners.sh | ok | ok | ok | agrees with the task's table; the 1024 clipping is in-box scroll, confirmed by measurement. The task note names line 228 as long; the lines actually past the edge are 124, 198 and 225-227 (a note inaccuracy, not a defect). |

## Verdict: green
