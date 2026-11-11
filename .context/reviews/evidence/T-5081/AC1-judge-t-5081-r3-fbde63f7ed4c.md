# Reviewer evidence — T-5081 AC#1

- dispatch: `judge-t-5081-r3-fbde63f7ed4c`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `aac9320726ce1ddfa6e9e0fe9128b18e54f8a687`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `455469bd9afa10dc39c0c4f8be79a759960a5f9c4783cfdd4ac55160093ef706`
- result.md sha256: `87e56233a792e8c6850f5b111aae5f5a1cd571c652045c6e14c7bb17f9294dfa`

## The worker's verdict block

```
1. [AC] The hand-back note reads clearly when you tick your last check
VERDICT: not-evaluated
WHY: Inspected both supplied screenshots. The review page shows an already checked criterion, but no hand-back note or untick transition. The tasks screenshot shows only the page top. Source wording in web/blueprints/tasks.py:1332–1333 describes both transitions, but does not establish their rendered appearance. Required screenshots .context/visual/T-5081/last-tick@1024.png, last-tick@1440.png, and last-tick@1920.png are missing.
GUIDANCE: Provide last-tick screenshots at all three required widths and rendered evidence after unticking. Verify that each note appears beside the checkbox and clearly communicates who acts next.
--evidence /tmp/tl-dispatch/judge-t-5081-r3-fbde63f7ed4c/tmp/T-5081-review-evidence/01-review-t-5079.png
--evidence /tmp/tl-dispatch/judge-t-5081-r3-fbde63f7ed4c/tmp/T-5081-review-evidence/02-tasks.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] The hand-back note reads clearly when you tick your last check
VERDICT: not-evaluated
WHY: Inspected both supplied screenshots. The review page shows an already checked criterion, but no hand-back note or untick transition. The tasks screenshot shows only the page top. Source wording in `web/blueprints/tasks.py:1332–1333` describes both transitions, but does not establish their rendered appearance. Required screenshots `.context/visual/T-5081/last-tick@1024.png`, `last-tick@1440.png`, and `last-tick@1920.png` are missing.
GUIDANCE: Provide last-tick screenshots at all three required widths and rendered evidence after unticking. Verify that each note appears beside the checkbox and clearly communicates who acts next.
--evidence /tmp/tl-dispatch/judge-t-5081-r3-fbde63f7ed4c/tmp/T-5081-review-evidence/01-review-t-5079.png
--evidence /tmp/tl-dispatch/judge-t-5081-r3-fbde63f7ed4c/tmp/T-5081-review-evidence/02-tasks.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
