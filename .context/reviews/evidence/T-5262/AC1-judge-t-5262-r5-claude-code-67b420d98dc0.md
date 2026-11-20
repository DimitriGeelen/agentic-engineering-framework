# T-5262 Human AC#1 — evidence report (rung-5-panel seat claude-code)

Revision reviewed: 99293a51c64e06025a898f55df0b9d4027974cf2
Criterion: Watchtower pages still render the same after the web/app.py form-safety change.

Cannot reproduce: I did not re-run the app or the capture; I judged the supplied images, as briefed.

## What I opened
All 9 `fw ux shots` crops in `.context/visual/T-5262/`, both judge captures
(`01-root.png`, `02-approvals.png`, 1280x900 viewport, top of page only), and the
baseline shots in `.context/visual/T-5260/` (home-header, cron-header, cron-footer, home-footer).

## Findings

| state | 1024 | 1440 | 1920 | comparison with T-5260 |
|-------|------|------|------|------------------------|
| home-header | ok | ok | ok | sha256 byte-identical to T-5260 `home-header@{1024,1440,1920}` (aa33db7e…, 8f81efd1…, 22441c8a…) |
| approvals-header | ok | ok | ok | sha256 byte-identical to T-5260 `cron-header@{…}` (3a5a7de8…, f0c91e0d…, adbef03f…); /cron and /approvals are both in the Govern menu group, so the same item is highlighted |
| approvals-footer | ok | ok | ok | same size as T-5260 `cron-footer` (W x 97); pixel diff is confined to one bbox on the version line (y 30-44), i.e. the build id `60-141-g722718588` -> `60-175-g1235bb179`; nothing else differs |

- Header, every width: logo + "Watchtower", Work / Knowledge / Architecture / Govern menus, Docs, search, settings and theme toggle are all visible, unclipped, no overlap. At 1024 the theme toggle wraps to a second row; the T-5260 baseline at 1024 is byte-identical, so this is how it was before, not a change.
- Footer, every width: version line and the "Found a framework bug? fw upstream report …" line are present and centred, unclipped.
- T-5260 has no /approvals shots; the nearest like-for-like baseline is its /cron header and footer (same nav group, same shared footer). The footer is shared layout, so this is a fair comparison.
- Judge captures: `/` shows menu, ambient strip, focus row, arcs list, tokens row; `/approvals` shows menu (Govern highlighted), breadcrumb, "Approvals (239 pending)", the brake form with its "Engage the brake" button, the count tiles and the first decision card. No added visible element, nothing missing or broken. Browser reported no console or page errors on either page.
- The footer build id `g1235bb179` is the build under review: `git diff 1235bb179 99293a51c -- web` is empty, so the screenshots show the complete web/app.py + web/project_extensions.py change.

## Limits
Both pages exceed the 16,000 px full-page limit, so the judge captures show the top only; the lower part is covered by the footer crops alone. The criterion's Expected names menu, header and footer, which are all covered.

## Verdict
green
