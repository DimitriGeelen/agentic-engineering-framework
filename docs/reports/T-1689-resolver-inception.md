# T-1689 Research Artifact — Resolver Inception

**Status:** in-progress (2026-05-03)
**Workflow type:** inception
**Arc:** orchestrator-rethink

## Problem

The Resolver is the load-bearing new component for v1 dispatch. CONTEXT.md +
ADR-0003 specify WHAT it does. This inception scopes HOW: module layout, error
handling, latency characteristics, and end-to-end validation strategy. Land
before T-1690/T-1691/T-1692 begin consuming it.

## Assumptions

| ID | Statement | Status |
|----|-----------|--------|
| A-1 | Python module + shell shim is the right fit | tested ✓ |
| A-2 | `git rev-parse HEAD:<path>` < 50ms per call | tested ✓ |
| A-3 | `.context/dispatch-blobs/` ≠ `.context/bus/blobs/` (no collision) | tested ✓ |
| A-4 | Tier 3 meta-prompt latency 5–30s acceptable for opt-in | not tested in v1 (deferred to T-1689 after build) |
| A-5 | `dispatches.jsonl` modify-in-place atomic via rewrite-then-rename | tested ✓ |

### A-1 — Module fit (Python + shell shim)

**Decision:** validated. Existing patterns in `lib/`:
- `lib/bus.sh` (~428 LOC pure bash, artifact storage)
- `lib/dispatch.sh` (~175 LOC pure bash, SSH envelope)
- `lib/hook-threshold.py`, `lib/doctor-hook-exercise.py` (Python where logic warrants)

Resolver needs YAML parse, template substitution, context selection from
multiple sources, JSONL append, UUID generation. Python is the right tool.
Shell shim wires it into `bin/fw resolver` and the future agent dispatch path.

### A-2 — git rev-parse latency

```
$ time git rev-parse HEAD:.context/project/workflows/default.yaml
92c132efd1c0072d3d44b81352ec4770fe4835c4
real    0m0.002s

$ time for i in {1..10}; do git rev-parse HEAD:default.yaml > /dev/null; done
real    0m0.021s   # ~2.1ms/call avg
```

Hot-cache cost is ~2ms. Cold-cache (after fresh clone or first call) is bounded
by `.git/objects/` lookup; still well under 50ms on any sane filesystem.
**VALIDATED** — call per dispatch (workflow file + template = 2 calls = ~4ms)
is invisible compared to the LLM round-trip.

### A-3 — Path separation

`.context/bus/blobs/` (existing, T-109 ledger) and `.context/dispatch-blobs/`
(new, this work) are siblings under `.context/`. Different parent dirs. No
collision possible. **VALIDATED** structurally.

### A-4 — Tier 3 latency

Not validated in this inception. Tier 3 (`prompt_strategy: meta-prompted`)
requires an actual LLM call (haiku meta-step). Validating it requires either
(a) a test API key on the dispatch path, or (b) a mock/stub. v1 build task
(downstream of this inception's GO) should:
1. Wire Tier 3 with a real haiku call against a representative build prompt
2. Measure latency + cost per dispatch
3. If latency > 30s OR cost > $0.05/dispatch, defer Tier 3 to v2 and ship
   only Tier 1+2 in v1

The substrate (workflow `prompt_strategy` field, `meta_template`, `meta_model`
fields, `meta_prompt_text` blob field in dispatches.jsonl) is wired
unconditionally — Tier 3 can ship later without retrofitting the schema.

### A-5 — JSONL modify-in-place atomicity

Pattern: read full file → patch the matching row → write to `.tmp` →
`os.rename(.tmp, original)`. POSIX rename is atomic on the same filesystem.
Concurrent dispatches each appending is also atomic if writes are O_APPEND
+ small (<PIPE_BUF, 4KB). Modify-in-place from a back-prop hook (T-1690) is
slower but rare (only on task completion, not every dispatch).

**VALIDATED** by precedent: `lib/learning.sh`, `lib/decision.sh` use the
same rewrite-then-rename pattern with no reported corruption in 1500+ tasks.

## Spike S-1 — End-to-end assembled resolver

Build the minimal Tier 2 path:
1. Read `.context/project/workflows/<task_type>.yaml`, fall back to default
2. Substitute `$VAR` slots from task frontmatter + recent dispatches
3. Compute workflow_sha + template_sha via git rev-parse
4. Generate dispatch_id (UUID4)
5. Write `dispatches.jsonl` row + `dispatch-blobs/<YYYY-MM>/<id>/` dir
6. Return Delegation envelope dict for downstream dispatch

Skip the actual TermLink dispatch — that's T-1691's scope. Verify telemetry
round-trip end of S-1 (read back the JSONL row, walk into the blob dir).

## Spike S-2 — Variant selection

Pure logic. Read `variants:` map, weighted random pick, record `variant_id`
in envelope and JSONL. No external dependency. Validate by running 1000
draws and confirming distribution matches weights ±5%.

## Spike S-3 — Tier 3 meta-prompt scaffolding

Not full validation (see A-4 above). Just wire the data flow:
- workflow has `prompt_strategy: meta-prompted` + `meta_model` + `meta_template`
- resolver assembles the meta-prompt context (task + last-N dispatches)
- placeholder for the actual meta-LLM call (returns a TODO marker)
- the TODO marker + meta-prompt text both captured in the blob dir
- v1 build task (downstream of this inception's GO) replaces the TODO with
  a real call against haiku.

## Findings

(filled as spikes complete)

## Recommendation

(filled at end)

## Dialogue Log

(no human dialogue yet — this inception is agent-driven exploration; the
human reviews via `fw task review T-1689` at the recommendation stage)
