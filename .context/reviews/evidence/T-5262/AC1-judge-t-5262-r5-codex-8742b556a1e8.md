# Reviewer evidence — T-5262 AC#1

- dispatch: `judge-t-5262-r5-codex-8742b556a1e8`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `70ce1b131992f00fff0f1967b3daf0e5facf8eca`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `865db2f16faf29967df8f7b0820967c6d9a00e23950ae2768caf6cd22a08af49`
- result.md sha256: `91e837903861ee4b209dda8ebd5b28bbeb555ae03e5189a94dc77ccaa576e2e8`

## The worker's verdict block

```
1. [AC] Watchtower pages still render the same
VERDICT: red
WHY: Opened all 11 screenshots. Both header crops at 1024, 1440 and 1920 show the logo, Work, Knowledge, Architecture, Govern, Docs, search, settings and theme toggle without clipping or overlap. The 1024 theme toggle occupies the permitted second row. All three footer crops show complete, unobstructed footer text. However, 02-approvals.png (1280 px wide) lacks the search and settings icons visible in 01-root.png and the approvals header crops. Therefore, the supplied evidence does not consistently meet “every framework menu element … present.”
GUIDANCE: Resolve the missing search and settings icons on /approvals at 1280 px and provide consistent screenshots confirming their visibility. Screenshots alone do not establish whether a project exemption is registered.

--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/01-root.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/02-approvals.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/home-header@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/home-header@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/home-header@1920.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-header@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-header@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-header@1920.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-footer@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-footer@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-footer@1920.png

Summary: 0 green, 0 amber, 1 red, 0 escalate, 0 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Watchtower pages still render the same
VERDICT: red
WHY: Opened all 11 screenshots. Both header crops at 1024, 1440 and 1920 show the logo, Work, Knowledge, Architecture, Govern, Docs, search, settings and theme toggle without clipping or overlap. The 1024 theme toggle occupies the permitted second row. All three footer crops show complete, unobstructed footer text. However, `02-approvals.png` (1280 px wide) lacks the search and settings icons visible in `01-root.png` and the approvals header crops. Therefore, the supplied evidence does not consistently meet “every framework menu element … present.”
GUIDANCE: Resolve the missing search and settings icons on `/approvals` at 1280 px and provide consistent screenshots confirming their visibility. Screenshots alone do not establish whether a project exemption is registered.

--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/01-root.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/02-approvals.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/home-header@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/home-header@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/home-header@1920.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-header@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-header@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-header@1920.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-footer@1024.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-footer@1440.png
--evidence /tmp/tl-dispatch/judge-t-5262-r5-codex-8742b556a1e8/tmp/review-T-5262-codex/evidence/approvals-footer@1920.png

Summary: 0 green, 0 amber, 1 red, 0 escalate, 0 not-evaluated
```
