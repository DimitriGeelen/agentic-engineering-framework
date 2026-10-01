# T-3341 AC1 — reviewer evidence (rung-1-same-vendor-independent)

Revision reviewed: 2a75b85f6e7c08ff62cb338a9de25baeb7b72f54
Verdict: **amber**

## What I did
1. `termlink hub status --json` → `status: running` (pid 3817871, termlink 0.12.41). Hub was up for every run.
2. Ran `python3 tests/manual/arc020_g3_demo.py` **six times** at this revision.
3. Read the script (`_deliver`, `_kill_circuit`, result block) and the committed
   `docs/reports/T-3341-g3-demo-evidence.md` (captured 2026-09-07, PASS).
4. Restored `docs/reports/T-3341-g3-demo-evidence.md` with `git checkout` afterwards,
   because the demo overwrites it on every run.

## Results
| Run | bind alive | c1 lands | drop: definitive absent | elect exactly-once | c1≠c2 | c2 alive | c2 lands | RESULT / exit |
|---|---|---|---|---|---|---|---|---|
| 1 | True | **False** | True | True (A won, B lost) | True (tl-my5yzxpv ≠ tl-e73jofb3) | True | **False** | **FAIL ✗ / 1** |
| 2 | True | True | True | True | True (tl-ptknjvs4 ≠ tl-upx4hubz) | True | True | PASS ✓ / 0 |
| 3 | True | True | True | True | True (tl-us2aojdg ≠ tl-lkseatwj) | True | True | PASS ✓ / 0 |
| 4–6 | — | True | — | — | — | — | True | PASS ✓ / 0 (x3) |

Total: 5 of 6 PASS. The failing leg was **delivery**, in sections 1 and 5 of the same run.
On that run both `interact … echo LANDED-…` calls returned output without the marker.
Right after the failure I ran a manual `termlink spawn --shell --backend background` followed by
`termlink interact <sid> "echo HELLO-RV" --json`, and the marker came back in 201 ms. I then
killed and cleaned that probe session; none were left behind. This points to a transient failure
in `_deliver`, not a broken mechanism. `_deliver` does one `interact` with no readiness wait and
no retry, and it throws away `_err`, so the failing run gives no diagnosis.

## Arc relevance
The self-heal mechanic was correct on every run, including the failing one:
- the drop gives a definitive 'not found', not 'unreachable' (D4-A);
- the election is exactly-once;
- the heal makes a new circuit id under the same durable name (D1);
- the healed circuit is alive.

So the evidence reads as the §ACD G3 self-heal leg firing, and a PASS run is a valid
`demo_evidence:` candidate for arc-020 G3.

## Why not green
1. **Not reproducible every time.** 1 of 6 runs failed the land leg with the hub running.
   The AC expects `RESULT: PASS ✓`, exit 0, every time.
2. **The evidence prose is wrong on failure.** The `## Result` sentence always says "the dropped
   circuit self-healed … and the peer's message landed" and only appends "G3 FAILED ✗".
   In run 1 the evidence file said the message landed when it had not. Because this file is the
   `demo_evidence:` artifact, a failed capture must not say the message landed.

## Needed for green
- Make `_deliver` robust: wait for the shell to be ready and/or retry `interact` a few times
  before declaring the message did not land. Record `_err`/raw output when it fails.
- Make the `## Result` sentence depend on `ok`, so a FAIL run does not say "self-healed …
  message landed".
- Then show N consecutive passes (for example 10/10).
