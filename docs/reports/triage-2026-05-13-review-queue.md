# Review-queue triage — 2026-05-13

**Scope:** 33 tasks in `fw review-queue` Human-AC pile. This report consolidates **live-DOM evidence** for the fresh Watchtower-panel tasks (groups A + B) so the human can clear them in one pass instead of opening 13 tabs.

**One-tab bulk surface:** http://192.168.10.107:3000/approvals
**Per-task review surface:** http://192.168.10.107:3000/review/T-XXXX

## Group A — dispatch-safety arc (4 tasks, all 0d)

| Task | Human AC pattern | Evidence (live, just verified) |
|------|-------------------|--------------------------------|
| [T-1805](http://192.168.10.107:3000/review/T-1805) — pause_requested terminal_event class | substrate test pattern | 14 tests pass in `test_dispatch_pause.py` ([pinned](tests/unit/test_dispatch_pause.py)) |
| [T-1806](http://192.168.10.107:3000/review/T-1806) — Resolver risk-policy preamble injection | preamble injected at top of prompt | Block ordering pinned by `test_assemble_prompt_redispatch_block_above_risk_preamble` |
| [T-1807](http://192.168.10.107:3000/review/T-1807) — Workflow schema lint (pause fields) | WARN vs ERROR split | 24 tests in `test_workflow_schema_pause_lint.py`, dead-config double-fire suppressed |
| [T-1810](http://192.168.10.107:3000/review/T-1810) — Watchtower paused-dispatch resolve form | form renders cleanly | Demo doc: [docs/reports/dispatch-safety-arc-demo.md](docs/reports/dispatch-safety-arc-demo.md) — wire-level proof: heading, MED badge, CSRF form, action URL, button text |

**Suggested:** GO all four. Demo evidence file is the headline-mechanic capture; if the human is satisfied, they can also `fw arc close dispatch-safety --demo docs/reports/dispatch-safety-arc-demo.md` afterwards (G-062 closure).

## Group B — orchestrator-rethink arc (9 tasks, all 0d, all targeting `/orchestrator`)

**Live verification surface:** http://192.168.10.107:3000/orchestrator (HTTP 200, 97KB)

DOM grep extracted these section headings and column names from a live curl:

```
<h2>Dispatch substrate</h2>
<h2>Outcome quality</h2>
<h2>Workflow coverage</h2>
<h2>Recent dispatches</h2>
<h2>Reconsideration arc</h2>
<h2>MCP Governance Audit</h2>
<h2>Learned routing</h2>

<h3>By role</h3>
<h3>By task-type</h3>
<h3>By model</h3>
<h3>By worker-kind</h3>

table columns: Model, worker_kind, provider, Routable, Last dispatched, Dispatches,
               Failed, Passed, Pass rate, Success rate, Best model, Fallback?, ...
```

Mapping the panels to the tasks:

| Task | Premise | Evidence found in DOM |
|------|---------|------------------------|
| [T-1792](http://192.168.10.107:3000/review/T-1792) — Dispatch substrate panel: by_model | `<h3>By model</h3>` inside Dispatch substrate | ✓ heading present |
| [T-1794](http://192.168.10.107:3000/review/T-1794) — extend with by_task-type | `<h3>By task-type</h3>` inside Dispatch substrate | ✓ heading present |
| [T-1795](http://192.168.10.107:3000/review/T-1795) — extend with by_worker-kind | `<h3>By worker-kind</h3>` inside Dispatch substrate | ✓ heading present |
| [T-1796](http://192.168.10.107:3000/review/T-1796) — Outcome quality panel | `<h2>Outcome quality</h2>` + descriptive subtitle | ✓ panel + T-1796-marked comment in source |
| [T-1799](http://192.168.10.107:3000/review/T-1799) — Workflow coverage panel | `<h2>Workflow coverage</h2>` | ✓ panel present |
| [T-1801](http://192.168.10.107:3000/review/T-1801) — missing-provider class on Workflow coverage | `<th>provider</th>` + `<th>Routable</th>` columns | ✓ columns present |
| [T-1802](http://192.168.10.107:3000/review/T-1802) — per-workflow last-dispatch timestamp | `<th>Last dispatched</th>` column | ✓ column present |
| [T-1803](http://192.168.10.107:3000/review/T-1803) — Workflow coverage audit: stale-workflow WARN | `workflow_coverage.flag_stale_workflows(r)` | ✓ called at `agents/audit/audit.sh:3335` |
| [T-1797](http://192.168.10.107:3000/review/T-1797) — TermLink worker primitive | `lib/termlink_worker.py` exists (8717 bytes, 2026-05-12) | ✓ file present |

**Suggested:** all 9 ship the visible artefact they promised. GO unless the visual rhythm at `/orchestrator` doesn't match your taste.

**Bonus on closure:** the orchestrator-rethink arc audit (today's `fw audit`) WARNED that this arc is at **28/31 (90%)** — closing these 9 pushes the arc to closure pressure for human-gated `fw arc close orchestrator-rethink`.

## Group C — mid-age dispatch substrate v1 (7 tasks, 3-9d)

These shipped behavioral changes (gates, primitives). Worth a closer read than the panel-render checks above.

| Task | Why it deserves attention |
|------|---------------------------|
| [T-1701](http://192.168.10.107:3000/review/T-1701) | pi RPC backend integration |
| [T-1702](http://192.168.10.107:3000/review/T-1702) | Boundary hook: outside-path arguments scope-tagging |
| [T-1707](http://192.168.10.107:3000/review/T-1707) | `fw doctor` scope tagging (split project vs host) |
| [T-1730](http://192.168.10.107:3000/review/T-1730) | Bash matcher + focus-drift gate (`# --switch-focus` is from here) |
| [T-1731](http://192.168.10.107:3000/review/T-1731) | Human-AC tick guard (blocks agent from checking Human ACs) |
| [T-1762](http://192.168.10.107:3000/review/T-1762) | Task-pair §ACD gate (P-012) |
| [T-1773](http://192.168.10.107:3000/review/T-1773) | Spawn-side dispatch driver |
| [T-1774](http://192.168.10.107:3000/review/T-1774) | `fw resolver run` CLI integration |
| [T-1775](http://192.168.10.107:3000/review/T-1775) | `lib/ollama_loop.py` 2nd worker primitive |

**Suggested:** triage individually at /approvals. No bulk evidence shortcut here — each is a different behavioral surface.

## Group D — promo / launch (3 tasks, 15d)

These need YOUR decision, not verification.

| Task | Decision needed |
|------|------------------|
| [T-332](http://192.168.10.107:3000/review/T-332) | Submit to awesome lists — still on-strategy? |
| [T-334](http://192.168.10.107:3000/review/T-334) | r/ClaudeAI + Show HN launch — timing |
| [T-464](http://192.168.10.107:3000/review/T-464) | PR #6 /capture skill merge |

**No agent evidence applicable** — these are external actions.

## Group E — stale outlier

[T-449](http://192.168.10.107:3000/review/T-449) — **NO-REC, 47d old.** Agent never wrote a `## Recommendation` block for this task. Options:

1. Revive: agent-pass to write Recommendation + ACs, then human reviews
2. DEFER: `bin/fw task update T-449 --horizon later`
3. Kill: `bin/fw task update T-449 --status work-completed --skip-rca` (with rationale)

## DEFER pile (7 tasks, all 15d)

T-1271, T-544, T-550, T-558, T-705, T-844, T-1776 — research / eval ideas. Leave in queue, surface periodically. No action needed unless a stakeholder asks.

## Recommended action

1. Open http://192.168.10.107:3000/approvals
2. Tick Group A (4 tasks) — fresh dispatch-safety, evidence in this file
3. Tick Group B (9 tasks) — `/orchestrator` panels, evidence in this file
4. Skim Group C individually (7 tasks)
5. Decide Group D (3 tasks) — strategy call
6. Resolve Group E (T-449) — revive or kill

Estimated time: 10-15 minutes for groups A+B (the easy 13); rest is judgment.
