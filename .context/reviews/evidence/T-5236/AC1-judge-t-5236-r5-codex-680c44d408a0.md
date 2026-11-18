# Reviewer evidence — T-5236 AC#1

- dispatch: `judge-t-5236-r5-codex-680c44d408a0`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `bbddc108498817326e81ceba0d7e68ded1707c8b`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `14578b5b715c970d1a08bfc0fdd9fcb91bcc3c82f3d4ced0521391882ca69211`
- result.md sha256: `8b15d9140c9f7c43e30c792be7f8b62c11fc88d7c589cf604be507df6c8ff8f0`

## The worker's verdict block

```
1. [AC] Hub profile cards identify who, hub, waiting messages, and fix
VERDICT: green
WHY: Inspected all six screenshots. At 1024, 1440, and 1920 px, both cards clearly identify user root, host dimitrimintdev, the affected hub, missing/broken status, and “1 message waiting.” The missing-profile card displays the hubs.toml path, configuration lines, and secret-placement instruction. The broken-profile card displays the complete prepared bash command and termlink fleet reauth demo-lab. Both checklist controls are visible and unclipped, with no overlap at every width. Wrapping at 1024 px preserves readability. The three page screenshots were inspected; the section crops establish the card findings. Commands were not executed.
GUIDANCE: None.

--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/01-approvals.png
--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/02-approvals-content.png
--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/03-approvals-continuous-state.png
--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/hub-profiles@1024.png
--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/hub-profiles@1440.png
--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/hub-profiles@1920.png

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Hub profile cards identify who, hub, waiting messages, and fix
VERDICT: green
WHY: Inspected all six screenshots. At 1024, 1440, and 1920 px, both cards clearly identify user root, host dimitrimintdev, the affected hub, missing/broken status, and “1 message waiting.” The missing-profile card displays the hubs.toml path, configuration lines, and secret-placement instruction. The broken-profile card displays the complete prepared bash command and `termlink fleet reauth demo-lab`. Both checklist controls are visible and unclipped, with no overlap at every width. Wrapping at 1024 px preserves readability. The three page screenshots were inspected; the section crops establish the card findings. Commands were not executed.
GUIDANCE: None.

--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/01-approvals.png
--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/02-approvals-content.png
--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/03-approvals-continuous-state.png
--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/hub-profiles@1024.png
--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/hub-profiles@1440.png
--evidence /tmp/tl-dispatch/judge-t-5236-r5-codex-680c44d408a0/tmp/review-T-5236-codex/evidence/hub-profiles@1920.png

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```
