# Reviewer evidence — T-5350 AC#1

- dispatch: `judge-t-5350-r3-ca1e3491a6d8`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `d158b34edb8c5dd01d44596f53283b6bcfb7792d`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `8e3841f3d2f05ec08bde2fc11c62cd8c2fb673b3f05298c8f383795799d1a155`
- result.md sha256: `ef20542a5672d9927c261dc2636979169949fc7ad331ac8a415360e390fd7543`

## The worker's verdict block

```
## AC1 Designer 0.46.0 shows both requested fixes
Vote: green
Evidence: image: .context/visual/T-5350/designer@1920.png region 1858,9,48,29
Location: .context/visual/T-5350/designer@1920.png region 1858,9,48,29
Evidence: image: .context/visual/T-5350/app@1024.png region 249,104,455,614
Location: .context/visual/T-5350/app@1024.png region 249,104,455,614
Evidence: image: .context/visual/T-5350/designer@1024.png region 0,0,1024,75
Location: .context/visual/T-5350/designer@1024.png region 0,0,1024,75
Evidence: image: .context/visual/T-5350/designer@1440.png region 0,0,1440,75
Location: .context/visual/T-5350/designer@1440.png region 0,0,1440,75
Evidence: image: .context/visual/T-5350/app@1440.png region 249,104,871,614
Location: .context/visual/T-5350/app@1440.png region 249,104,871,614
Evidence: image: .context/visual/T-5350/app@1920.png region 249,77,1351,614
Location: .context/visual/T-5350/app@1920.png region 249,77,1351,614
Evidence: image: .context/working/judge-evidence/T-5350/01-designer.png region 0,0,1280,900
Location: .context/working/judge-evidence/T-5350/01-designer.png region 0,0,1280,900
Evidence: image: .context/working/judge-evidence/T-5350/02-designer-app.png region 249,104,711,614
Location: .context/working/judge-evidence/T-5350/02-designer-app.png region 249,104,711,614
Rule: Save must be on the first toolbar row inside the frame at 1920; at 1024 the starter map must show its top-left, start event and first steps with sharp, nonoverlapping labels; continuation beyond the canvas edge is explicitly expected.
Conclusion: The 1920 designer capture shows Save fully inside the first toolbar row, and the 1024 app capture shows Investigation requested, Load context bundle and Decompose problem clearly from the map’s top-left without overlapping labels, satisfying both visual requirements.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-5350
reviewer: /root
round: 1
vote: green
failed: []

## AC1 Designer 0.46.0 shows both requested fixes
Vote: green
Evidence: image: .context/visual/T-5350/designer@1920.png region 1858,9,48,29
Location: .context/visual/T-5350/designer@1920.png region 1858,9,48,29
Evidence: image: .context/visual/T-5350/app@1024.png region 249,104,455,614
Location: .context/visual/T-5350/app@1024.png region 249,104,455,614
Evidence: image: .context/visual/T-5350/designer@1024.png region 0,0,1024,75
Location: .context/visual/T-5350/designer@1024.png region 0,0,1024,75
Evidence: image: .context/visual/T-5350/designer@1440.png region 0,0,1440,75
Location: .context/visual/T-5350/designer@1440.png region 0,0,1440,75
Evidence: image: .context/visual/T-5350/app@1440.png region 249,104,871,614
Location: .context/visual/T-5350/app@1440.png region 249,104,871,614
Evidence: image: .context/visual/T-5350/app@1920.png region 249,77,1351,614
Location: .context/visual/T-5350/app@1920.png region 249,77,1351,614
Evidence: image: .context/working/judge-evidence/T-5350/01-designer.png region 0,0,1280,900
Location: .context/working/judge-evidence/T-5350/01-designer.png region 0,0,1280,900
Evidence: image: .context/working/judge-evidence/T-5350/02-designer-app.png region 249,104,711,614
Location: .context/working/judge-evidence/T-5350/02-designer-app.png region 249,104,711,614
Rule: Save must be on the first toolbar row inside the frame at 1920; at 1024 the starter map must show its top-left, start event and first steps with sharp, nonoverlapping labels; continuation beyond the canvas edge is explicitly expected.
Conclusion: The 1920 designer capture shows Save fully inside the first toolbar row, and the 1024 app capture shows Investigation requested, Load context bundle and Decompose problem clearly from the map’s top-left without overlapping labels, satisfying both visual requirements.

## Counter-search
Searched: All eight supplied images, including toolbar boundaries and map labels at every supplied width, against the two checklist controls in .tasks/active/T-5350-take-designer-0460-832-pin-bump-verify-t.md:308-323.
Found: Save is fully visible on row two at 1024 and 1440 and row one at 1920; the 1440 designer modal dims the underlying toolbar but does not crop Save. The app map continues beyond the canvas at 1024, and Synthesize findings is clipped at 1440, matching the checklist’s explicit exceptions. At 1920 the main branching and synthesis sequence is readable. The additional 1280 captures show a project picker and readable starter-map content respectively. Reported 404 errors do not establish a failure of either visual requirement. Screenshots establish appearance, not operation of scrolling or Fit; neither interaction was rerun.

## Change-my-mind
A supplied 1920 designer image showing Save wrapped or outside the frame, or a 1024 app image showing the start event or first steps missing, blurred, or overlapped, would change this verdict.
===END===
```
