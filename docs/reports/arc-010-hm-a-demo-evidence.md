# arc-010 Headline Mechanic A (HM-A) — Demo Evidence

**Arc:** arc-010 (slug: capability-overlay)
**Anchor task:** T-2209
**Demo task:** T-2268 (Slice 3 — HM-A demo agent)
**Demo target:** T-2273 (the task the demo agent drove)
**Worker prompt:** [docs/reports/arc-010-hm-a-demo-prompt.md](./arc-010-hm-a-demo-prompt.md)
**Closes:** G-062 arc-closure gate for arc-010 (per `fw arc close capability-overlay`)

## Headline Mechanic (verbatim from arc YAML)

> Agent dispatches a task via `mcp__fw__task_update` / `mcp__fw__work_on` and works
> it to work-completed; operator observes `/review/T-XXX` rendered correctly;
> transcript JSONL shows no `Bash(bin/fw ...)` lines for those verbs.

## Status: AWAITING DEMO RUN

This README is a **scaffold**. The traceability table below is empty until the
operator wires `.mcp.json` (per `agents/mcp/framework-mcp.mcp-fragment.json`) and
runs the demo worker (see worker prompt linked above).

**Capture host:** _(to fill in after run)_
**Capture timestamp:** _(to fill in after run)_
**Worker session id:** _(to fill in after run)_
**Transcript path:** `docs/reports/arc-010-hm-a-demo/transcript.jsonl` _(to be created
during run)_

## Traceability Table

Each row maps one clause of the headline mechanic to the artefact that proves it
fired, and the commit that shipped the artefact.

| # | Headline mechanic clause                                         | Demo artefact                                                                   | Shipping commit |
|---|------------------------------------------------------------------|---------------------------------------------------------------------------------|-----------------|
| 1 | Agent dispatches a task via `mcp__fw__work_on`                   | `docs/reports/arc-010-hm-a-demo/transcript.jsonl` (grep `"name":"mcp__fw__work_on"` for T-2273) | _(fill: SHA of demo-evidence commit)_ |
| 2 | Agent dispatches via `mcp__fw__task_update`                      | `docs/reports/arc-010-hm-a-demo/transcript.jsonl` (grep `"name":"mcp__fw__task_update"` for T-2273) | _(fill: SHA)_ |
| 3 | Task reaches `work-completed`                                    | `.tasks/completed/T-2273-*.md` exists with `status: work-completed`             | _(fill: SHA of T-2273 close commit)_ |
| 4 | Operator observes `/review/T-XXX` rendered correctly             | `curl -sf "$(bin/fw watchtower url)/review/T-2273"` returns HTTP 200 with valid HTML — operator confirms render in Watchtower | _(fill: operator confirmation note)_ |
| 5 | Transcript shows **no** `Bash(bin/fw ...)` lines for those verbs | `grep -cE 'Bash.*bin/fw (task update\|work-on\|context focus)' docs/reports/arc-010-hm-a-demo/transcript.jsonl` returns **0** | _(fill: SHA)_ |
| 6 | Deliverable file produced by demo run                            | `docs/reports/arc-010-mcp-tools-overview.md` (the file T-2273 ships)            | _(fill: SHA of T-2273 close commit)_ |

## Verdict

_(to fill in after run — one of)_

- **FIRED** — All 6 clauses traceable. arc-010 G-062 satisfied. Operator may run
  `fw arc close capability-overlay --demo docs/reports/arc-010-hm-a-demo-evidence.md`.
- **PARTIAL** — _N_ of 6 clauses traceable. List which clauses failed and why.
  Re-run after fix.
- **REFUTED** — The negative grep (clause 5) returned > 0. Worker used Bash for an
  fw verb. Headline mechanic falsified for this run. Investigate MCP server gaps
  or worker prompt clarity before re-run.

## Tone

Factual. No marketing. The artefact is for a future reviewer who has never seen
arc-010; the traceability table is the only thing they need to draw the verdict
themselves.
