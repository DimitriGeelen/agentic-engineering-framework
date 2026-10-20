# Reviewer evidence — T-4475 AC#1

- dispatch: `judge-t-4475-r5-codex-4241bb3e2eb6`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `362bba05ebfc4fd20f8e3aabab5dcdf51184a878`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `0f24dd48ba63864d27cd928e9285cdb85832c5175f1995b5abe965671711991c`
- result.md sha256: `62b968c02f53f0615ed8155a278ba69266b093935eb25e56f8a36e8c25bb441a`

## The worker's verdict block

```
1. [AC] EMBED_WORKERS row reads clearly beside its neighbours
VERDICT: not-evaluated
WHY: web/blueprints/config.py:75 defines default 1 and describes concurrent reindex embed requests, matching the server’s OLLAMA_NUM_PARALLEL, and serial operation at 1. However, all four required screenshots are missing: .context/working/judge-evidence/T-4475/01-config.png, .context/visual/T-4475/config@1024.png, .context/visual/T-4475/config@1440.png, and .context/visual/T-4475/config@1920.png. I could not inspect the rendered page or verify visibility, reachability, clipping, overlap, or layout beside neighbouring rows.
GUIDANCE: Supply all four screenshots to a reviewer who can inspect and cite them, then evaluate the rendered row at each required width.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] EMBED_WORKERS row reads clearly beside its neighbours
VERDICT: not-evaluated
WHY: web/blueprints/config.py:75 defines default `1` and describes concurrent reindex embed requests, matching the server’s OLLAMA_NUM_PARALLEL, and serial operation at 1. However, all four required screenshots are missing: `.context/working/judge-evidence/T-4475/01-config.png`, `.context/visual/T-4475/config@1024.png`, `.context/visual/T-4475/config@1440.png`, and `.context/visual/T-4475/config@1920.png`. I could not inspect the rendered page or verify visibility, reachability, clipping, overlap, or layout beside neighbouring rows.
GUIDANCE: Supply all four screenshots to a reviewer who can inspect and cite them, then evaluate the rendered row at each required width.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
