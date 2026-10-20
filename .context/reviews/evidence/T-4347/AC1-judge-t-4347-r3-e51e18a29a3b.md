# T-4347 Human AC#1 — ISSUES_DECISIONS_STANDING_PERMISSION row on /config

Reviewer: judge-t-4347-r3-e51e18a29a3b, revision 69e8de57a8b88ad7e3a6600c0b36643ee4796043

## Checks
1. `bin/fw watchtower url` -> http://192.168.10.107:3000
2. Live `curl /config`: row `FW_ISSUES_DECISIONS_STANDING_PERMISSION`: Current **1**, Default `0`, Source badge `file`,
   description: "1 = fw issues comment posts a decision stage (accepted / needs-info / duplicate / not-planned) without a
   per-comment operator approval; the ledger row records approved_by: standing-permission:operator-2026-10-19
   (operator ruling 2026-10-19, T-4347). 0 keeps the per-comment approval"
3. Source: `git show 69e8de57a:web/blueprints/config.py` line 25 holds the same tuple (default "0").
   `.framework.yaml:32` = `ISSUES_DECISIONS_STANDING_PERMISSION: 1`.
4. Expected text checks: value 1 ✓, default 0 ✓, names the operator ruling of 2026-10-19 ✓, says 0 keeps per-comment approval ✓.

## Visual
- 01-config.png (judge render, 1280): row visible, value 1 / default 0 / FILE / full description.
- config@1024.png: cropped and zoomed. The row is visible, value 1, default 0, FILE badge, description wraps fully inside the column. The env-var name wraps every 3 chars, the same as every other row (existing table styling, not this task). Nothing clipped or overlapping.
- config@1440.png: cropped. Row fully readable, no clipping.
- config@1920.png: row fully readable, no clipping or overlap.

Verdict: green.
