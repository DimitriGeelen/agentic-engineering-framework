# T-564: OpenClaw Comparative — Agent Isolation and Session Management

## Comparison: How Agents Are Isolated

### OpenClaw Agent Isolation

| Mechanism | Purpose |
|-----------|---------|
| Session keys | `agent:<agentId>:<scope>` — each agent has unique namespace |
| Channel isolation | Messages routed by channel, agents can't cross channels |
| Profile boundaries | Each agent has its own auth profile, tool set, config |
| Subagent isolation | Spawned agents get restricted tool sets via policy |
| Process registry | `runtime-state.ts` — PID tracking with TTL-based cleanup |
| Crash recovery | Kill children, flush queues, archive transcript on crash |

### Our Framework Agent Isolation

| Mechanism | Purpose |
|-----------|---------|
| Process isolation | Each agent runs as a bash subprocess |
| Task scoping | Each agent works on one task (focus.yaml) |
| Session stamping | T-560 — focus_session prevents stale focus reuse |
| TermLink isolation | Dispatched workers run as independent `claude -p` processes |
| Budget isolation | Each session tracks its own token usage |
| Hook enforcement | PreToolUse hooks enforce per-session governance |

### Gap Analysis

Already covered by T-582 (session-scoped agent isolation). The key finding from that analysis:
- Two concurrent agents sharing `.context/working/` corrupt each other
- Solution: hybrid session namespace (Option D) for focus.yaml and budget-status
- This is architecturally analogous to OpenClaw's session keys

### Key Finding: Same Problem, Different Scale

OpenClaw solves multi-agent isolation at platform scale (thousands of concurrent agents across channels). We need it at project scale (2-5 concurrent agents sharing one project). T-582's Option D is the right solution for our scale.

## Recommendation: NO-GO (Covered by T-582)

This comparative confirms T-582's design direction. No additional isolation mechanisms needed beyond what T-582 proposes.
