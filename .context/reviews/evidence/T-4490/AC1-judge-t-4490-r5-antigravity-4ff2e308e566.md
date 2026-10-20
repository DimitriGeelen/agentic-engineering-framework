# Reviewer evidence — T-4490 AC#1

- dispatch: `judge-t-4490-r5-antigravity-4ff2e308e566`
- worker kind: `antigravity` (vendor `google`, model `worker default`)
- seat: `antigravity`
- reviewed revision: `1cabcd1b8b37341ceee9d12dd54b9afccba1c157`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.md sha256: `87bb9c6526ac1bf6ff3ee1454813c0b988bbdfbfb2d2764d899def6584f2640a`

## The worker's verdict block

```
1. [AC] The new REVIEW_GREEN_DEGRADED row on /config reads clearly next to the spend-ceiling row
VERDICT: green
WHY: Verified in web/blueprints/config.py (line 86) and lib/config.sh (line 393), and visually confirmed across all rendered page screenshots (--evidence .context/working/judge-evidence/T-4490/01-config.png, --evidence .context/visual/T-4490/config@1024.png, --evidence .context/visual/T-4490/config@1440.png, --evidence .context/visual/T-4490/config@1920.png). The FW_REVIEW_GREEN_DEGRADED row sits directly below FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING, displays default 1 (and current 1 with DEFAULT badge), clearly states the Set 0 to opt out mechanism, the conditions for GREEN-DEGRADED closure (including exclusions for tier-0, act-in-the-world, and sovereignty criteria), and that every degraded close is written on the criterion and WARNed by fw audit with a weekly count. At 1024, 1440, and 1920 widths the row is visible, unclipped, reachable, and matches its neighbours' layout. (Note: degraded: single-vendor panel — this run records the antigravity seat verdict, and the criterion remains open pending multi-vendor panel completion.)
GUIDANCE: None on the criterion itself; remains open only because this dispatch is a degraded single-vendor panel run.

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```

## The worker's full output (result.md)

```
Independent review evidence report for `T-4490` at revision `1cabcd1b8b37341ceee9d12dd54b9afccba1c157` (panel seat: `antigravity`, rung: `rung-5-panel:antigravity`).

**Note on panel status:** This run is operating under `degraded: single-vendor panel`. Because fewer vendors can be dispatched than the multi-vendor panel requires, this single-vendor run cannot by itself satisfy the multi-vendor requirement: my verdict is recorded and reported below, and the criterion stays open until multi-vendor requirements are met.

### Evidence Checked
- Code & Registry:
  - [web/blueprints/config.py](file:///tmp/tl-dispatch/judge-t-4490-r5-antigravity-4ff2e308e566/tree/web/blueprints/config.py#L85-L86): `REVIEW_GREEN_DEGRADED` is registered immediately after `REVIEWER_JUDGE_WEEKLY_SPEND_CEILING` with default `"1"` and description: `"1 (default): a rung-5 review panel whose only missing seats were provably unavailable closes a criterion as GREEN-DEGRADED when two or more seats of different vendors judged green and none dissented; never for tier-0, act-in-the-world or sovereignty criteria. Every such close is written on the criterion and WARNed by fw audit with a weekly count. Set 0 to opt out. T-4490."`
  - [lib/config.sh](file:///tmp/tl-dispatch/judge-t-4490-r5-antigravity-4ff2e308e566/tree/lib/config.sh#L391-L393): Parity confirmed with `FW_CONFIG_REGISTRY`.
  - [T-4490-green-degraded-closes-a-rung-5-review-pa.md](file:///tmp/tl-dispatch/judge-t-4490-r5-antigravity-4ff2e308e566/tree/.tasks/active/T-4490-green-degraded-closes-a-rung-5-review-pa.md#L315-L320): Visual Verification checklist specifies state `config`, control `REVIEW_GREEN_DEGRADED row`, `ok` across `1024`, `1440`, and `1920`.
- Screenshots inspected (`--evidence`):
  - `--evidence .context/working/judge-evidence/T-4490/01-config.png`
  - `--evidence .context/visual/T-4490/config@1024.png`
  - `--evidence .context/visual/T-4490/config@1440.png`
  - `--evidence .context/visual/T-4490/config@1920.png`
- Visual Verification across viewports:
  - In all four screenshots (`01-config.png`, `config@1024.png`, `config@1440.png`, `config@1920.png`), the `FW_REVIEW_GREEN_DEGRADED` row renders at the bottom of the Settings table directly beneath `FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING`.
  - Current value `1`, Default `1`, Source badge `DEFAULT`, and the full description text are visible, reachable, unclipped, and free of overlap at 1024px, 1440px, and 1920px widths, matching the layout rhythm of neighbouring rows.

1. [AC] The new REVIEW_GREEN_DEGRADED row on /config reads clearly next to the spend-ceiling row
VERDICT: green
WHY: Verified in `web/blueprints/config.py` (line 86) and `lib/config.sh` (line 393), and visually confirmed across all rendered page screenshots (`--evidence .context/working/judge-evidence/T-4490/01-config.png`, `--evidence .context/visual/T-4490/config@1024.png`, `--evidence .context/visual/T-4490/config@1440.png`, `--evidence .context/visual/T-4490/config@1920.png`). The `FW_REVIEW_GREEN_DEGRADED` row sits directly below `FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING`, displays default `1` (and current `1` with `DEFAULT` badge), clearly states the `Set 0 to opt out` mechanism, the conditions for `GREEN-DEGRADED` closure (including exclusions for tier-0, act-in-the-world, and sovereignty criteria), and that every degraded close is written on the criterion and WARNed by `fw audit` with a weekly count. At 1024, 1440, and 1920 widths the row is visible, unclipped, reachable, and matches its neighbours' layout. (Note: `degraded: single-vendor panel` — this run records the `antigravity` seat verdict, and the criterion remains open pending multi-vendor panel completion.)
GUIDANCE: None on the criterion itself; remains open only because this dispatch is a degraded single-vendor panel run.

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```
