# T-4355 Human AC#1 — ABSENT_COMPONENTS on Watchtower /config (reviewer judge-t-4355-r3-55f89dbab33f)

Revision reviewed: be5bf5b9159e8c459307f7175e311e700ceac785

## Source checked (at be5bf5b91)
- lib/config.sh:265 — `"ABSENT_COMPONENTS||Optional components this project leaves out on purpose, space- or comma-separated: termlink node bats shellcheck pi ollama litellm. fw doctor reports each as OK (absent by choice) instead of WARN; a workflow that needs one still WARNs, and an unknown name WARNs (T-4355, GitHub #98)"` — default field empty.
- web/blueprints/config.py:22 — same key, default "", identical description.

## Screenshots read (all four, row cropped at full resolution for 1024 and 1920)
- 01-config-judge-t-4355-r3-55f89dbab33f.png (judge capture, 1280 wide; browser reported no console/page errors)
- config-1024-judge-t-4355-r3-55f89dbab33f.png, config-1440-judge-t-4355-r3-55f89dbab33f.png, config-1920-judge-t-4355-r3-55f89dbab33f.png

At every width the row FW_ABSENT_COMPONENTS (the page shows every key with its FW_ env prefix) sits between FW_RELEASE_ARTIFACT_PATHS and FW_HOST. Current: empty. Default: empty. Source: DEFAULT. Description fully visible, not clipped, no overlap, wraps cleanly in the description column.

## Against Expected
- Row is there: yes.
- Empty default: yes (Default cell blank, Source DEFAULT, source code default "").
- Says which components can be listed: yes ("termlink node bats shellcheck pi ollama litellm", plus the separator rule).
- Says a needed or misspelled one still warns: yes ("a workflow that needs one still WARNs, and an unknown name WARNs").

## Observation (not part of the criterion)
The Env Var column and the DEFAULT badge wrap mid-word at 1024 ("FW_ABSE / NT_COMPO / NENTS", "DEFAU / LT"). Every row on the page does this, so it was already there and this task did not cause it.

Verdict: green.
