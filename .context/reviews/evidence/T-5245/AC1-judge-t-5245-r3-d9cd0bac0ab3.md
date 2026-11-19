# T-5245 Human AC#1 — evidence report (judge-t-5245-r3-d9cd0bac0ab3)

Revision reviewed: 61602a3a44cacc6e67d537094939c77c65d93688
Criterion: the settings page shows the new FOCUS_BRIEFING row like its neighbours.

## What I looked at (supplied images, judged as given; cannot reproduce — the capture was not re-run)

- 01-config-judge-t-5245-r3-d9cd0bac0ab3.png (full /config page, 1280x10408, sha256 3ebcb448…bac5). Too tall to read whole, so I cropped the band y=6150..6900 of this same image and read it at full resolution.
- config-row@1024-judge-t-5245-r3-d9cd0bac0ab3.png, config-row@1440-judge-t-5245-r3-d9cd0bac0ab3.png, config-row@1920-judge-t-5245-r3-d9cd0bac0ab3.png (sha256 match the capture record config-row.capture.json: d4d1e935…, f77453bd…, 163395f8…).
- web/blueprints/config.py:90 (row source) and the task's Visual Verification table.

## Findings

1. Row present, exactly once. In the full-page crop the order is FW_INDEX_STALE_DAYS, FW_RECALL_USAGE_DAYS, FW_FOCUS_BRIEFING, FW_INDEX_MAX_AGE_HOURS: one FW_FOCUS_BRIEFING row, directly above FW_INDEX_MAX_AGE_HOURS as the criterion says. config.py has a single ("FOCUS_BRIEFING", "0", ...) tuple at line 90, between RECALL_USAGE_DAYS and INDEX_MAX_AGE_HOURS.
2. Key: shown as FW_FOCUS_BRIEFING. Every row on the page carries the FW_ prefix (the criterion's own neighbour INDEX_MAX_AGE_HOURS is shown as FW_INDEX_MAX_AGE_HOURS), so the criterion's registry-key naming and the page agree.
3. Default 0: Current column "0" (bold), Default column "0", Source badge DEFAULT.
4. Description shown in full: "1 = fw context focus (and fw work-on) also asks the local model for a task briefing (lib/ask.py, 15 s limit). Off by default: it timed out every time and cost ~15 s per focus; T-5245" — identical to config.py:90, not truncated at any width.
5. Layout unchanged. Columns line up with the rows above and below at 1024, 1440 and 1920 and in the 1280 full page. Wrapping is no worse than neighbours:
   - key cell: 3 lines at 1024 (FW_RECALL_USAGE_DAYS above it: 3 lines), 2 lines at 1280/1440/1920 (neighbour: 2; FW_INDEX_MAX_AGE_HOURS below: 3 at 1280);
   - source badge wraps "DEFAU/LT" on every row of the table, not only this one;
   - description: 3 lines at 1024/1280, 3 at 1440, 2 at 1920 — ordinary text wrap inside its cell, same as other long descriptions (e.g. FW_INDEX_REINDEX_INTERVAL_HOURS, 3 lines at 1280).
   No text overflows a cell, nothing is clipped, nothing overlaps.
6. Browser recorded no console or page errors for /config (per the dispatch).

## Visual Verification checklist

| state | control | 1024 | 1440 | 1920 |
|---|---|---|---|---|
| config-row | FW_FOCUS_BRIEFING row on /config | ok — visible, unclipped, no overlap | ok | ok |

My reading agrees with the task's table (ok/ok/ok).

Note (not a defect of this task): the crop step names FW_INDEX_MAX_AGE_HOURS as its end row, but the three width crops end after the FW_FOCUS_BRIEFING row; the lower neighbour is visible only in the full-page shot, where it lines up.

## Verdict: green
