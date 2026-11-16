# Reviewer evidence — T-5172 AC#1

- dispatch: `judge-t-5172-r5-codex-1b96ea7d1900`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `2793879cb5b5a72badf90b6e3fc618888a9c9e08`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `a296510475763b901c1c203a427b8d381822d40b526adc1645ef5401bfb70fec`
- result.md sha256: `7040972ecc9dd2f8cf4c6eec334c15ef0a6a870bdd96a909efd157cf9024468c`

## The worker's verdict block

```
1. [AC] A file in a declared folder opens from a review page
VERDICT: not-evaluated
WHY: Inspected all five supplied screenshots and the Visual Verification checklist. The script displays syntax highlighting and line numbers at 1024, 1440, and 1920 pixels. Its title and line-number gutter are visible without overlap at each width. At 1024, long lines are clipped by the code pane; horizontal-scroll reachability cannot be verified from screenshots. The /config capture shows the configuration page, not /file/.git/config. The required /file/.git/config page was not captured or seen, so refusal in step 2 could not be evaluated.
GUIDANCE: Capture /file/.git/config and verify that access is refused without serving its contents. Verify horizontal scrolling reaches clipped script content at 1024 pixels before accepting the checklist’s “ok” entry.

--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1b96ea7d1900/tmp/review-evidence-T-5172-codex/01-file-scripts-agent-listeners-sh.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1b96ea7d1900/tmp/review-evidence-T-5172-codex/03-config.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1b96ea7d1900/tmp/review-evidence-T-5172-codex/script-file@1024.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1b96ea7d1900/tmp/review-evidence-T-5172-codex/script-file@1440.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1b96ea7d1900/tmp/review-evidence-T-5172-codex/script-file@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] A file in a declared folder opens from a review page
VERDICT: not-evaluated
WHY: Inspected all five supplied screenshots and the Visual Verification checklist. The script displays syntax highlighting and line numbers at 1024, 1440, and 1920 pixels. Its title and line-number gutter are visible without overlap at each width. At 1024, long lines are clipped by the code pane; horizontal-scroll reachability cannot be verified from screenshots. The `/config` capture shows the configuration page, not `/file/.git/config`. The required `/file/.git/config` page was not captured or seen, so refusal in step 2 could not be evaluated.
GUIDANCE: Capture `/file/.git/config` and verify that access is refused without serving its contents. Verify horizontal scrolling reaches clipped script content at 1024 pixels before accepting the checklist’s “ok” entry.

--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1b96ea7d1900/tmp/review-evidence-T-5172-codex/01-file-scripts-agent-listeners-sh.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1b96ea7d1900/tmp/review-evidence-T-5172-codex/03-config.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1b96ea7d1900/tmp/review-evidence-T-5172-codex/script-file@1024.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1b96ea7d1900/tmp/review-evidence-T-5172-codex/script-file@1440.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1b96ea7d1900/tmp/review-evidence-T-5172-codex/script-file@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
