# Reviewer evidence — T-5147 AC#1

- dispatch: `judge-t-5147-r3-47d1d95a1d6d`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `2541cecfbc0ca163eb5c6adaed14fb44282f4160`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `6d02af98f4343e17dc7c20a109deebbf431615c1f3fc1004bb98082d2f4b0f9b`
- result.md sha256: `1ebd91ff44884c54aa3310b28c553bd6749bb16272ce3a4e251495576d728907`

## The worker's verdict block

```
1. [AC] Board stays fast after review and Awaiting review catches up
VERDICT: not-evaluated
WHY: The live URL was unreachable: curl returned error 7, HTTP 000. I could not observe either reload, a newly green task becoming ready within 20 seconds, or readiness correctness against recorded verdicts. Static screenshots cannot establish those behaviors.

I inspected all four screenshots against the visual checklist. All five columns and visible cards appear at each width. At 1024, card controls have truncated labels and right-edge badges are clipped; at 1440, some control labels remain truncated; at 1920, visible card controls fit. The supplied page screenshot also shows clipped card metadata. Interaction reachability and off-screen cards could not be verified.

--evidence /tmp/tl-dispatch/judge-t-5147-r3-47d1d95a1d6d/tmp/evidence/T-5147/01-tasks.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-47d1d95a1d6d/tmp/evidence/T-5147/board@1024.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-47d1d95a1d6d/tmp/evidence/T-5147/board@1440.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-47d1d95a1d6d/tmp/evidence/T-5147/board@1920.png

GUIDANCE: Route to a reviewer with live browser access. Measure baseline and both post-verdict reloads, verify the newly green task becomes ready by the second reload, and compare displayed readiness with authoritative verdicts. Check narrow-width card controls interactively.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Board stays fast after review and Awaiting review catches up
VERDICT: not-evaluated
WHY: The live URL was unreachable: curl returned error 7, HTTP 000. I could not observe either reload, a newly green task becoming ready within 20 seconds, or readiness correctness against recorded verdicts. Static screenshots cannot establish those behaviors.

I inspected all four screenshots against the visual checklist. All five columns and visible cards appear at each width. At 1024, card controls have truncated labels and right-edge badges are clipped; at 1440, some control labels remain truncated; at 1920, visible card controls fit. The supplied page screenshot also shows clipped card metadata. Interaction reachability and off-screen cards could not be verified.

--evidence /tmp/tl-dispatch/judge-t-5147-r3-47d1d95a1d6d/tmp/evidence/T-5147/01-tasks.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-47d1d95a1d6d/tmp/evidence/T-5147/board@1024.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-47d1d95a1d6d/tmp/evidence/T-5147/board@1440.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-47d1d95a1d6d/tmp/evidence/T-5147/board@1920.png

GUIDANCE: Route to a reviewer with live browser access. Measure baseline and both post-verdict reloads, verify the newly green task becomes ready by the second reload, and compare displayed readiness with authoritative verdicts. Check narrow-width card controls interactively.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
