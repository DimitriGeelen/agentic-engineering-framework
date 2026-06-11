# arc-011 M1 §4 — headline_mechanic evidence

**Task:** T-2341
**Date:** 2026-06-11
**Demo script:** `agents/dispatch/single-host-parallel-demo.sh`
**Integration test:** `tests/integration/test_single_host_parallel.bats` (6/6 PASS)

## headline_mechanic (verbatim from `.context/arcs/parallel-execution-aef.yaml`)

> Two agents on disjoint write-set tasks run concurrently … operator observes
> no `.tasks/` merge conflicts.

## What this slice ships

The M1 demo that **fires** the headline_mechanic for the first time. Prior
arc-011 M1 slices (T-2337 disjoint validator, T-2338 yield-point, T-2339
orchestrator-graph, T-2340 pre-flight gate) were infrastructure. This slice
composes them end-to-end:

```
2 file-write-only worker tasks with disjoint write_sets
  → orchestrator-graph emits BOTH as `parallel`
  → pre-flight gate APPROVES both
  → workers spawn concurrently (bash background &)
  → BOTH appear in dispatches.jsonl with outcome="" simultaneously
  → BOTH write to their declared paths
  → BOTH complete
  → .tasks/ tree clean (no merge conflict markers)
```

## Wire-level evidence (captured live, 2026-06-11)

### dispatches.jsonl — overlapping in-flight window

The headline_mechanic predicate is: **at some point both T-DEMO-A and T-DEMO-B
dispatch rows exist with `outcome=""` simultaneously** (proof of concurrent
execution, not serial).

```jsonl
{"dispatch_id":"D-DEMO-002","task_id":"T-DEMO-B","outcome":"","started_at":1781203359}
{"dispatch_id":"D-DEMO-001","task_id":"T-DEMO-A","outcome":"","started_at":1781203359}
{"dispatch_id":"D-DEMO-002","task_id":"T-DEMO-B","outcome":"success","completed_at":1781203360}
{"dispatch_id":"D-DEMO-001","task_id":"T-DEMO-A","outcome":"success","completed_at":1781203360}
```

- **Both rows have `started_at: 1781203359`** — same wall-clock second.
- **Both `outcome=""` rows precede both `outcome="success"` rows** — proving
  the in-flight window overlaps rather than serialises (B-start, A-start,
  B-end, A-end).
- The demo script's snapshot taken at t+0.5s captures both rows with
  `outcome=""` — recorded by the script's `OVERLAP_SNAPSHOT` assertion.

### `.tasks/` clean tree

After both workers complete, `git status --short .tasks/` in the sandbox shows:

```
?? .tasks/
```

The `?? .tasks/` line is the entire sandbox directory being untracked (the
sandbox is git-init'd at the demo start with `--allow-empty`, then the
worker fixtures are added but the dir is untouched after the workers exit).
No merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) appear in any
task file — verified by `grep -rE '^<<<<<<<|^=======|^>>>>>>>' $SANDBOX/.tasks/`
returning no matches.

### Wall-clock timing

```yaml
duration_seconds: 1
```

The serial baseline would be ~2s (1s sleep per worker, run sequentially).
Concurrent execution finishes in ~1s — strong evidence that the workers
ran in parallel, not serially.

## Reproducing the demo

```bash
bash agents/dispatch/single-host-parallel-demo.sh
```

Optional: capture wire evidence:

```bash
EVID=$(mktemp -d)
EVIDENCE_DIR="$EVID" bash agents/dispatch/single-host-parallel-demo.sh \
    --sandbox "$EVID/sandbox"
ls "$EVID"   # dispatches.jsonl, tasks-git-status.txt, timing.yaml, sandbox/
```

## What this evidence demonstrates

| Headline_mechanic clause | Evidence |
|--------------------------|----------|
| "two agents" | T-DEMO-A worker + T-DEMO-B worker (bash subprocess, M1) |
| "on disjoint write-set tasks" | `docs/reports/_demo/A.md` vs `docs/reports/_demo/B.md` (validated by `bin/fw write-set check`) |
| "run concurrently" | dispatches.jsonl rows with overlapping `outcome=""` windows + 1s wall-clock vs 2s serial baseline |
| "operator observes no `.tasks/` merge conflicts" | `git status --short .tasks/` shows clean tree, zero merge conflict markers |

## arc-011 demo_evidence field

This artifact satisfies arc-011's `demo_evidence:` field. After this slice
lands, `fw arc show parallel-execution-aef` reports demo evidence captured
(per §G-062 arc completion discipline).

## What this slice does NOT prove (out of scope for M1)

- **Cross-machine parallelism** — M2 territory. M1 is single-host-only.
  Workers are bash subprocesses on the same host; no TermLink / SSH / dispatch
  fan-out. The orchestrator does not consult fleet-state.
- **Real-agent compatibility** — M2 territory. Workers here are deterministic
  bash stubs that touch a file and exit. `claude -p` worker parity (model
  invocation, structured output, stream-json capture) ships in M2.
- **Heartbeat staleness** — M2 territory. If a worker hangs, the yield-point
  (T-2338) refuses subsequent workers, but the dispatch gauge has no liveness
  signal. M2 ADR §5 cooperative-poll mechanism covers this.
- **Watchtower visualisation** — §5 of arc-011 M1 (T-2342, planned). This
  slice's evidence is grep-based; §5 makes operator observation visual.

## References

- arc anchor: `.context/arcs/parallel-execution-aef.yaml`
- arc-011 M1 sketch (this slice): `docs/reports/arc-011-m1-single-host-sketch.md:189-232`
- T-2337 (disjoint validator): `lib/write_set.py`, `bin/fw write-set`
- T-2338 (yield-point): `agents/dispatch/yield-point.sh`
- T-2339 (orchestrator-graph): `agents/orchestrator/orchestrator-graph.py:build_graph`, `bin/fw orchestrator next-dispatch`
- T-2340 (pre-flight gate): `agents/orchestrator/orchestrator-graph.py:pre_flight_check`, `bin/fw orchestrator pre-flight`
- This slice: `agents/dispatch/single-host-parallel-demo.sh` + `tests/integration/test_single_host_parallel.bats`
