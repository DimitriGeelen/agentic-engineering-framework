# Reviewer evidence — T-5351 AC#1

- dispatch: `judge-t-5351-r5-antigravity-6f3eb488a947`
- worker kind: `antigravity` (vendor `google`, model `worker default`)
- seat: `antigravity`
- reviewed revision: `e2c4cce50ddbeb0160731267bed81c66b3f14af4`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `b270c28dc6f2e6799fe822e329c92c624db360ebba14deaf6076a75bd0bfbbe6`
- result.md sha256: `995f5ed7ae268af4ae1804a91842a2dba640605613cd9a7da82006183227dc49`

## The worker's verdict block

```
## AC1 The /config page shows the new SIDECAR_W1_PROMPT_ORIGIN row like its neighbours
Vote: green
Evidence: image: .context/working/judge-evidence/T-5351/01-config.png region 40,4375,1200,114
Location: .context/working/judge-evidence/T-5351/01-config.png region 40,4375,1200,114
Evidence: image: .context/visual/T-5351/config@1024.png region 37,5493,950,162
Location: .context/visual/T-5351/config@1024.png region 37,5493,950,162
Evidence: image: .context/visual/T-5351/config@1440.png region 120,4375,1200,114
Location: .context/visual/T-5351/config@1440.png region 120,4375,1200,114
Evidence: image: .context/visual/T-5351/config@1920.png region 235,3967,1450,90
Location: .context/visual/T-5351/config@1920.png region 235,3967,1450,90
Evidence: "1 = in a project that runs TermLink's own W1 sidecar hooks (adapter/2 off by its w1-guard), the prompt hook sends exactly one adapter/2 prompt_submit (250 ms) so the main claim carries the receiver-checked origin; a failure claims origin unknown (T-5351, 010-termlink T-3694). 0 (default) = claim as before"
Location: web/blueprints/config.py:58
Rule: criterion: "One row, default 0, the description readable and laid out like the rows around it; no broken table" and Visual Verification checklist `config | SIDECAR_W1_PROMPT_ORIGIN row | ok | ok | ok` across 1024, 1440, and 1920 px
Conclusion: All four captures (1024, 1280, 1440, and 1920 px) show a single `FW_SIDECAR_W1_PROMPT_ORIGIN` row with current and default `0`, source `DEFAULT`, and the full readable description from `web/blueprints/config.py:58` aligned cleanly with its neighbouring rows and intact table borders, with zero console or page errors.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-5351
reviewer: antigravity
round: 1
vote: green
failed: []

## AC1 The /config page shows the new SIDECAR_W1_PROMPT_ORIGIN row like its neighbours
Vote: green
Evidence: image: .context/working/judge-evidence/T-5351/01-config.png region 40,4375,1200,114
Location: .context/working/judge-evidence/T-5351/01-config.png region 40,4375,1200,114
Evidence: image: .context/visual/T-5351/config@1024.png region 37,5493,950,162
Location: .context/visual/T-5351/config@1024.png region 37,5493,950,162
Evidence: image: .context/visual/T-5351/config@1440.png region 120,4375,1200,114
Location: .context/visual/T-5351/config@1440.png region 120,4375,1200,114
Evidence: image: .context/visual/T-5351/config@1920.png region 235,3967,1450,90
Location: .context/visual/T-5351/config@1920.png region 235,3967,1450,90
Evidence: "1 = in a project that runs TermLink's own W1 sidecar hooks (adapter/2 off by its w1-guard), the prompt hook sends exactly one adapter/2 prompt_submit (250 ms) so the main claim carries the receiver-checked origin; a failure claims origin unknown (T-5351, 010-termlink T-3694). 0 (default) = claim as before"
Location: web/blueprints/config.py:58
Rule: criterion: "One row, default 0, the description readable and laid out like the rows around it; no broken table" and Visual Verification checklist `config | SIDECAR_W1_PROMPT_ORIGIN row | ok | ok | ok` across 1024, 1440, and 1920 px
Conclusion: All four captures (1024, 1280, 1440, and 1920 px) show a single `FW_SIDECAR_W1_PROMPT_ORIGIN` row with current and default `0`, source `DEFAULT`, and the full readable description from `web/blueprints/config.py:58` aligned cleanly with its neighbouring rows and intact table borders, with zero console or page errors.

## Counter-search
Searched: full-page captures at 1024, 1280, 1440, and 1920 px (including top summary cards, surrounding rows `FW_TERMLINK_ADAPTER2` and `FW_TERMLINK_MAX_WORKERS`, bottom Custom Settings table, and footer), plus `web/blueprints/config.py`, `lib/config.sh`, and `web/templates/config.html` for duplicate entries, wrong defaults, clipping, overlap, or table breakage
Found: `SIDECAR_W1_PROMPT_ORIGIN` appears once among the 105 settings (index 43) and is absent from Custom Settings; the row is visible, unclipped, and non-overlapping at all four widths; the wrapped `FW_*` env-var code pill and `DEFAU`/`LT` badge stem from pre-existing `.config-table td { overflow-wrap: anywhere; }` (`web/templates/config.html:52-54`) and render identically on every neighbouring default row

## Change-my-mind
A capture of `/config` at 1024, 1280, 1440, or 1920 px where `FW_SIDECAR_W1_PROMPT_ORIGIN` is missing or duplicated, shows a default other than `0`, has clipped or overlapping description text, or misaligns the five table columns relative to its neighbouring rows.
===END===

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```
