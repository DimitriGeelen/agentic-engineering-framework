# Reviewer evidence — T-5262 AC#1

- dispatch: `judge-t-5262-r5-codex-cc747b0f5d67`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `fb1a7870c7e5d402dd89034a0093900b8c097d1d`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `a857ce49e9080fd0b96a63e6774e00fcef52b1cc899389d34615883ba63d6902`
- result.md sha256: `357b0461b89160c894403e04bf282348bba72c22c4bc9e5db0e50d2c38e51eed`

## The worker's verdict block

```
1. [AC] Watchtower pages retain all menu elements and footer text
VERDICT: red
WHY: Opened all 11 screenshots. Both header crops at 1024, 1440 and 1920 show logo, Work, Knowledge, Architecture, Govern, Docs, search, settings and theme toggle without overlap or clipping. The 1024 theme toggle occupies the permitted second row. All three footer crops show complete, unclipped text. However, the separate 1280 px rendered /approvals screenshot, 02-approvals.png, lacks the search and settings icons between Docs and the theme toggle; those icons are visible in 01-root.png. The supplied evidence therefore does not consistently meet “every framework menu element … present.”
GUIDANCE: Resolve the missing search and settings icons on /approvals at 1280 px and supply a consistent rendered screenshot demonstrating both controls are visible.

--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/01-root.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/02-approvals.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/home-header@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/home-header@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/home-header@1920.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-header@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-header@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-header@1920.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-footer@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-footer@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-footer@1920.png

Summary: 0 green, 0 amber, 1 red, 0 escalate, 0 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Watchtower pages retain all menu elements and footer text
VERDICT: red
WHY: Opened all 11 screenshots. Both header crops at 1024, 1440 and 1920 show logo, Work, Knowledge, Architecture, Govern, Docs, search, settings and theme toggle without overlap or clipping. The 1024 theme toggle occupies the permitted second row. All three footer crops show complete, unclipped text. However, the separate 1280 px rendered `/approvals` screenshot, 02-approvals.png, lacks the search and settings icons between Docs and the theme toggle; those icons are visible in 01-root.png. The supplied evidence therefore does not consistently meet “every framework menu element … present.”
GUIDANCE: Resolve the missing search and settings icons on `/approvals` at 1280 px and supply a consistent rendered screenshot demonstrating both controls are visible.

--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/01-root.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/02-approvals.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/home-header@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/home-header@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/home-header@1920.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-header@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-header@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-header@1920.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-footer@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-footer@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-cc747b0f5d67/tmp/review-evidence/T-5262/approvals-footer@1920.png

Summary: 0 green, 0 amber, 1 red, 0 escalate, 0 not-evaluated
```
