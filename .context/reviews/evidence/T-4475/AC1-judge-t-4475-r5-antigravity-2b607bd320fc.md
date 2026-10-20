# Reviewer evidence — T-4475 AC#1

- dispatch: `judge-t-4475-r5-antigravity-2b607bd320fc`
- worker kind: `antigravity` (vendor `google`, model `worker default`)
- seat: `antigravity`
- reviewed revision: `aa6ab3db17a50984007cba05a718c8defd28b76a`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.md sha256: `17ec32dbec68480ef6dedb590641a225aba1fcef846da1b4d0fed90c3c3bac63`

## The worker's verdict block

```
1. [AC] [REVIEW] The new EMBED_WORKERS row on /config reads clearly next to its neighbours
VERDICT: not-evaluated
WHY: Although web/blueprints/config.py line 75 defines ("EMBED_WORKERS", "1", "Concurrent embed requests the vector reindex sends to the bulk embedding host (web/embeddings.py:_embed_batches; order preserved). Match it to the server's OLLAMA_NUM_PARALLEL; 1 is serial. Malformed or <1 means 1; T-4475") matching the expected text and default, this harness seat runs in a git archive export that excludes .context/ (:(exclude).context in run.sh line 201) and runs with sandbox isolation blocking access to /opt/999-Agentic-Engineering-Framework and network access. Therefore, the required rendered page screenshots (.context/working/judge-evidence/T-4475/01-config.png, .context/visual/T-4475/config@1024.png, .context/visual/T-4475/config@1440.png, .context/visual/T-4475/config@1920.png) and the live /config page could not be seen or evaluated by this seat. Note also: degraded: single-vendor panel (fewer vendors can be dispatched than the panel requires, so this run cannot satisfy a multi-vendor requirement and the criterion stays open).
GUIDANCE: Evaluate Criterion 1 with a reviewer seat that has read access to .context/working/judge-evidence/T-4475/01-config.png and .context/visual/T-4475/config@{1024,1440,1920}.png (or stage those screenshot files into the harness reviewer's readable workspace), and satisfy the multi-vendor panel requirement.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
This is an independent review report for **T-4475** from seat `antigravity` under rung `rung-5-panel:antigravity`.

**Panel status note:** **degraded: single-vendor panel.** Fewer vendors can be dispatched than the panel requires, so this run cannot satisfy a multi-vendor requirement: this verdict is recorded and reported, and the criterion stays open.

### Evidence & Evaluation Details

1. **Static Inspection (`web/blueprints/config.py` & `web/templates/config.html`):**
   - In [`web/blueprints/config.py`](file:///tmp/tl-dispatch/judge-t-4475-r5-antigravity-2b607bd320fc/tree/web/blueprints/config.py#L75), `EMBED_WORKERS` is registered with default `"1"` and description: `"Concurrent embed requests the vector reindex sends to the bulk embedding host (web/embeddings.py:_embed_batches; order preserved). Match it to the server's OLLAMA_NUM_PARALLEL; 1 is serial. Malformed or <1 means 1; T-4475"`.
2. **Rendered Page & Visual Verification (`not-evaluated` reason):**
   - As a harness reviewer (`antigravity`), this session runs inside a `git archive` export (`/tmp/tl-dispatch/judge-t-4475-r5-antigravity-2b607bd320fc/tree`) constructed with `:(exclude).context` (`run.sh` line 201), and the sandbox blocks access outside the workspace (such as `/opt/999-Agentic-Engineering-Framework/.context/`) as well as local network access to a live Watchtower instance.
   - Consequently, the required screenshots (`.context/working/judge-evidence/T-4475/01-config.png`, `.context/visual/T-4475/config@1024.png`, `.context/visual/T-4475/config@1440.png`, `.context/visual/T-4475/config@1920.png`) do not exist in the exported workspace tree and could not be read or visually inspected.
   - Per the T-3986 operator ruling ("Never vote on what you did not see... return `not-evaluated` with the reason instead"), Criterion 1 is marked `not-evaluated`.

1. [AC] [REVIEW] The new EMBED_WORKERS row on /config reads clearly next to its neighbours
VERDICT: not-evaluated
WHY: Although `web/blueprints/config.py` line 75 defines `("EMBED_WORKERS", "1", "Concurrent embed requests the vector reindex sends to the bulk embedding host (web/embeddings.py:_embed_batches; order preserved). Match it to the server's OLLAMA_NUM_PARALLEL; 1 is serial. Malformed or <1 means 1; T-4475")` matching the expected text and default, this harness seat runs in a `git archive` export that excludes `.context/` (`:(exclude).context` in `run.sh` line 201) and runs with sandbox isolation blocking access to `/opt/999-Agentic-Engineering-Framework` and network access. Therefore, the required rendered page screenshots (`.context/working/judge-evidence/T-4475/01-config.png`, `.context/visual/T-4475/config@1024.png`, `.context/visual/T-4475/config@1440.png`, `.context/visual/T-4475/config@1920.png`) and the live `/config` page could not be seen or evaluated by this seat. Note also: degraded: single-vendor panel (fewer vendors can be dispatched than the panel requires, so this run cannot satisfy a multi-vendor requirement and the criterion stays open).
GUIDANCE: Evaluate Criterion 1 with a reviewer seat that has read access to `.context/working/judge-evidence/T-4475/01-config.png` and `.context/visual/T-4475/config@{1024,1440,1920}.png` (or stage those screenshot files into the harness reviewer's readable workspace), and satisfy the multi-vendor panel requirement.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
