# T-565: OpenClaw Comparative — Monitoring and Observability

## Comparison: How Each Framework Observes Agent Behavior

### OpenClaw Observability Stack

**Source:** T-549 architecture mapping, T-583 background health check analysis

| Layer | Mechanism | Frequency | What it detects |
|-------|-----------|-----------|-----------------|
| Health monitor | `channel-health.ts` | Every 5 min | Stale sockets, stuck sessions, half-dead connections |
| Readiness probe | `readiness.ts` | On-demand (HTTP) | Aggregated health across all subsystems |
| Transcript logging | Session-level | Continuous | Full conversation + tool call history |
| Metrics export | Prometheus-style | Continuous | Message counts, latency, error rates |
| Event bus | `event-bus.ts` | Real-time | Inter-component signals, failure propagation |
| Process registry | `runtime-state.ts` | Continuous | Running agents, PID tracking, TTL-based cleanup |

### Our Framework Observability Stack

| Layer | Mechanism | Frequency | What it detects |
|-------|-----------|-----------|-----------------|
| Cron audit | `audit.sh` via cron | Every 15 min | Full compliance scan (148+ checks) |
| Pre-push audit | `pre-push` hook | Before every push | Same compliance scan |
| PostToolUse checkpoint | `checkpoint.sh` | Every tool call | Budget level, auto-handover trigger |
| PreToolUse gates | 3 hooks | Every Write/Edit/Bash | Task state, Tier 0, budget |
| Error watchdog | `error-watchdog.sh` | Every tool call | Error patterns in tool output |
| Watchtower UI | Web dashboard | Continuous | Tasks, metrics, discoveries, approvals |
| Discovery engine | `scanner.py` | Periodic | Omission detection, trend analysis, anomalies |
| Episodic memory | Post-completion | Per task | Condensed task histories for pattern mining |
| Metrics history | `metrics-history.yaml` | Daily | Velocity, traceability, health trends |
| Handover system | Session end | Per session | State capture for session continuity |

### Gap Analysis

| Observability Concern | OpenClaw | Our Framework | Gap |
|----------------------|----------|---------------|-----|
| Real-time agent health | 5-min background monitor | None (between doctor runs) | **Gap** (T-583 addresses) |
| Compliance scanning | No equivalent | 148+ check audit system | We're ahead |
| Trend detection | Basic metrics export | Discovery engine with anomaly detection | We're ahead |
| Conversation logging | Full transcript | JSONL transcript (Claude Code built-in) | Parity |
| Visual dashboard | No web UI | Watchtower (tasks, metrics, fabric, approvals) | We're ahead |
| Process health | PID tracking + TTL | Watchtower cron PID tracking | Parity |
| Session continuity | No equivalent | Handover system + episodic memory | We're ahead |
| Pattern mining | No equivalent | Failure/success patterns + healing loop | We're ahead |
| Context budget | N/A (server-side) | Budget gate + checkpoint monitoring | We're ahead |

### Key Finding: Fundamentally Different Approaches

OpenClaw uses **real-time infrastructure monitoring** (health probes, metrics, process registry) because it's a running server that must stay up.

Our framework uses **compliance-based observability** (audit checks, discovery patterns, episodic summaries) because it's a governance system that must enforce rules.

**What we could adopt from OpenClaw:**
1. **Background health probe** — already designed in T-583. OpenClaw's 5-min health check is the inspiration.
2. **Process registry with TTL** — relevant for TermLink dispatch cleanup. We have basic PID tracking for Watchtower but not for dispatched agents.

**What OpenClaw could learn from us:**
- Compliance auditing (they have none)
- Task traceability (they have none)
- Pattern-based learning (they have none)
- Visual dashboard with approval workflows (they have none)

## Recommendation: NO-GO on New Mechanisms

T-583 (background health probe) already captures the only adoptable pattern. No additional monitoring mechanisms needed from this comparative.

## Dialogue Log

- Cross-referenced T-583 (background health check design), T-549 (architecture mapping)
- Our observability stack is significantly more comprehensive for governance use cases
