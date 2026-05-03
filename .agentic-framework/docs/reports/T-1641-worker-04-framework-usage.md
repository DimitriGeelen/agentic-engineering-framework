# T-1641 Worker 04 — Framework-Side Usage of Orchestrator Arc

**Scope:** does `/opt/999-Agentic-Engineering-Framework` actually USE the
T-1063 / T-1064 / T-1065 / T-1066 features it built into TermLink, or do
they sit dormant in `/opt/termlink`?

## Summary

The arc is **largely dormant in this framework**. Only T-1063 (MCP task
governance) is actively wired — `.mcp.json:24` sets
`TERMLINK_TASK_GOVERNANCE=1` and `agents/context/lib/focus.sh:99` writes
the task-id file the MCP layer reads. T-1064 (`task_type` routing) is
**not used at all** — `agents/termlink/termlink.sh::cmd_dispatch`
(lines 266–309) has no `--task-type` flag, never tags spawned workers
with `task-type:X`, and the dispatch preamble (`agents/dispatch/preamble.md`)
makes no mention of it. T-1065 (`--model`) has a CLI surface in
`agents/termlink/termlink.sh:278,332` but **no caller anywhere in the
framework passes it**. T-1066 (Governance frame 0x8 subscriber) has zero
references in framework code — referenced only in docs/task files. Net:
the framework gets the *gate* benefit (task-id required), but none of
the *routing*, *model selection*, or *observability* benefits the rest
of the arc was built to deliver.

## Per-Feature Wiring Table

| Feature | Used in framework? | Cite | Impact |
|---|---|---|---|
| T-1063: `TERMLINK_TASK_GOVERNANCE=1` | **Yes** | `.mcp.json:24`; `agents/context/lib/focus.sh:99` writes task-id file | Working — MCP tools refuse calls without `task_id` |
| T-1063: `--task` required on dispatch | **Yes** | `agents/termlink/termlink.sh:284` (`die "Missing --task"`) | Working — bash dispatch path also gated |
| T-1064: `task_type` parameter on `orchestrator.route` | **No** | not found — no grep hit for `--task-type`, `task_type=`, or `task-type:` outside task-file metadata | Dormant — framework never asks the orchestrator to route by type |
| T-1064: `task-type:<type>` worker tags | **No** | not found — `cmd_dispatch` builds no such tag; preamble silent | Dormant — even if the orchestrator looked, no specialists are tagged this way |
| T-1065: `--model` flag plumbing | **Partial** | `agents/termlink/termlink.sh:278,332` accept and forward to `claude -p` | Capability exists; **no caller passes it** (no grep hit for `--model X` invocations of `fw termlink dispatch` outside docs) |
| T-1065: `resolve_dispatch_model` / fallback chain | **No (consumer-side)** | runs hub-side; no framework code reads `model_requested`/`model_used`/`fallback_used` from results | Dormant from this side — no auditing, no learning loop using the data |
| T-1066: Governance frame 0x8 / `GovernanceSubscriber` | **No** | zero matches for `GovernanceSubscriber`, `subscribe_governance`, or `governance.frame` in `agents/`, `bin/`, `lib/`, `web/` | Dormant — no framework component consumes the frames |
| Hooks referencing arc | **No** | `.claude/settings.json` has no orchestrator/task-type/governance-frame references | Dormant |
| Dispatch preamble guidance | **No** | `agents/dispatch/preamble.md` mentions neither task_type nor model nor 0x8 | Agents have no reason to start using it |

Note: `task_type` strings found in `lib/pickup.sh:261`, `lib/setup.sh:409`,
`agents/observe/observe.sh:166`, `agents/task-create/update-task.sh:286`
are **unrelated** — they refer to `workflow_type` of framework tasks
being created locally, not the TermLink orchestrator parameter.

## Dormant Capabilities

1. **`task_type` routing (T-1064)** — orchestrator can route by task type but framework never sends one.
2. **Specialist tag convention `task-type:<type>`** — no spawn site applies it.
3. **`--model` selection on dispatch (T-1065)** — flag exists, no caller uses it; framework always gets default model.
4. **Model fallback chain visibility (T-1065)** — `model_requested` / `model_used` / `fallback_used` in result JSON are never read.
5. **`best_model_for(task_type)` learning (T-1590)** — framework feeds the cache nothing because it never sends `task_type` or `model`.
6. **Governance frame 0x8 subscriber (T-1066)** — no framework consumer; pattern matching/emission unused on this side.

## Recommended Follow-Up Tasks

(All `from-T-1641`, scoped to wiring this framework into the arc it shipped.)

1. **Add `--task-type` to `fw termlink dispatch`** — derive from active task's `workflow_type`, tag worker `task-type:<type>`, pass to orchestrator. Tag: `from-T-1641, termlink, t-1064-wiring`.
2. **Tag long-lived specialist sessions with `task-type:<type>`** — e.g. ring20-manager, NTB-ATC sessions, so the routing cache has anything to learn from. Tag: `from-T-1641, termlink, specialists`.
3. **Wire `--model` into dispatch defaults** — let `.framework.yaml` set `FW_TERMLINK_DEFAULT_MODEL` and per-task-type overrides; surface `model_used`/`fallback_used` in the dispatch result manifest. Tag: `from-T-1641, t-1065-wiring`.
4. **Subscribe to Governance frames (0x8) in Watchtower** — render an "orchestrator activity" panel (routes hit, fallbacks fired, breaker trips). Tag: `from-T-1641, t-1066-wiring, watchtower`.
5. **Update `agents/dispatch/preamble.md`** — document task-type and model flags with examples; without preamble guidance the capability stays invisible to dispatching agents. Tag: `from-T-1641, docs`.
6. **Audit / drift-check** — `fw doctor` warning when `TERMLINK_TASK_GOVERNANCE=1` but zero workers carry `task-type:` tags over a rolling window (signal that flags 1+5 above never landed). Tag: `from-T-1641, drift-defense`.

— W04
