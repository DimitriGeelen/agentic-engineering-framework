# Demo Worker Prompt — arc-010 Headline Mechanic A (HM-A)

You are a fresh Claude Code worker spawned in `/opt/999-Agentic-Engineering-Framework`
with `.mcp.json` configured for the framework MCP server (see
`agents/mcp/framework-mcp.mcp-fragment.json` for the wiring contract).

Your job: drive **T-2273** ("arc-010 HM-A demo-target — generate MCP tools overview
doc") end-to-end **using only `mcp__fw__*` verbs** for governance — never
`Bash(bin/fw task update|work-on|context focus|inception|arc|...)`. The Write tool is
allowed for the deliverable file; the Read tool is allowed for inspection.

This proves the headline mechanic recorded in
`.context/arcs/capability-overlay.yaml:headline_mechanic`:

> Agent dispatches a task via `mcp__fw__task_update` / `mcp__fw__work_on` and works
> it to work-completed; operator observes `/review/T-XXX` rendered correctly;
> transcript JSONL shows no `Bash(bin/fw ...)` lines for those verbs.

## Steps

1. **Read T-2273's ACs** to understand the deliverable:
   - Read `.tasks/completed/T-2273-arc-010-hm-a-demo-target--generate-mcp-t.md` (Read tool).
   - Read `policy/capability-overlay/tool-set.yaml` (Read tool) — the 22 framework MCP
     tools and their classifications (read_only / agent_authority).
   - Read `.tasks/completed/T-2265-arc-010-slice-2--framework-mcp-server-em.md` (Read
     tool) for context on the MCP server.

2. **Take the task** via `mcp__fw__work_on(task_id="T-2273")`. This sets focus + flips
   status to `started-work`. **Do NOT call `Bash(bin/fw work-on T-2273)`** — that
   defeats the demo.

3. **Write the deliverable**: `docs/reports/arc-010-mcp-tools-overview.md`. Use the
   Write tool. Constraints (from T-2273 ACs):
   - 80-150 words total.
   - Groups the 22 framework MCP tools into ≥ 4 named capability groupings (e.g.
     task / context / focus / fabric / handover / metrics).
   - References `T-2265` (MCP server ship), `T-2258` (tool-set artefact), and
     `policy/capability-overlay/tool-set.yaml` (path).
   - Tone: brief technical overview, not marketing.

4. **Close the task** via `mcp__fw__task_update(task_id="T-2273",
   status="work-completed")`. The Verification block runs the file-exists + word-count
   + reference-grep + reviewer-PASS gate. If any fails, fix and re-call. **Do NOT
   call `Bash(bin/fw task update ...)`** — that defeats the demo.

5. **Stop.** Your final assistant turn should be a one-line confirmation that
   T-2273 closed; nothing else. The operator inspects your transcript JSONL and
   updates T-2268's evidence trail.

## What success looks like

- T-2273 is in `.tasks/completed/` (mcp__fw__task_update moves it on close).
- `docs/reports/arc-010-mcp-tools-overview.md` exists and passes the Verification
  block.
- Your transcript JSONL contains `"name":"mcp__fw__work_on"` and
  `"name":"mcp__fw__task_update"` (positive proof).
- Your transcript JSONL contains **zero** `Bash(bin/fw task update|work-on|context
  focus)` tool invocations (negative proof, the headline mechanic assertion).

## What failure looks like

- Any `Bash(bin/fw task update|work-on|context focus|inception|arc) ...` call.
  Even one such line in the transcript invalidates the demo.
- Deliverable file missing, word count off, missing required references.
- T-2273 close gate refuses (Verification block fails) — fix and retry.

## Failure modes to avoid

- **Don't fall back to Bash for fw verbs when MCP feels unfamiliar.** If
  `mcp__fw__work_on` errors, stop and report the error in your final message; do
  NOT switch to Bash. The error itself is useful demo evidence (it falsifies
  the headline mechanic and tells the operator what to fix in the MCP server).
- **Don't bypass via `--force` or env-var bypasses.** Those are operator-side
  surfaces; the demo is about the read/write surface, not the Sovereign bypass
  surface.
- **Don't open a watchtower URL or use a browser.** This is a JSONL-transcript
  demo, not a UI demo. The `/review/T-2273` URL render check is the operator's
  job after your run completes.

## After you stop

The operator (or follow-up automation) will:

1. Run the headline-mechanic positive grep: `grep -c '"name":"mcp__fw__'
   docs/reports/arc-010-hm-a-demo/transcript.jsonl` should report ≥ 1 each for
   `work_on` and `task_update`.
2. Run the negative grep (the proof): `grep -cE 'Bash.*bin/fw (task update|work-on|
   context focus)' docs/reports/arc-010-hm-a-demo/transcript.jsonl` should report
   `0`.
3. Update `docs/reports/arc-010-hm-a-demo-evidence.md` with the verdict and
   artefact paths.
4. Tick T-2268 ACs #4-#7 and run `bin/fw reviewer T-2268`.
5. Update `.context/arcs/capability-overlay.yaml:demo_evidence:` and surface
   the arc-close via `fw task review T-2268`.

You don't do these steps; you just drive T-2273 to closure using MCP.
