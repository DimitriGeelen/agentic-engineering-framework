# T-4490 Human AC#1 — REVIEW_GREEN_DEGRADED row on /config

Reviewer: claude-code seat, rung-5-panel:claude-code, revision 1cabcd1b8b37341ceee9d12dd54b9afccba1c157.

**Degraded: single-vendor panel.** Fewer vendors could be dispatched than the panel needs, so
this run cannot satisfy a multi-vendor requirement. My verdict is recorded and reported, and the criterion stays open.

## What I checked
- Source: `web/blueprints/config.py:86` sits directly after `REVIEWER_JUDGE_WEEKLY_SPEND_CEILING` (line 85):
  `("REVIEW_GREEN_DEGRADED", "1", "1 (default): a rung-5 review panel whose only missing seats were provably
  unavailable closes a criterion as GREEN-DEGRADED when two or more seats of different vendors judged green and
  none dissented; never for tier-0, act-in-the-world or sovereignty criteria. Every such close is written on the
  criterion and WARNed by fw audit with a weekly count. Set 0 to opt out. T-4490.")`
- I did not restart watchtower myself (my role is read-only). I judged from the supplied rendered screenshots, which I
  cropped around the last rows of the env-var table and read:
  - `01-config-judge-t-4490-r5-claude-code-dcda7a0167a7.png` (1280w, copy of .context/working/judge-evidence/T-4490/01-config.png, sha256 f896833f…): row `FW_REVIEW_GREEN_DEGRADED`, current `1`, default `1`, DEFAULT badge, full description visible.
  - `config@1024.png`, `config@1440.png`, `config@1920.png`: the row renders at each width, directly below the spend-ceiling row
    and above "Custom Settings".

## Against Expected
- Default `1`: yes (current and default columns both show 1, with the DEFAULT badge).
- Description names the opt-out: yes, "Set 0 to opt out."
- Every degraded close is WARNed and counted weekly by fw audit: yes, "Every such close is written on the criterion and WARNed by fw audit with a weekly count."
- Layout matches its neighbours: yes. The column widths, the badge style, the vertically centred value cells, the row separator and the T-ID suffix
  all match the REVIEWER_JUDGE_WEEKLY_SPEND_CEILING and PROVISION_LOAD_MAX rows at all widths.
- The text reads clearly. It opens with "1 (default):", which echoes the value, and it states the scope exclusions (tier-0, act-in-the-world, sovereignty).

## Visual checklist (state config, control REVIEW_GREEN_DEGRADED row)
| width | result |
|---|---|
| 1024 | ok: visible, unclipped, no overlap |
| 1440 | ok |
| 1920 | ok |

## Observations outside this AC (not blocking)
- The Env Var column is narrow at every width, so long names wrap mid-token (e.g. `FW_RE/VIEW_G/REEN_D/EGRADE/D`). Every row has this, so it is not caused by this task.
- At 1024 the description column runs to the right edge of the table card on this row and its neighbours alike. This also predates the task.
