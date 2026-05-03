# Orchestrator-rethink arc — closure-readiness packet

**Captured:** 2026-05-02T05:20Z (last revised 2026-05-02T05:38Z, post-T-1665)
**Arc:** `orchestrator-rethink` (17/20 completed, 85%, audit-detective WARN firing — and now firing in production cron, post-T-1665)
**Anchor task:** T-1641
**Decision needed:** `fw arc close orchestrator-rethink --decision "..."`

This packet collects the §Arc Completion Discipline (G-062) three-question
evidence in one place so the human review at closure time is a click-through,
not a scavenger hunt.

## §ACD Q1 — "Did the integrated system run end-to-end on a fresh substrate?"

**Answer:** YES on both populating paths.

| Path | Substrate | Closure evidence |
|------|-----------|------------------|
| Framework dispatch | `agents/termlink/termlink.sh` cmd_dispatch | `docs/reports/T-1643-Q1-wire-evidence.md` (2026-05-02T05:09 section) — live `meta.json` with all four orchestrator-aware fields populated; canonical `task:T-1643, task-type:build` tags; round-trip `confirmed.` via T-1663 stream-json |
| /opt/termlink CLI | `scripts/tl-dispatch.sh` cmd_spawn | `/opt/termlink/docs/reports/U-005-meta-populate.md` — 21/21 substrate tests pass; commit `143cd870` |

**Wire evidence at a glance** (live `q1-wire-evidence` worker, 2026-05-02T05:09:21Z):

```json
{
  "task": "T-1643",
  "task_type": "build",
  "model": "haiku",
  "model_used": "haiku",
  "fallback_used": true,
  "started": "2026-05-02T05:09:21Z"
}
```

Watchtower `/orchestrator` "Recent dispatches" panel renders this entry
live with task link, `build` task-type pill, and the populated values.

## §ACD Q2 — "Did any silently-defaulted constants escape human review?"

**Answer:** NO. All 13 routing-policy constants enumerated and approved
under T-1642 with explicit GO decision recorded 2026-05-01T17:08:40Z.

| # | Constant | Decision | Source of truth |
|---|----------|----------|-----------------|
| 1 | task_type taxonomy | Closed enum mirroring `workflow_type` | T-1642 Decision block |
| 2 | DEFAULT_MODEL_FALLBACK | `[opus-4-7, sonnet-4-6, haiku-4-5]` quality-first | T-1642 Decision block |
| 3 | PROMOTION_THRESHOLD (bypass) | 5 successes / 0 failures + warning emit | T-1642 Decision block |
| 4 | PROMOTION_THRESHOLD (template_cache) | Diverge: 3 successes | T-1642 Decision block |
| 5 | FAILURE_THRESHOLD (circuit) | 3 consecutive + per-model override | T-1642 Decision block |
| 6 | COOLDOWN (circuit) | 60s linear | T-1642 Decision block |
| 7 | DEFAULT_TTL_HOURS (route cache) | 168h (7d) | T-1642 Decision block |
| 8 | CONFIDENCE_THRESHOLD | 0.8 (documented) | T-1642 Decision block |
| 9 | task-type tag prefix | `task-type:` keep + `arc:` namespace | T-1642 Decision block |
| 10 | Discovery filter (no-match) | Soft preference + opt-in `--strict` | T-1642 Decision block |
| 11 | Cost weighting | Defer (T-1637 horizon: later) | T-1642 Decision block |
| 12 | Concurrency cap | 5 hub-side, 10 client-side | T-1642 Decision block |
| 13 | Success/failure attribution | `InfraFailure` non-blocking, `CommandFailure` blocking | T-1642 Decision block |

**Framework-side constants registered in `lib/config.sh`:**

- `DISPATCH_MODEL_DEFAULT` (line 167) — empty default, T-1643/W3
- `ARC_COMPLETION_THRESHOLD` (line 168) — 0.80 default, T-1656

**Implementation follow-ups** (Q2 *implementation* — distinct from Q2 *audit*):
T-1642 proposed B1/B2/B3 (substrate-side) and B4 (framework-side) as separate
build tasks. **Not yet filed** — Q2 closure is satisfied by the human-reviewed
decisions; lifting constants from code to config is forward work, not a
closure blocker.

## §ACD Q3 — "Does the framework that built the arc actually USE the arc?"

**Answer:** YES. Multiple framework paths now consume orchestrator substrate:

| Framework path | Consumes | Evidence |
|----------------|----------|----------|
| `fw termlink dispatch` | task-type derivation, model resolution, populated meta.json | T-1643/W1+W3+W4 + T-1664 commit `5fd678eb0` |
| `fw termlink spawn` | task-type tagging | T-1643/W2 |
| `agents/dispatch/preamble.md` | orchestrator-aware dispatch contract | T-1643/W6 |
| Watchtower `/orchestrator` | live render of recent dispatches + audit + sessions | T-1643/W5, T-1647 |
| Watchtower `/arcs/orchestrator-rethink` | arc surface with audit-detective | T-1656 + T-1657 + T-1661 + T-1662 |
| `fw audit` arc-completion section | warns at ARC_COMPLETION_THRESHOLD | T-1656 |
| `fw task review` arc-parent gate | three-question check enforced interactively | T-1657 |
| `agents/audit/orchestrator-mcp-scan.sh` | MCP `task_id` enforcement audit | T-1646 |

**Live signal proof:** the arc-completion detective on this very arc is
firing right now: 16/19 (84%) ≥ ARC_COMPLETION_THRESHOLD (80%), badge
"audit warns ≥80%" rendered on `/arcs/orchestrator-rethink`. The mechanism
built under the arc is producing the closure signal for the arc itself.

## Constituent task status (20 total)

**Completed (17):**
- T-1641 (anchor — orchestrator-arc reconsideration)
- T-1642 (Arc A — routing-policy consultation, GO with 13 constants)
- T-1644 (Arc C — drift defenses)
- T-1645 (G-015 reframe — sub-agent /tmp/ bypass)
- T-1646 (MCP-tool task_id audit)
- T-1648 (governance frame 0x8 golden test)
- T-1649 (tag-format lint)
- T-1650 (route_cache schema test)
- T-1651 (TermLink list --json contract)
- T-1652 (cross-repo fabric cards)
- T-1654 (canonical `task:` tag fix)
- T-1655 (G-062 mech #1 — §ACD codified)
- T-1656 (G-062 mech #2 — fw audit arc-completion)
- T-1657 (G-062 mech #3 — fw task review extra gate)
- T-1663 (dispatch run.sh stream-json visibility)
- T-1664 (framework dispatch path populates model_used/fallback_used)
- T-1665 (arc-completion detective wired into oe-daily cron — fires in production)

**Started-work, awaiting human review (3):**
- T-1643 (Arc B — framework-side wiring) — [GO via `fw task review T-1643`](http://192.168.10.107:3000/review/T-1643)
- T-1647 (Watchtower /orchestrator page) — [GO via `fw task review T-1647`](http://192.168.10.107:3000/review/T-1647)
- T-1661 (Arc system MVP) — [GO via `fw task review T-1661`](http://192.168.10.107:3000/review/T-1661)

Each of these has all Agent ACs ticked, a GO Recommendation block with concrete
evidence, and a single `[REVIEW]` Human AC remaining (visual judgment).

## What "closure" looks like

Per CLAUDE.md §ACD: closure is a **declaration**, not a state change. The
framework cannot verify the meaning behind it; only the human can. The closure
declaration ends with a one-liner:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc close orchestrator-rethink \
    --decision "Q1 closed both paths (framework dispatch + /opt/termlink CLI) with live wire evidence; Q2 closed via T-1642 GO covering all 13 constants; Q3 closed via 8 framework paths consuming substrate including the arc's own self-monitoring"
```

This:
1. Sets `status: closed` and `closed_at: <now>` in `.context/arcs/orchestrator-rethink.yaml`
2. Writes the decision string to the arc file
3. Auto-clears `arc-focus.yaml` if this was the focused arc
4. Stops the audit-detective WARN (closed arcs aren't checked)

**Not closed by `fw arc close`:** the three started-work tasks remain as
partial-complete. Their human review proceeds independently — closing the arc
does not auto-close member tasks. That's deliberate (the arc is a coordination
construct, not a task aggregator).

## Recommended decision string

> Q1 closed both paths (framework dispatch + /opt/termlink CLI) with live wire
> evidence; Q2 closed via T-1642 GO covering all 13 constants; Q3 closed via 8
> framework paths consuming substrate including the arc's own self-monitoring.

Override freely — the framework records whatever string is passed.

## Post-closure follow-up (optional, not blocking)

- File T-1642-B1/B2/B3 in /opt/termlink to lift policy constants to `routing-policy.yaml`
- File T-1642-B4 in framework for `fw config` plumbing
- Tick `[REVIEW]` ACs on T-1643/T-1647/T-1661 to move them to `completed/`

None of these are required for arc closure. They're forward work that the
arc's groundwork enables.
