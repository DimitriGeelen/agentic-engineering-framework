# Reviewer evidence — T-3786 AC#1

- dispatch: `judge-t-3786-r5-codex-fd227ac9706c`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `415d10706db6218e349a5b34f45204ebd7edffb3`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `c295d45a97a4704198b409fc8dcfff1a53aaaa708307fac0d125d46a07f3a1cf`
- result.md sha256: `a653bb8d25db83e4e4e577999d43e5e0edec7b0bfc26498b77969e7a13f53bf0`

## The worker's verdict block

```
1. [AC] Search and ask still work, and never rebuild the index from the page
VERDICT: not-evaluated
WHY: Inspected all 23 screenshots and relevant code. Search screenshots show 20 results for “vector index.” Code contains the unavailable-index remedy and returns without building. However, the live URL failed to connect (curl exit 7); ask screenshots show only an empty panel or query-too-short error. Referenced walk captures are absent. I could not verify the requested answer or live unavailable-index behavior. All screenshot copies and --evidence citations are recorded in [review.txt](/tmp/tl-dispatch/judge-t-3786-r5-codex-fd227ac9706c/tmp/report/review.txt).
GUIDANCE: Route to a reviewer with live browser access to perform both specified steps and verify the unavailable-index message and absence of rebuild activity using an isolated test index.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Search and ask still work, and never rebuild the index from the page
VERDICT: not-evaluated
WHY: Inspected all 23 screenshots and relevant code. Search screenshots show 20 results for “vector index.” Code contains the unavailable-index remedy and returns without building. However, the live URL failed to connect (curl exit 7); ask screenshots show only an empty panel or query-too-short error. Referenced walk captures are absent. I could not verify the requested answer or live unavailable-index behavior. All screenshot copies and --evidence citations are recorded in [review.txt](/tmp/tl-dispatch/judge-t-3786-r5-codex-fd227ac9706c/tmp/report/review.txt).
GUIDANCE: Route to a reviewer with live browser access to perform both specified steps and verify the unavailable-index message and absence of rebuild activity using an isolated test index.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
