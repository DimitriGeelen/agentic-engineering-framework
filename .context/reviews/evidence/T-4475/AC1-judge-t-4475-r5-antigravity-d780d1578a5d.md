# Reviewer evidence — T-4475 AC#1

- dispatch: `judge-t-4475-r5-antigravity-d780d1578a5d`
- worker kind: `antigravity` (vendor `google`, model `worker default`)
- seat: `antigravity`
- reviewed revision: `c110a06ac224685cfb443fd41b7b8b01a1e78204`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `8a183be9946e7ddba66b7001a5fa94a75d62118ef1385f9ce9091042ec14d99e`
- result.md sha256: `f8c695610059d20f3d0d68eb5742fb2730a636eb2f8164b01da53a8e29ea193d`

## The worker's verdict block

```
## AC1 The new EMBED_WORKERS row on /config reads clearly next to its neighbours
Vote: amber
Evidence: image: .context/working/judge-evidence/T-4475/01-config.png region 56,7062,1124,89
Location: .context/working/judge-evidence/T-4475/01-config.png region 56,7062,1124,89
Evidence: image: .context/visual/T-4475/config@1024.png region 53,5855,902,137
Location: .context/visual/T-4475/config@1024.png region 53,5855,902,137
Evidence: image: .context/visual/T-4475/config@1440.png region 136,4905,1102,89
Location: .context/visual/T-4475/config@1440.png region 136,4905,1102,89
Evidence: image: .context/visual/T-4475/config@1920.png region 251,4240,1394,89
Location: .context/visual/T-4475/config@1920.png region 251,4240,1394,89
Evidence: "overflow-wrap: anywhere;"
Location: web/templates/config.html:53
Evidence: "Concurrent embed requests the vector reindex sends to the bulk embedding host (web/embeddings.py:_embed_batches; order preserved). Match it to the server's OLLAMA_NUM_PARALLEL; 1 is serial. Malformed or <1 means 1; T-4475"
Location: web/blueprints/config.py:96
Rule: criterion: "The new EMBED_WORKERS row on /config reads clearly next to its neighbours" and "default `1`; the description says it sets concurrent embed requests during reindex, to match the server's OLLAMA_NUM_PARALLEL, and that 1 is serial; the row's layout matches its neighbours"
Conclusion: Although the EMBED_WORKERS row displays default `1`, the required unclipped description text, and no horizontal overflow at 1024/1280/1440/1920 px, applying `overflow-wrap: anywhere;` to every `.config-table td` at web/templates/config.html:53 collapses the Source and Env Var columns across all widths so the row's `DEFAULT` badge splits into `DEFAU` / `LT` at 1024, 1280, 1440, and 1920 px and `FW_EMBED_WORKERS` breaks mid-word (`FW_EMBED_W` / `ORKERS` at 1280 and 1440 px, `FW_EMBED_WORK` / `ERS` at 1920 px), preventing it from reading cleanly.
Guidance: In `web/templates/config.html`, add `white-space: nowrap;` to `.source-badge` (lines 23-31) so `DEFAULT` stays on one line, and restrict `overflow-wrap: anywhere;` at lines 52-54 away from the Source and Env Var columns (for example, scope `overflow-wrap: anywhere;` to `.config-table td:nth-child(2), .config-table td:nth-child(5)` and use `overflow-wrap: break-word;` or a readable column width for Env Var so `FW_EMBED_WORKERS` does not split mid-word while keeping `table.scrollWidth <= container.clientWidth` at 1024 px); then re-capture `.context/visual/T-4475/config@{1024,1440,1920}.png`.
```

## The worker's full output (result.md)

```
```
===VERDICT===
format: verdict/1
task: T-4475
reviewer: antigravity
round: 1
vote: amber
failed: [1]

## AC1 The new EMBED_WORKERS row on /config reads clearly next to its neighbours
Vote: amber
Evidence: image: .context/working/judge-evidence/T-4475/01-config.png region 56,7062,1124,89
Location: .context/working/judge-evidence/T-4475/01-config.png region 56,7062,1124,89
Evidence: image: .context/visual/T-4475/config@1024.png region 53,5855,902,137
Location: .context/visual/T-4475/config@1024.png region 53,5855,902,137
Evidence: image: .context/visual/T-4475/config@1440.png region 136,4905,1102,89
Location: .context/visual/T-4475/config@1440.png region 136,4905,1102,89
Evidence: image: .context/visual/T-4475/config@1920.png region 251,4240,1394,89
Location: .context/visual/T-4475/config@1920.png region 251,4240,1394,89
Evidence: "overflow-wrap: anywhere;"
Location: web/templates/config.html:53
Evidence: "Concurrent embed requests the vector reindex sends to the bulk embedding host (web/embeddings.py:_embed_batches; order preserved). Match it to the server's OLLAMA_NUM_PARALLEL; 1 is serial. Malformed or <1 means 1; T-4475"
Location: web/blueprints/config.py:96
Rule: criterion: "The new EMBED_WORKERS row on /config reads clearly next to its neighbours" and "default `1`; the description says it sets concurrent embed requests during reindex, to match the server's OLLAMA_NUM_PARALLEL, and that 1 is serial; the row's layout matches its neighbours"
Conclusion: Although the EMBED_WORKERS row displays default `1`, the required unclipped description text, and no horizontal overflow at 1024/1280/1440/1920 px, applying `overflow-wrap: anywhere;` to every `.config-table td` at web/templates/config.html:53 collapses the Source and Env Var columns across all widths so the row's `DEFAULT` badge splits into `DEFAU` / `LT` at 1024, 1280, 1440, and 1920 px and `FW_EMBED_WORKERS` breaks mid-word (`FW_EMBED_W` / `ORKERS` at 1280 and 1440 px, `FW_EMBED_WORK` / `ERS` at 1920 px), preventing it from reading cleanly.
Guidance: In `web/templates/config.html`, add `white-space: nowrap;` to `.source-badge` (lines 23-31) so `DEFAULT` stays on one line, and restrict `overflow-wrap: anywhere;` at lines 52-54 away from the Source and Env Var columns (for example, scope `overflow-wrap: anywhere;` to `.config-table td:nth-child(2), .config-table td:nth-child(5)` and use `overflow-wrap: break-word;` or a readable column width for Env Var so `FW_EMBED_WORKERS` does not split mid-word while keeping `table.scrollWidth <= container.clientWidth` at 1024 px); then re-capture `.context/visual/T-4475/config@{1024,1440,1920}.png`.

## Counter-search
Searched: all four supplied screenshots (`01-config.png` at 1280 px and `config@{1024,1440,1920}.png`), `web/blueprints/config.py`, `lib/config.sh`, `web/templates/config.html`, and the Visual Verification table in `.tasks/active/T-4475-adapt-termlink-proposal-344-webembedding.md` to verify whether `DEFAU / LT` and mid-word `FW_EMBED_WORKERS` wrapping were pre-existing or limited to narrow viewports
Found: T-4475's own Visual Verification note confirms T-4475 introduced `overflow-wrap: anywhere` on `.config-table td` (web/templates/config.html:52-54); the `DEFAULT` badge is crushed to 56-59 px and split into `DEFAU / LT` at every width including 1920 px (where Description is 851 px wide), and `FW_EMBED_WORKERS` breaks mid-word at 1280, 1440, and 1920 px; all other checks pass (default `1`, accurate unclipped description, zero overlap, zero console/page errors).

## Change-my-mind
Screenshots at 1024, 1280, 1440, and 1920 px where the `EMBED_WORKERS` row's `Source` badge renders `DEFAULT` on a single line, `FW_EMBED_WORKERS` does not split mid-word at 1280/1440/1920 px, and the Description column remains unclipped with no horizontal overflow at 1024 px.
===END===
```

Summary: 0 green, 1 amber, 0 red, 0 escalate, 0 not-evaluated
```
