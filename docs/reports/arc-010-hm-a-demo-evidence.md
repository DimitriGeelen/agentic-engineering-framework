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

## Operator Quickstart

Three steps. All commands run from `/opt/999-Agentic-Engineering-Framework`.

**1. Wire `.mcp.json`** — merge the framework-mcp fragment into the current
config. Idempotent (skips on duplicate key):

```sh
python3 -c '
import json, pathlib
mcp = pathlib.Path(".mcp.json")
cfg = json.loads(mcp.read_text()) if mcp.exists() else {"mcpServers": {}}
cfg.setdefault("mcpServers", {})
frag = json.loads(pathlib.Path("agents/mcp/framework-mcp.mcp-fragment.json").read_text())
cfg["mcpServers"].update(frag)
mcp.write_text(json.dumps(cfg, indent=2) + "\n")
print("wired:", list(frag.keys()))
'
```

**2. Spawn the demo worker** — fresh `claude -p` with transcript capture:

```sh
mkdir -p docs/reports/arc-010-hm-a-demo
claude -p "$(cat docs/reports/arc-010-hm-a-demo-prompt.md)" \
    --output-format stream-json \
    > docs/reports/arc-010-hm-a-demo/transcript.jsonl
```

**3. Verify the headline mechanic fires** — two greps, one negative:

```sh
T=docs/reports/arc-010-hm-a-demo/transcript.jsonl
echo "MCP work_on:    $(grep -c '\"name\":\"mcp__fw__work_on\"' "$T")"     # ≥1
echo "MCP task_update: $(grep -c '\"name\":\"mcp__fw__task_update\"' "$T")" # ≥1
echo "Bash bin/fw:    $(grep -cE 'Bash.*bin/fw (task update|work-on|context focus)' "$T")"  # MUST be 0
```

If clause-5 (negative grep) returns `0`, the headline mechanic fired. Run
`bats tests/integration/test_arc010_hm_a_demo_evidence.bats` — t9, t10, t11 will
upgrade from skip to pass. Then fill the traceability table below + the metadata
fields above, tick the remaining T-2268 ACs, and run `fw arc close
capability-overlay --demo docs/reports/arc-010-hm-a-demo-evidence.md`.

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
