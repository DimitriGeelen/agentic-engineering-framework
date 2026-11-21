# Reviewer evidence — T-5350 AC#1

- dispatch: `judge-t-5350-r3-c5de13c5aa5b`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `83923c96a9518bf7689e63c68d1ec9de9e3cd32a`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `6e46bca0c47b12b15bfdcd0a260150a7cc42c0159e09e3597e3fff2ffa702f3f`
- result.md sha256: `d4c832c0141d842ecdd157f2020e865c52771de4fe7a2257ebff7c93d2f1a292`

## The worker's verdict block

```
## AC1 Designer 0.46.0 shows both requested fixes
Vote: red
Evidence: image: .context/visual/T-5350/designer@1920.png region 1855,7,55,35
Location: .context/visual/T-5350/designer@1920.png region 1855,7,55,35
Evidence: image: .context/visual/T-5350/app@1024.png region 570,510,150,210
Location: .context/visual/T-5350/app@1024.png region 570,510,150,210
Evidence: image: .context/visual/T-5350/designer@1024.png region 0,0,1024,75
Location: .context/visual/T-5350/designer@1024.png region 0,0,1024,75
Evidence: image: .context/visual/T-5350/designer@1440.png region 0,0,1440,75
Location: .context/visual/T-5350/designer@1440.png region 0,0,1440,75
Evidence: image: .context/visual/T-5350/app@1440.png region 1065,510,80,100
Location: .context/visual/T-5350/app@1440.png region 1065,510,80,100
Evidence: image: .context/visual/T-5350/app@1920.png region 250,78,1350,645
Location: .context/visual/T-5350/app@1920.png region 250,78,1350,645
Evidence: image: .context/working/judge-evidence/T-5350/01-designer.png region 280,81,720,738
Location: .context/working/judge-evidence/T-5350/01-designer.png region 280,81,720,738
Evidence: image: .context/working/judge-evidence/T-5350/02-designer-app.png region 249,104,713,646
Location: .context/working/judge-evidence/T-5350/02-designer-app.png region 249,104,713,646
Rule: “Save on the first toolbar row at 1920; starter map readable at 1024,” specifically “labels not clipped or overlapping.”
Conclusion: Save meets the 1920 requirement, but the 1024 starter-map capture cuts off the diagram at the properties panel, hiding downstream nodes and labels, so both fixes are not verified as written.
Guidance: Return the 1024 screenshot to 832 with the clipping at x=704 identified; provide a layout and capture meeting the unclipped-label requirement, or obtain an operator-approved criterion explicitly allowing a partially visible map navigated by scrolling.
  Visual checklist inspection: designer Save is fully inside the frame at 1024 and 1440 on row two, and at 1920 on row one; the modal at 1440 dims the toolbar.
  App at 1024: the visible start, Load context bundle, and Decompose problem labels are readable without overlap, but the downstream map is hidden beyond the canvas boundary.
  App at 1440: search labels are readable, but Synthesize findings is partially cut off at the right boundary; the checklist's unqualified “ok” does not describe an entirely unclipped map.
  App at 1920: the visible main sequence has readable, separated labels.
  The two additional rendered-page captures show a project-picker modal and a partially visible map respectively; neither establishes the required 1024 unclipped map.
  Scrolling reachability cannot be verified from these static images.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-5350
reviewer: codex
round: 1
vote: red
failed: [1]

## AC1 Designer 0.46.0 shows both requested fixes
Vote: red
Evidence: image: .context/visual/T-5350/designer@1920.png region 1855,7,55,35
Location: .context/visual/T-5350/designer@1920.png region 1855,7,55,35
Evidence: image: .context/visual/T-5350/app@1024.png region 570,510,150,210
Location: .context/visual/T-5350/app@1024.png region 570,510,150,210
Evidence: image: .context/visual/T-5350/designer@1024.png region 0,0,1024,75
Location: .context/visual/T-5350/designer@1024.png region 0,0,1024,75
Evidence: image: .context/visual/T-5350/designer@1440.png region 0,0,1440,75
Location: .context/visual/T-5350/designer@1440.png region 0,0,1440,75
Evidence: image: .context/visual/T-5350/app@1440.png region 1065,510,80,100
Location: .context/visual/T-5350/app@1440.png region 1065,510,80,100
Evidence: image: .context/visual/T-5350/app@1920.png region 250,78,1350,645
Location: .context/visual/T-5350/app@1920.png region 250,78,1350,645
Evidence: image: .context/working/judge-evidence/T-5350/01-designer.png region 280,81,720,738
Location: .context/working/judge-evidence/T-5350/01-designer.png region 280,81,720,738
Evidence: image: .context/working/judge-evidence/T-5350/02-designer-app.png region 249,104,713,646
Location: .context/working/judge-evidence/T-5350/02-designer-app.png region 249,104,713,646
Rule: “Save on the first toolbar row at 1920; starter map readable at 1024,” specifically “labels not clipped or overlapping.”
Conclusion: Save meets the 1920 requirement, but the 1024 starter-map capture cuts off the diagram at the properties panel, hiding downstream nodes and labels, so both fixes are not verified as written.
Guidance: Return the 1024 screenshot to 832 with the clipping at x=704 identified; provide a layout and capture meeting the unclipped-label requirement, or obtain an operator-approved criterion explicitly allowing a partially visible map navigated by scrolling.
  Visual checklist inspection: designer Save is fully inside the frame at 1024 and 1440 on row two, and at 1920 on row one; the modal at 1440 dims the toolbar.
  App at 1024: the visible start, Load context bundle, and Decompose problem labels are readable without overlap, but the downstream map is hidden beyond the canvas boundary.
  App at 1440: search labels are readable, but Synthesize findings is partially cut off at the right boundary; the checklist's unqualified “ok” does not describe an entirely unclipped map.
  App at 1920: the visible main sequence has readable, separated labels.
  The two additional rendered-page captures show a project-picker modal and a partially visible map respectively; neither establishes the required 1024 unclipped map.
  Scrolling reachability cannot be verified from these static images.

## Counter-search
Searched: All eight supplied screenshots, including the larger app captures, and the task's Visual Verification checklist.
Found: The 1920 toolbar passes, and visible node labels at 1024 are sharp and separated; however, larger captures reveal downstream nodes absent from the 1024 view, and the checklist itself marks the 1024 starter map “clipped.” No supplied image demonstrates those hidden labels becoming reachable through scrolling. Reported 404 errors were not used as grounds for this visual verdict.

## Change-my-mind
A supplied 1024 px /designer/app capture showing the starter-map labels readable without clipping or overlap, or an operator-approved restatement allowing viewport clipping accompanied by evidence that the remaining map is reachable.
===END===
```
