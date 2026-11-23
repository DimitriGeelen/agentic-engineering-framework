# Reviewer evidence — T-4475 AC#1

- dispatch: `judge-t-4475-r5-codex-9d6921b9f44b`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `c110a06ac224685cfb443fd41b7b8b01a1e78204`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `a6aadb09f3e01c2ed42e36fe3f052e15bc5c5fbb69481671dfaee3727b7f5e75`
- result.md sha256: `44c14fef4eaa29028dabb062669298d7b3c550fac1aa79126a8cc3ad688321ec`

## The worker's verdict block

```
## AC1 EMBED_WORKERS reads clearly next to its neighbours
Vote: green
Evidence: image: .context/working/judge-evidence/T-4475/01-config.png region 40,7062,1200,90
Location: .context/working/judge-evidence/T-4475/01-config.png region 40,7062,1200,90
Evidence: image: .context/visual/T-4475/config@1024.png region 37,5855,950,138
Location: .context/visual/T-4475/config@1024.png region 37,5855,950,138
Evidence: image: .context/visual/T-4475/config@1440.png region 120,4905,1200,90
Location: .context/visual/T-4475/config@1440.png region 120,4905,1200,90
Evidence: image: .context/visual/T-4475/config@1920.png region 235,4240,1450,90
Location: .context/visual/T-4475/config@1920.png region 235,4240,1450,90
Rule: Default is 1; description explains concurrent embed requests during reindex, matching OLLAMA_NUM_PARALLEL, and serial operation at 1; layout matches neighbouring rows.
Conclusion: All four screenshots show default 1 and the required explanation, with consistent column alignment and wrapping, and the checklist’s EMBED_WORKERS row remains visible and unclipped without overlap at 1024, 1440, and 1920 pixels.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-4475
reviewer: codex
round: 1
vote: green
failed: []

## AC1 EMBED_WORKERS reads clearly next to its neighbours
Vote: green
Evidence: image: .context/working/judge-evidence/T-4475/01-config.png region 40,7062,1200,90
Location: .context/working/judge-evidence/T-4475/01-config.png region 40,7062,1200,90
Evidence: image: .context/visual/T-4475/config@1024.png region 37,5855,950,138
Location: .context/visual/T-4475/config@1024.png region 37,5855,950,138
Evidence: image: .context/visual/T-4475/config@1440.png region 120,4905,1200,90
Location: .context/visual/T-4475/config@1440.png region 120,4905,1200,90
Evidence: image: .context/visual/T-4475/config@1920.png region 235,4240,1450,90
Location: .context/visual/T-4475/config@1920.png region 235,4240,1450,90
Rule: Default is 1; description explains concurrent embed requests during reindex, matching OLLAMA_NUM_PARALLEL, and serial operation at 1; layout matches neighbouring rows.
Conclusion: All four screenshots show default 1 and the required explanation, with consistent column alignment and wrapping, and the checklist’s EMBED_WORKERS row remains visible and unclipped without overlap at 1024, 1440, and 1920 pixels.

## Counter-search
Searched: All four screenshots, examining the EMBED_WORKERS row and adjacent rows for clipped descriptions, overlapping columns, missing values, and inconsistent spacing.
Found: Long identifiers and source badges wrap within their columns consistently with neighbouring rows; the complete description remains readable at every supplied width.

## Change-my-mind
A supplied-width screenshot showing missing description text, a default other than 1, or EMBED_WORKERS content clipped or overlapping an adjacent column would change this verdict.
===END===
```
