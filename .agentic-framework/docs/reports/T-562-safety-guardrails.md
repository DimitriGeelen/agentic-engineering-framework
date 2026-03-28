# T-562: OpenClaw Comparative — Safety Guardrails

## Comparison: Safety Mechanisms

### OpenClaw Safety Guardrails

**Source:** T-549 architecture mapping, T-579 idempotency/dedup analysis

| Mechanism | Purpose | Implementation |
|-----------|---------|----------------|
| Rate limiting | Prevent API abuse, brute-force protection | Per-client write rate limits on control plane |
| Deduplication | Prevent double-processing of messages | 4-layer dedup: message ID, session key, delivery queue, event bus |
| Tool loop detection | Prevent runaway tool calls | Max consecutive same-tool, oscillation detection, total limit |
| Max message limit | Prevent infinite conversation loops | Session-level message count cap |
| Blast radius containment | Isolate failures to single session/channel | Session scoping, channel isolation, profile boundaries |
| Idempotency keys | Prevent duplicate side effects | Keyed async operations, per-message dedup map |
| Auth profile rotation | Handle provider failures gracefully | Auto-rotate on billing/auth errors, cooldown per profile |

### Our Framework Safety Guardrails

| Mechanism | Purpose | Implementation |
|-----------|---------|----------------|
| Budget gate | Prevent context exhaustion | `budget-gate.sh` — blocks Write/Edit at ≥190K tokens |
| Task gate | Prevent ungoverned work | `check-active-task.sh` — blocks without active task |
| Tier 0 blocks | Prevent destructive commands | `check-tier0.sh` — blocks rm -rf, force push, etc. |
| Inception discipline | Prevent premature building | commit-msg hook + inception gate |
| Loop detection | Prevent runaway tool calls | `loop-detect.ts` (T-594) — basic same-tool detector |
| Error watchdog | Detect error patterns | `error-watchdog.sh` PostToolUse hook |
| Auto-handover | Preserve state before crash | `checkpoint.sh` auto-generates handover at critical budget |
| Session stamping | Prevent stale focus bypass | T-560 — focus_session validation |
| Build readiness gate | Prevent unscoped building | G-020 — blocks placeholder ACs |
| Sovereignty gate | Protect human authority | R-033 — blocks agent from completing human-owned tasks |

### Gap Analysis

| Safety Concern | OpenClaw | Our Framework | Gap |
|---------------|----------|---------------|-----|
| Runaway agent (tool loops) | 4-detector loop detection | 1-detector loop detection | **Partial gap** |
| Context exhaustion | N/A (server-side, no context limit) | Budget gate + auto-handover | We're ahead |
| Ungoverned work | No equivalent | Task gate + inception discipline | We're ahead |
| Destructive commands | No equivalent | Tier 0 blocks | We're ahead |
| Double-processing | 4-layer dedup | N/A (single-agent, sequential) | No gap — different architecture |
| Rate limiting | Per-client rate limits | No equivalent | **No gap** — single-agent, no abuse vector |
| Session isolation | Channel + profile boundaries | Session stamping (T-560) | **Partial gap** (T-582 addresses) |
| Provider failover | Profile rotation + cooldown | N/A (single provider: Anthropic) | No gap — different deployment model |

### Key Finding: Architecturally Different Safety Models

OpenClaw is a **multi-tenant server** — its safety concerns are about isolation, abuse prevention, and concurrent access. Our framework is a **single-agent governance system** — our safety concerns are about agent discipline, human authority, and context management.

**We have safety mechanisms OpenClaw doesn't need:**
- Task-first gate (structural enforcement of governance)
- Tier 0 destructive command detection
- Budget/context management
- Inception discipline for exploration vs building
- Human sovereignty protection

**OpenClaw has safety mechanisms we don't need:**
- Rate limiting (no abuse vector in single-agent)
- Deduplication (no concurrent message processing)
- Auth profile rotation (single provider)
- Channel isolation (no channels)

## Recommendation: NO-GO on New Guardrails

The gap analysis shows our framework is **more comprehensive** on the safety concerns relevant to our architecture. The only actionable gap is loop detection robustness (already addressed by T-561's finding — enhance loop-detect.ts).

No new safety guardrails needed from this comparative analysis.

## Dialogue Log

- Built on T-549 architecture mapping and T-579 dedup analysis
- Cross-referenced T-561 tool call enforcement comparative
