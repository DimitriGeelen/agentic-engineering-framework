# Pending Inception Decisions — 2026-04-05

41 inception tasks await go/no-go decisions. Review at: http://192.168.10.107:3000/approvals

## With Recommendation (can batch-decide)

### GO (8 tasks)
| Task | Summary |
|------|---------|
| T-436 | Auto-compact YOLO mode — automatic compact → resume → autonomous proceed |
| T-599 | MCP server for TermLink — expose session/file/remote/hub as structured tools |
| T-686 | Article angle 3 — landscape differentiation research |
| T-696 | Qualify Path C as repeatable pattern — template + second experiment |
| T-697 | KCP (Knowledge Context Protocol) — Path C codebase ingestion |
| T-698 | TermLink dispatch observability — interactive vs headless worker mode |
| T-707 | ntfy deep-dive — Path C ingestion + framework notification enhancement |
| T-818 | TermLink dispatch result persistence — ensure worker outputs survive budget exhaustion |

### NO-GO (3 tasks)
| Task | Summary |
|------|---------|
| T-316 | Layered CLAUDE.md (framework base + project overrides) |
| T-702 | Single-source-of-truth generation — generate CLAUDE.md from manifest |
| T-703 | Incremental adoption levels — fw init --level 1|2|3 |

### DEFER (6 tasks)
| Task | Summary |
|------|---------|
| T-558 | Build task risk signal detection — PreToolUse gate for high-impact builds |
| T-579 | Idempotency/dedup layer — prevent hook re-entry and double task completion |
| T-600 | TermLink attach-self — register existing shell session as endpoint |
| T-699 | fw stats — SQLite event logging for observability |
| T-700 | 3-tier validation consistency across all fw tools |
| T-701 | Context budgeting hints — token estimates and load priority in component cards |

## Without Recommendation (need review — 24 tasks)

Inception tasks with no recommendation yet. Review individually at /approvals.

## Immediate Decisions Needed

**T-864** (NO-GO recommended):
```
cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-864 no-go --rationale "Episodic summaries already capture 80% of desired stats"
```

**T-866** (GO recommended):
```
cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-866 go --rationale "flock guard, timeout, stale reaper all feasible"
```
