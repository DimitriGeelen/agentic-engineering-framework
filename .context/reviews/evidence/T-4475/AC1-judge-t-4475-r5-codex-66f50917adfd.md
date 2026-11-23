# Reviewer evidence — T-4475 AC#1

- dispatch: `judge-t-4475-r5-codex-66f50917adfd`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `1e799c0abfdd1acdac36dcb3e55f90e2abdd7719`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `1329f67d01ab9c0dcaa8bbf51feaf1eab145eab21c1344646b76234aa7574992`
- result.md sha256: `1df3090d05a217f8f58010e93744cfc49b9d14cf503c8b40adb3d83689a9c44f`

## The worker's verdict block

```
## AC1 EMBED_WORKERS row reads clearly next to its neighbours
Vote: green
Evidence: image: .context/working/judge-evidence/T-4475/01-config.png region 40,7730,1200,364
Location: .context/working/judge-evidence/T-4475/01-config.png region 40,7730,1200,364
Evidence: image: .context/visual/T-4475/config@1024.png region 37,12532,950,568
Location: .context/visual/T-4475/config@1024.png region 37,12532,950,568
Evidence: image: .context/visual/T-4475/config@1440.png region 120,7730,1200,364
Location: .context/visual/T-4475/config@1440.png region 120,7730,1200,364
Evidence: image: .context/visual/T-4475/config@1920.png region 235,6099,1450,268
Location: .context/visual/T-4475/config@1920.png region 235,6099,1450,268
Rule: Default is 1; description explains concurrent embed requests during reindex, matching OLLAMA_NUM_PARALLEL, and 1 being serial; layout matches neighbouring rows at 1024, 1440 and 1920.
Conclusion: All four screenshots show default 1 and the required explanation, with aligned columns, intact variable names and source badges, and a fully visible description without clipping or overlap.
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

## AC1 EMBED_WORKERS row reads clearly next to its neighbours
Vote: green
Evidence: image: .context/working/judge-evidence/T-4475/01-config.png region 40,7730,1200,364
Location: .context/working/judge-evidence/T-4475/01-config.png region 40,7730,1200,364
Evidence: image: .context/visual/T-4475/config@1024.png region 37,12532,950,568
Location: .context/visual/T-4475/config@1024.png region 37,12532,950,568
Evidence: image: .context/visual/T-4475/config@1440.png region 120,7730,1200,364
Location: .context/visual/T-4475/config@1440.png region 120,7730,1200,364
Evidence: image: .context/visual/T-4475/config@1920.png region 235,6099,1450,268
Location: .context/visual/T-4475/config@1920.png region 235,6099,1450,268
Rule: Default is 1; description explains concurrent embed requests during reindex, matching OLLAMA_NUM_PARALLEL, and 1 being serial; layout matches neighbouring rows at 1024, 1440 and 1920.
Conclusion: All four screenshots show default 1 and the required explanation, with aligned columns, intact variable names and source badges, and a fully visible description without clipping or overlap.

## Counter-search
Searched: Inspected EMBED_WORKERS and its immediate neighbours in every supplied screenshot, particularly the description’s right edge and long identifiers at 1024.
Found: At 1024 the implementation reference wraps within its identifier, but remains readable and contained; OLLAMA_NUM_PARALLEL, FW_EMBED_WORKERS and DEFAULT remain intact, and spacing matches neighbouring rows.

## Change-my-mind
A supplied-width capture showing clipped description text, overlapping columns, a split variable name or source badge, or a default other than 1 would change this verdict.
===END===
```
