# T-4001 Human AC#1: reviewer PASS/FAIL badges read green/red (review at 162f7e1b1)

## What I checked
1. **Code change (b5476ec48):** `web/templates/arc_detail.html:447,452`. The badge backgrounds changed from `var(--pico-ins-color,#2a7)` / `var(--pico-del-color,#c33)` to `var(--wt-success)` / `var(--wt-danger)`. The text stays `#fff`.
2. **Live server** (http://192.168.10.107:3000): the badges appear only on arc-006 and arc-011. The served markup uses `background: var(--wt-success)` for "Reviewer: PASS" and `var(--wt-danger)` for "Reviewer: FAIL — scorable". The served palette is `data-wt-palette="stone"`.
3. **Token values** (`static/css/foundations.css:21-57`): `--wt-success` is green and `--wt-danger` is red in every palette. The dark-mode blocks (`[data-theme="dark"]…`, lines 60-100) do NOT override these two tokens, so dark mode keeps the light values.
4. **White-text contrast** (WCAG relative luminance):

| palette | PASS bg | white contrast | FAIL bg | white contrast |
|---|---|---|---|---|
| stone (served) | #5a8a3a | 4.09 | #a44a2d | 5.84 |
| linen | #5b8a5a | 4.02 | #b1503e | 5.14 |
| paper | #0e8a4f | 4.41 | #d33232 | 4.92 |
| bone | #5e8a3a | 4.06 | #a8442e | 5.95 |
| slate (:root default) | #10b981 | **2.54** | #ef4444 | **3.76** |
| console | #22c55e | **2.28** | #f87171 | **2.77** |

## Limits
- The screenshot I was given (`01-arcs.png`) shows the /arcs index, which has no reviewer badges. I have not seen the badges rendered in light or dark mode.
- The finding is based on the served markup and the CSS token values, not on a visual check.

## Finding
- Hue: met. PASS is green and FAIL is red in every palette, in both themes.
- Readability on the served stone palette: borderline-acceptable. PASS is about 4.1:1 at 0.8em, just below AA 4.5:1; FAIL is 5.8:1.
- Readability on slate (the `:root` default when no palette is set) and console: poor. White on #10b981 is 2.5:1 and white on #22c55e is 2.3:1.
