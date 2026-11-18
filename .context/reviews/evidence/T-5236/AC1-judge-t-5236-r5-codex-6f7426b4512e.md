# Reviewer evidence — T-5236 AC#1

- dispatch: `judge-t-5236-r5-codex-6f7426b4512e`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `6949f1077eaf81ff22c3eb9689c3a14f5941efeb`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `bbfe350b8fdf3f65453941c519b14f9c2d83fa9f1f49d9939e38c789f72c8a11`
- result.md sha256: `1746d5249018c51e2b41a40b75bbc42c249f028c244e8cac9e28b1522c0e4233`

## The worker's verdict block

```
1. [AC] Hub profile cards communicate identity, hub, waiting count, and fix
VERDICT: not-evaluated
WHY: cannot view the uncaptured page /opt/999-Agentic-Engineering-Framework/.context/visual/T-5236/, explicitly identified as missing in the partial-capture instructions. I opened all six supplied screenshots. The three hub-profile crops show both cards clearly at 1024, 1440, and 1920 pixels: user, host, hub, waiting count, configuration instructions, prepared bash command, and underlying command are visible without clipping or overlap. The other three screenshots do not show this section. The explicit partial-capture restriction prevents a green verdict.
GUIDANCE: Route to a reviewer with the missing page evidence, or resolve the capture restriction so the supplied hub-profile crops can establish this criterion.
--evidence .context/working/judge-evidence/T-5236/02-approvals.png
--evidence .context/working/judge-evidence/T-5236/03-approvals-content.png
--evidence .context/working/judge-evidence/T-5236/04-approvals-continuous-state.png
--evidence .context/visual/T-5236/hub-profiles@1024.png
--evidence .context/visual/T-5236/hub-profiles@1440.png
--evidence .context/visual/T-5236/hub-profiles@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Hub profile cards communicate identity, hub, waiting count, and fix
VERDICT: not-evaluated
WHY: cannot view the uncaptured page `/opt/999-Agentic-Engineering-Framework/.context/visual/T-5236/`, explicitly identified as missing in the partial-capture instructions. I opened all six supplied screenshots. The three hub-profile crops show both cards clearly at 1024, 1440, and 1920 pixels: user, host, hub, waiting count, configuration instructions, prepared bash command, and underlying command are visible without clipping or overlap. The other three screenshots do not show this section. The explicit partial-capture restriction prevents a green verdict.
GUIDANCE: Route to a reviewer with the missing page evidence, or resolve the capture restriction so the supplied hub-profile crops can establish this criterion.
--evidence .context/working/judge-evidence/T-5236/02-approvals.png
--evidence .context/working/judge-evidence/T-5236/03-approvals-content.png
--evidence .context/working/judge-evidence/T-5236/04-approvals-continuous-state.png
--evidence .context/visual/T-5236/hub-profiles@1024.png
--evidence .context/visual/T-5236/hub-profiles@1440.png
--evidence .context/visual/T-5236/hub-profiles@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
