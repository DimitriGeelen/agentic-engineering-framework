# Reviewer evidence — T-4490 AC#1

- dispatch: `judge-t-4490-r5-codex-a91db04b56f7`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `7528a69d47aa187d279ab9f4a430811641485ce8`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `ad8179bfd969f76ef5bcd8ee6dae7a2c67bd8df0a86e2172d2d2b9d9c14808ee`
- result.md sha256: `a410887353116df93adf13383cd0965cc0ed2e3b1228d17760d33764c89f22b2`

## The worker's verdict block

```
## AC1 Degraded-review configuration row
Vote: green
Evidence: image: .context/working/judge-evidence/T-4490/01-config.png region 0,10603,1280,1048
Location: .context/working/judge-evidence/T-4490/01-config.png region 0,10603,1280,1048
Evidence: image: .context/visual/T-4490/config@1024.png region 0,16859,1024,1666
Location: .context/visual/T-4490/config@1024.png region 0,16859,1024,1666
Evidence: image: .context/visual/T-4490/config@1440.png region 0,10603,1440,1048
Location: .context/visual/T-4490/config@1440.png region 0,10603,1440,1048
Evidence: image: .context/visual/T-4490/config@1920.png region 0,8357,1920,826
Location: .context/visual/T-4490/config@1920.png region 0,8357,1920,826
Rule: Default is 1; description names the opt-out and says every degraded close is WARNed and counted weekly by fw audit; layout matches neighbouring rows and remains visible and unclipped at all checklist widths.
Conclusion: All four screenshots show the row immediately below the spend-ceiling row, with default 1, explicit “Set 0 to opt out” and weekly audit-warning wording, aligned columns and fully visible text without clipping or overlap.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-4490
reviewer: codex
round: 1
vote: green
failed: []

## AC1 Degraded-review configuration row
Vote: green
Evidence: image: .context/working/judge-evidence/T-4490/01-config.png region 0,10603,1280,1048
Location: .context/working/judge-evidence/T-4490/01-config.png region 0,10603,1280,1048
Evidence: image: .context/visual/T-4490/config@1024.png region 0,16859,1024,1666
Location: .context/visual/T-4490/config@1024.png region 0,16859,1024,1666
Evidence: image: .context/visual/T-4490/config@1440.png region 0,10603,1440,1048
Location: .context/visual/T-4490/config@1440.png region 0,10603,1440,1048
Evidence: image: .context/visual/T-4490/config@1920.png region 0,8357,1920,826
Location: .context/visual/T-4490/config@1920.png region 0,8357,1920,826
Rule: Default is 1; description names the opt-out and says every degraded close is WARNed and counted weekly by fw audit; layout matches neighbouring rows and remains visible and unclipped at all checklist widths.
Conclusion: All four screenshots show the row immediately below the spend-ceiling row, with default 1, explicit “Set 0 to opt out” and weekly audit-warning wording, aligned columns and fully visible text without clipping or overlap.

## Counter-search
Searched: All four supplied screenshots, with enlarged inspection of the target row and its neighbours, checking default values, missing wording, column alignment, wrapping, clipping and overlap.
Found: At 1024 pixels the description wraps into more lines, but remains complete within its row; the 1440- and 1920-pixel checklist captures and the rendered-page capture also meet the requirement.

## Change-my-mind
A supplied capture showing a missing opt-out or weekly warning statement, a default other than 1, or target-row text clipped or overlapping neighbouring cells would change this verdict.
===END===
```
