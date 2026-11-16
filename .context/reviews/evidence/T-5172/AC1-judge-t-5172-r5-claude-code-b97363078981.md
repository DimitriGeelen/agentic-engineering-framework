# T-5172 Human AC#1 — evidence report (panel seat claude-code, rung 5)

Revision reviewed: 9032563a310bdf79fc76a7f4e0b3aebde804258d

Criterion: a file in a declared folder opens from a review page —
http://192.168.10.107:3000/file/scripts/agent-listeners.sh shows the script with syntax
highlighting and line numbers; long lines scroll sideways inside the code box rather than
widening the page.

## What I checked

1. Precondition: `.framework.yaml:49` declares `VIEWABLE_DIRS: scripts`.
2. Live page: `curl` of the URL returned HTTP 200. The markup is
   `<div class="file-lines"><pre>…<span id="L1" class="line">…`, with the rule
   `.file-lines pre { counter-reset: line; overflow-x: auto; … }`.
3. Screenshots read (all five): the judge capture of the file page (1280 wide), the three
   checklist captures at 1024 / 1440 / 1920, and the /config capture.
   - File page, every width: heading `scripts/agent-listeners.sh`, a code box with a
     numbered gutter 1–232 and coloured tokens (comments green italic, strings red,
     keywords bold, numbers blue). The header, nav and footer are intact, nothing overlaps.
   - 1024: lines 124, 198, 221 and 226–227 are cut at the right edge of the code box; the
     page itself stays 1024 wide (no horizontal page overflow in the capture).
   - 1440 and 1920: every line fits inside the box.
   - /config: renders normally; no errors. The capturing browser reported no console or
     page errors for either page.
4. My own headless-browser measurement (Playwright/Chromium against the live page):

   | viewport | pre overflow-x | pre scrollWidth | pre clientWidth | scrollLeft after scroll | document scrollWidth / clientWidth |
   |----------|----------------|-----------------|-----------------|-------------------------|------------------------------------|
   | 1024 | auto | 1151 | 918 | 233 | 1024 / 1024 |
   | 1440 | auto | 1168 | 1168 | 0 | 1440 / 1440 |
   | 1920 | auto | 1418 | 1418 | 0 | 1920 / 1920 |

   So at 1024 the code box scrolls sideways by 233 px and the page is not widened. The
   page has 232 `.line` elements (the file has 232 lines, `wc -l`), 1066 coloured token
   spans, and the line number comes from `::before { content: counter(line) }`.

## Checklist row (script-file | /file/scripts/agent-listeners.sh)

1024 ok, 1440 ok, 1920 ok — agrees with what I saw. The row's note (scrollWidth 1151 >
clientWidth 918, scrolled 233 px) matches my own measurement exactly.

## Verdict

green — highlighting, line numbers and in-box sideways scrolling all confirmed, by
screenshot and by measurement on the live page.
