# T-5079 Human AC#1 — RELEASE_ARTIFACT_PATHS on /config (reviewer judge-t-5079-r3-99728bfcce67)

Revision reviewed: 640c33582ffc566b188ba6aee24ccff468232d2a

## What I checked
- Read all four screenshots in full and cropped the row region of each at native resolution
  (judge shot 01-config.png at 1280; ux shots at 1024, 1440, 1920).
- Capture notes: /config, 0 console errors, full page (height 8614).
- Source: lib/config.sh:264 and web/blueprints/config.py:21 carry the same entry with empty default.

## Findings
- Row present: key shown as FW_RELEASE_ARTIFACT_PATHS (every row on the page carries the FW_ env prefix),
  placed between FW_UX_SHOT_WIDTHS and FW_ABSENT_COMPONENTS.
- Current and Default cells are empty; Source badge DEFAULT. Empty default: met.
- Description as rendered: "Directories (ending in /, at least two levels deep, outside source and
  framework-state trees) that this project's release commit generates. A release commit touching only
  these does not make a reviewer verdict stale. Read only from .framework.yaml as committed; refused
  entries are ignored and WARNed by fw audit (T-5079, 832)".
  - Scope "only for files a release generates": stated (directories this project's release commit generates).
  - What it refuses: the parenthetical gives the acceptance rules (trailing /, >=2 levels deep, not in
    source or framework-state trees), and the closing clause says refused entries are ignored and WARNed
    by fw audit. Also states it is read only from the committed .framework.yaml (no env/CLI override).
- Visual checklist (row key/default/description) at 1024/1440/1920 and 1280: visible, unclipped, no overlap;
  the key wraps across lines in the narrow Env Var column like every other row. All ok.

Minor non-blocking note: "832" in the trailer is an opaque reference to a reader; harmless.

Verdict: green.
