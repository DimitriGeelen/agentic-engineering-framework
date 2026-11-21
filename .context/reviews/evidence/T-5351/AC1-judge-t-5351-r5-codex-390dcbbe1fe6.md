# Reviewer evidence — T-5351 AC#1

- dispatch: `judge-t-5351-r5-codex-390dcbbe1fe6`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `e2c4cce50ddbeb0160731267bed81c66b3f14af4`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `0b47a9714dac4e1570462fb4330e323e1331fcaa0f84d9eee6bfeae394bd3eb8`
- result.md sha256: `a3f7621f9bbdddd9e465cbc3be19432a48e351f9a65d346fc38c012cbfda186b`

## The worker's verdict block

```
## AC1 The /config page shows the new SIDECAR_W1_PROMPT_ORIGIN row like its neighbours
Vote: green
Evidence: image: .context/working/judge-evidence/T-5351/01-config.png region 40,4375,1200,113
Location: .context/working/judge-evidence/T-5351/01-config.png region 40,4375,1200,113
Evidence: image: .context/visual/T-5351/config@1024.png region 37,5494,950,161
Location: .context/visual/T-5351/config@1024.png region 37,5494,950,161
Evidence: image: .context/visual/T-5351/config@1440.png region 120,4375,1200,113
Location: .context/visual/T-5351/config@1440.png region 120,4375,1200,113
Evidence: image: .context/visual/T-5351/config@1920.png region 235,3967,1450,90
Location: .context/visual/T-5351/config@1920.png region 235,3967,1450,90
Rule: “One row, default 0, the description readable and laid out like the rows around it; no broken table.”
Conclusion: Each screenshot shows one FW_SIDECAR_W1_PROMPT_ORIGIN row with default 0, a fully readable description, and consistent neighbouring column alignment and row boundaries without clipping or overlap.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-5351
reviewer: codex
round: 1
vote: green
failed: []

## AC1 The /config page shows the new SIDECAR_W1_PROMPT_ORIGIN row like its neighbours
Vote: green
Evidence: image: .context/working/judge-evidence/T-5351/01-config.png region 40,4375,1200,113
Location: .context/working/judge-evidence/T-5351/01-config.png region 40,4375,1200,113
Evidence: image: .context/visual/T-5351/config@1024.png region 37,5494,950,161
Location: .context/visual/T-5351/config@1024.png region 37,5494,950,161
Evidence: image: .context/visual/T-5351/config@1440.png region 120,4375,1200,113
Location: .context/visual/T-5351/config@1440.png region 120,4375,1200,113
Evidence: image: .context/visual/T-5351/config@1920.png region 235,3967,1450,90
Location: .context/visual/T-5351/config@1920.png region 235,3967,1450,90
Rule: “One row, default 0, the description readable and laid out like the rows around it; no broken table.”
Conclusion: Each screenshot shows one FW_SIDECAR_W1_PROMPT_ORIGIN row with default 0, a fully readable description, and consistent neighbouring column alignment and row boundaries without clipping or overlap.

## Counter-search
Searched: All four supplied full-page screenshots and enlarged target-row regions, comparing the target with TERMLINK_ADAPTER2 above and TERMLINK_MAX_WORKERS below.
Found: Narrow widths wrap setting names and DEFAULT badges like neighbouring rows, but preserve complete text, separate columns, and readable descriptions; no duplicate target row or broken table was visible.

## Change-my-mind
A supplied capture showing a second target row, a nonzero default, clipped description text, or target-row content overlapping neighbouring cells would change this verdict.
===END===
```
