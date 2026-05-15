# dispatch-safety arc — headline-mechanic demo evidence

**Arc:** `dispatch-safety`
**Purpose:** Wire-level proof that the arc's `headline_mechanic` fires end-to-end. This file is the `--demo` artefact for `fw arc close dispatch-safety` (G-062).

## Headline mechanic (from `.context/arcs/dispatch-safety.yaml`)

> Agent dispatches a Worker; Worker hits an ambiguity whose severity × likelihood crosses the workflow `pause_threshold`; Worker emits `pause_requested` with question + risk assessment; Worker exits cleanly; operator sees [PAUSE] in Watchtower review queue; operator answers; Agent re-dispatches with resolution context linked via `retry_of_dispatch_id`; Worker completes correctly first-try.

## Slice coverage

| Slice | Task | Mechanic surface |
|-------|------|------------------|
| 1 | T-1805 | substrate recognizes `pause_requested` terminal event |
| 2 | T-1806 | Resolver injects risk-policy preamble teaching Workers when to pause |
| 3 | T-1807 | workflow linter catches `pause_threshold`/`allow_pause`/`pause_preamble` typos before dispatch |
| 4 | T-1808 | paused dispatches surface in `fw review-queue` + Watchtower `/approvals` |
| 5 | T-1809 | `fw pause resolve <id> --answer "..."` writes retry row with `retry_of_dispatch_id` linking back; RE-DISPATCH block prepended to new prompt above risk-policy preamble |
| 6 | T-1810 | Watchtower `/review/T-XXX` paused-dispatch resolve form — web parity for CLI |

All six slices shipped with passing tests. Combined test count: **86 tests** across `test_dispatch_pause.py + test_workflow_schema_pause_lint.py + test_pause_resolve.py + test_resolver.py + test_review_paused_resolve.py`.

## Wire-level evidence

### 1. Paused dispatch row (slice 1 substrate)

A Worker emitting `pause_requested` produces a row in `.context/dispatches.jsonl` with `outcome=paused`:

```json
{
  "schema_version": 1,
  "ts": "2026-05-13T17:43:00+00:00",
  "dispatch_id": "demo-T1810-aabbccdd",
  "task_id": "T-1810",
  "task_type": "build",
  "worker_kind": "TermLink",
  "model": "sonnet",
  "outcome": "paused",
  "terminal_event": {
    "type": "pause_requested",
    "question": "Should the resolve button use POST-redirect-GET or htmx swap?",
    "assessment": {"severity": "medium", "likelihood": "high"}
  }
}
```

### 2. Operator visibility — Watchtower `/review/T-1810` rendered DOM (slice 4 + 6)

`curl -s http://localhost:3000/review/T-1810` against a tree with the row above appended to `dispatches.jsonl` returns HTML containing all five required elements:

- `<h3>Paused Dispatches — Worker awaits your answer</h3>` (panel heading)
- `<span ...>MED</span>` (severity badge, medium → amber)
- `Q: Should the resolve button use POST-redirect-GET or htmx swap?` (question render)
- `<form method="POST" action="/review/T-1810/pause/demo-T1810-aabbccdd/resolve">` (full dispatch_id in action)
- `<button type="submit">Resolve &amp; re-dispatch</button>` (submit button)

Hide condition tested: after restoring `dispatches.jsonl` to the empty-paused state, `grep -c "Paused Dispatches"` against `/review/T-1810` returns **0**. Panel renders only when there are paused rows for the task.

### 3. Resolution chain (slice 5 CLI + slice 6 web)

CLI path (slice 5):

```bash
fw pause resolve demo-T1810-aabbccdd --answer "Use POST-redirect-GET — htmx swap loses the URL flash"
# prints:
# new dispatch_id:    <fresh-uuid>
# task_id:            T-1810
# retry_of_dispatch:  demo-T1810-aabbccdd
# prompt:             ~1.2KB chars
```

Web path (slice 6):

POST `/review/T-1810/pause/demo-T1810-aabbccdd/resolve` with form field `answer=Use POST-redirect-GET ...` → **303 See Other** → `Location: /review/T-1810?resolved=<short_id>...`. The fresh page render no longer shows the Paused panel (deflated via `list_paused_dispatches_for_task`'s `retry_of_dispatch_id` filter).

### 4. RE-DISPATCH block in the retry prompt (slice 5)

The new Worker sees the operator's answer above the risk-policy preamble:

```
[RE-DISPATCH — operator answered your pause]

On a previous attempt at this task you paused with this question:
  Q: Should the resolve button use POST-redirect-GET or htmx swap?

The operator's answer is:
  A: Use POST-redirect-GET — htmx swap loses the URL flash

Treat this answer as authoritative. Proceed with the task using it as
guidance. Do NOT re-pause on the same question. If a different ambiguity
arises that meets the severity × likelihood threshold, you may pause
again — but on the new question, not this one.

[RISK POLICY — when to pause vs proceed]
...
```

Block ordering is pinned by `tests/unit/test_pause_resolve.py::test_assemble_prompt_redispatch_block_above_risk_preamble` (RE-DISPATCH must precede RISK POLICY).

## Appendix: Live CLI + web smoke (2026-05-13, T-1812 follow-up)

Beyond the JSON example above, this section captures **actual command output** from a controlled smoke against the live framework — synthetic paused row appended to `.context/dispatches.jsonl`, full CLI+web chain exercised, row removed at end. No state polluted.

**Synthetic row appended (smoke-T1687-arctest1):**

```json
{"schema_version": 1, "ts": "2026-05-13T18:40:00+00:00", "dispatch_id": "smoke-T1687-arctest1", "task_id": "T-1687", "task_type": "build", "worker_kind": "TermLink", "model": "sonnet", "outcome": "paused", "terminal_event": {"type": "pause_requested", "question": "Smoke test: should the agent proceed with end-to-end verification?", "assessment": {"severity": "medium", "likelihood": "high"}}}
```

**`bin/fw pause list` output (slice 4 CLI surface):**

```
PAUSED — Workers awaiting resolution (1)
  AGE  DISPATCH    TASK        SEV     QUESTION
 <10m  smoke-T1..  T-1687      medium  Smoke test: should the agent proceed with end-to-end veri...
```

**`bin/fw pause resolve --dry-run` output (slice 5 CLI surface):**

```
new dispatch_id:    11c0f0f8-9728-471c-8ac1-f206f27b98d1
task_id:            T-1687
task_type:          build
worker_kind:        TermLink
retry_of_dispatch:  smoke-T1687-arctest1
prompt:             3765 chars
dry-run:            no JSONL append, no blob written
```

**`bin/fw pause resolve --dry-run --json` envelope tail (retry link confirmed):**

```
"outcome": "pending",
"dry_run": true,
"retry_of_dispatch_id": "smoke-T1687-arctest1"
```

**Web `/review/T-1687` rendered DOM (slices 4 + 6, panel + form):**

```
Paused Dispatches — Worker awaits your answer
MED
Smoke test: should the agent proceed with end-to-end verification?
<form method="POST" action="/review/T-1687/pause/smoke-T1687-arctest1/resolve" ...>
```

All five surfaces (substrate JSONL, CLI list, CLI resolve dry-run, JSON envelope, web panel) co-operated correctly on a fresh row. The `retry_of_dispatch_id` linkage is verified in the resolve envelope, which is exactly the slice-4 forward-compat → slice-5 fulfilment chain. Synthetic row removed from `.context/dispatches.jsonl` after capture (rollback via stored backup).

## Closure path

When the human is ready to close the arc:

```bash
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc close dispatch-safety --demo docs/reports/dispatch-safety-arc-demo.md
```

(Optional `--decision "shipped 6 slices end-to-end, v2 peer-consult deferred via T-1804/U-007 pending TermLink-side seam agreement"`.)

The `--demo` argument satisfies G-062's wire-level evidence gate. The default-to-OPEN clause does not apply (no human pushbacks on this arc).

## Out of scope (NOT demonstrated here)

- **v2 peer-consult substrate** — gated on T-1804 (GO recorded 2026-05-13, awaiting TermLink-side concurrence on seam via pending U-007). Arc closure here covers v1 only.
- **Real-Worker dispatch** — the substrate is fully tested with synthetic Worker output (pause_requested terminal events). End-to-end with a live LLM Worker is part of the broader v1 dispatch substrate (T-1700/T-1701 build arc), not this safety arc.
