# T-3341 AC1 — reviewer evidence (rung-1-same-vendor-independent)

Reviewed revision: c17b92d3c (HEAD at review time c79415475; `git diff c17b92d3c HEAD` is empty for
`tests/manual/arc020_g3_demo.py` and `docs/reports/T-3341-g3-demo-evidence.md`).

## Step 1 — hub
`termlink hub status --json` → `{"ok":true,"pid":3817871,...,"status":"running"}`. The hub was running before the demo.

## Step 2 — live run (2026-10-01T13:42:32Z)
`python3 tests/manual/arc020_g3_demo.py` → `RESULT: PASS ✓`, **EXIT=0**.

| Leg | Observed |
|---|---|
| 1 Bind | circuit-1 `tl-ohxr4as4` alive=True; `LANDED-c1-afc0542f` lands=True |
| 2 Drop | listener killed + `termlink clean`; probe says **definitively absent** ('not found', not 'unreachable') = True |
| 3 Elect | healer-A=won, healer-B=lost (holder healer-A); exactly-once = True |
| 4 Heal | provision → `provisioned`; circuit-2 `tl-73sgnx5k`; `tl-ohxr4as4 ≠ tl-73sgnx5k` = True |
| 5 Land | circuit-2 alive=True; `LANDED-c2-afc0542f` lands=True |

No leg showed False. The circuit IDs and message tags are fresh for this run and differ from the committed
report (`tl-kmkfvx7g`/`tl-xrtat6j5`, captured 2026-09-07). This shows the PASS is live and is not a replay.

## Step 3 — evidence doc and arc relevance
- `docs/reports/T-3341-g3-demo-evidence.md` (committed) has the same 5 sections with True for each leg. Its
  structure matches this run, and only the timestamps, IDs and tags differ.
- The demo imports the real production modules (`lib.aef_address`, `lib.aef_election`
  `TermlinkChannelClaimBackend`/`elect`, `lib.aef_resolve`). It drives a real termlink hub and contains no mocks or fakes.
- `.context/arcs/arc-020.yaml` ("Cross-agent identity & self-healing circuits") states the headline as "a dropped
  circuit self-heals" (line 16) and has a `demo_evidence:` key (line 19). The demo shows exactly that: the
  durable name `@healer` outlives circuit-1, the election is exactly-once, and the name heals onto a distinct
  circuit-2 where a peer message lands. This makes it a valid G3 (self-heal) `demo_evidence:` candidate.

## Side effect note
Running the demo rewrites `docs/reports/T-3341-g3-demo-evidence.md`. I checked the diff (timestamps, IDs and tags only)
and restored the committed version with `git checkout --` so I did not change the reviewed artifact.
Non-blocking observation: a manual demo that overwrites its committed evidence on every run produces churn.
An `--out` flag or write-only-on-request would be cleaner.
