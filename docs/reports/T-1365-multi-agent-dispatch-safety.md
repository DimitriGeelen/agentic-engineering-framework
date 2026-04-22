# T-1365: Multi-agent dispatch safety — research artifact

## Context

Termlink (pickup source T-1169) proposes a 5-primitive safety package (P1 worktree, P2 task metadata, P3 dispatch gate, P4 reconciliation, P5 coordination note) to close the gap where today's `fw dispatch` cannot safely run >1 worker editing overlapping files in a shared clone.

## Finding summary

- Shell-side `fw dispatch` has existing safeguards: `agents/monitor/check-dispatch.sh`, 5-parallel Agent cap (CLAUDE.md), write-to-disk convention (T-818), TermLink process isolation.
- No concrete multi-agent merge-conflict incident exists in this framework's episodic memory (`.context/episodic/`) or open concerns register.
- Motivating evidence cited by the pickup is **planned** parallelism (termlink's T-1158+T-1159), not an observed collision.
- Pattern match: L-237 (mitigations shipped without a triggering incident drift toward speculative fixes).

## Recommendation

DEFER primary, BUILD-LIGHT fallback.

- **DEFER:** Do not open P1-P5 build tasks. Wait for a concrete incident or explicit human request for proactive infrastructure.
- **BUILD-LIGHT (if human requests):** Tighten CLAUDE.md §Sub-Agent Dispatch Protocol with a single rule — "Do not dispatch >1 worker touching the same file without worktree isolation." Zero code, ~5 lines of documentation.

## Trigger-list for DEFER → DECOMPOSE

| Trigger | Response |
|---|---|
| First multi-agent merge-conflict incident | DECOMPOSE into 5 per-primitive inceptions |
| Human requests worktree infra ahead of incident | Open P1 inception only (ship P2 metadata alongside) |
| Consumer project reports collision | Escalate priority to horizon:now |

## Primitive-by-primitive scoping (for future DECOMPOSE)

| Primitive | Effort | Depends on | Notes |
|---|---|---|---|
| P1 worktree spawn | ~150 LoC | nothing | Highest mechanical value |
| P2 metadata (`touches:`, `parallelism_class:`) | ~30 LoC | nothing | Prerequisite for P3 |
| P3 dispatch gate | ~100 LoC | P2 corpus | Useless without P2 data |
| P4 reconciliation | ~200 LoC | P1+P2+P3 | Speculative — defer until P1-P3 in use |
| P5 coordination note | ~5 LoC CLAUDE.md | nothing | Fold into BUILD-LIGHT |

## Related work

- T-097 (dispatch protocol) — produced the 5-parallel cap and write-to-disk convention. Explicitly did NOT prescribe worktree.
- T-503 (TermLink integration) — each worker is a separate `claude -p` process, not a subagent sharing parent memory.
- T-879, T-914, T-916, T-1025, T-1026 — dispatch reliability fixes, all landed.

## Decision trail

See task file `.tasks/active/T-1365-pickup-multi-agent-dispatch-safety-model.md` for full Recommendation, Evidence, and trigger-list.
