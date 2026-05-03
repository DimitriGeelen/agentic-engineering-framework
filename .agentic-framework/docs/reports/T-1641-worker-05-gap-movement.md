# T-1641 Worker W05 — Gap Movement (G-011 / G-015 / G-017)

**Question:** T-1061 claimed the orchestrator arc would move G-011 (PostToolUse advisory-only), partially move G-015 (sub-agent results bypass), and at least surface G-017 (proposal/suggestion layer). Did it?

## Summary

The arc shipped exactly **one** narrow, opt-in mitigation on G-011 (T-1063: MCP `task_id` parameter, gated by `TERMLINK_TASK_GOVERNANCE=1`) and explicitly **disclaimed** G-015 in the inception artefact itself. G-017 was named in the T-1061 doc and then never touched by any phase. None of the three gap entries in `.context/project/concerns.yaml` were updated, re-reviewed, or had `related_task` widened during the arc — last_reviewed dates are still 2026-02-21 / 2026-03-06 / 2026-03-09, all predating T-1061's inception (2026-04-21). The arc moved code; it did not move the register.

## Per-gap status

| Gap | T-1061 claim | Actual movement | Verdict |
|-----|--------------|----------------|---------|
| **G-011** PostToolUse advisory-only | "MCP-level enforcement is structural… G-011 ceases to exist at this layer" (T-1061 §Constitutional, line 153) | T-1063 added `task_id` to `termlink_exec/spawn/dispatch/interact`, **opt-in via env var**, structural error if missing. Applies only to cross-session MCP calls. Native Claude Code PostToolUse hooks unchanged. Gap entry untouched (last_reviewed 2026-02-21). | **Partially mitigated, not registered.** Moves the needle for MCP-mediated work in /opt/termlink, but does not reduce in-process Claude Code hook risk that G-011 actually describes. Register is stale. |
| **G-015** Sub-agent results bypass task governance | "Caveat on G-015: Sub-agent governance… remains unsolved at the TermLink layer. This requires Claude Code-level changes or filesystem enforcement — outside TermLink's architectural scope" (T-1061 line 156) | Zero. Acknowledged-and-deferred, as documented. No phase touched it. `fw bus` (the partial mitigation) predates the arc. Gap entry untouched (last_reviewed 2026-03-06). | **Unmoved by design.** T-1061 was honest about this; the arc cannot fix in-process Task-tool sub-agents. |
| **G-017** Execution gates miss proposal/suggestion layer | Named in T-1061 §Constitutional ("known gaps G-011, G-015, G-017") with no concrete plan | Zero. No phase added any reasoning-layer enforcement. Hooks still fire on tool use, not on suggestions. Gap entry untouched (last_reviewed 2026-03-09). | **Mentioned only.** The arc's architecture (deterministic substrate at MCP/orchestrator level) is structurally incapable of intercepting reasoning, so naming G-017 here was aspirational at best. |

## Concerns.yaml audit (60-day window)

`git log --since="60 days ago" -- .context/project/concerns.yaml`: 35 commits modify the file. Zero touch G-011, G-015, or G-017. The arc completed (T-1061→T-1066, ~2026-04-21–04-29) without any companion bookkeeping commit. The last substantive edits to these three entries are the original registrations (T-228, T-329, T-372), all from Feb–Mar 2026.

## Honest answer

The orchestrator arc **claimed** to address three governance gaps and **actually moved one of them, narrowly, opt-in, and only for the cross-session MCP path** — while leaving the gap register untouched so a reader of `concerns.yaml` would never know the work happened. G-015 was disclaimed in the inception (correctly: out of architectural scope). G-017 was name-checked with no plan and no delivery. The arc's gap-movement story is therefore: **1 of 3 partially-moved-but-unregistered, 2 of 3 unmoved.** This matches the broader T-1641 finding: code shipped, governance hygiene did not.

## Recommended follow-ups (from-T-1641)

1. **T-NEW: Refresh G-011 register entry** — record T-1063 as a partial mitigation (cross-session MCP only, opt-in), keep gap open for in-process hooks, update last_reviewed. (Tag: from-T-1641)
2. **T-NEW: Make `TERMLINK_TASK_GOVERNANCE=1` the default** — the opt-in flag means the mitigation is structurally absent until a human flips it; this is exactly the "policy silently defaulted" pattern T-1641 surfaced. (Tag: from-T-1641)
3. **T-NEW: Add audit check that orchestrator-arc deliverables are actually invoked** — would have caught that the framework doesn't USE its own routing (W04 territory) and that gap-register entries went stale during a multi-task arc. (Tag: from-T-1641)
4. **T-NEW: Register a new gap "Arc completion does not require concerns-register hygiene"** — six tasks shipped citing three gaps; zero updated the register. This is a meta-gap about arc bookkeeping. (Tag: from-T-1641)
5. **G-017 explicit deferral** — if no enforcement at the reasoning layer is feasible, mark G-017 `status: accepted-risk` with that rationale rather than leaving it `watching` while no one watches. (Tag: from-T-1641)
