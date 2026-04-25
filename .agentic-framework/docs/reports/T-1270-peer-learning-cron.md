# T-1270 — Peer-learning cron: 15-min reflections between TermLink-connected agents

**Status:** INCEPTION captured 2026-04-15. Awaiting GO/NO-GO.

## Working artifact

See `.tasks/active/T-1270-peer-learning-cron-every-15-min-connect-.md` for the full inception (Problem Statement, 6 Assumptions, 6 Spikes, Technical Constraints, Scope Fence, Recommendation).

## Propagation record (2026-04-15)

Pickup envelope created: `.context/pickup/processed/P-022-feature-proposal.yaml`

Injected as proposal to 3 local TermLink sessions:

| Session | Tag | Project | Injected |
|---------|-----|---------|----------|
| tl-4zyplaci | pickup,agent,task:T-012 | /opt/999-Agentic-Engineering-Framework | yes |
| tl-bv4dajie | task=T-012 | /003-NTB-ATC-Plugin | yes |
| tl-vvlizrda | task=T-013 | /003-NTB-ATC-Plugin | yes |

Remote hubs attempted but unreachable:
- ring20-dashboard (192.168.10.121:9100) — connection refused
- ring20-management (192.168.10.122:9100) — connection refused
- .112 hub — unreachable

## Dialogue log

### 2026-04-15 — Inception created in response to operator ask

Operator ask: "please add a cronjob to connect to anyone that you can connect to on termlink every 15 minutes and ask / check / reflect if you can learn something from one another. Make this an inception task and propagate this task to any termlink-connected agent."

Inception authored following the C-001 research-artifact rule and the §Inception Discipline rule (no build artifacts before GO decision).

Propagation executed via (a) local pickup envelope P-022 and (b) `termlink pty inject` to 3 sessions. Remote hubs listed in `~/.termlink/hubs.toml` were tried but all three are currently down — propagation there is DEFERRED until hubs come back up.

## Agent analysis (2026-04-22, S-2026-0422-resume)

### Cost calculation

Polling cost at proposed cadence:
- 15 min × 4 cycles/hr × 24 hr = 96 cycles/day
- 96 × 5 peers × 200 tokens response = 96,000 tokens/day
- Plus 96 × 5 × 150 tokens outbound prompt = 72,000 tokens/day
- **Total ≈ 168K tokens/day per agent purely on peer chatter**

Over an 8-hour active window, ~56K tokens go to cron polling — roughly 1/5 of a single 300K context window per day per agent. Speculative spend.

### Structural objections

1. **Goodhart feedback loop.** A cron that asks "what did you learn?" at 15-min cadence incentivises agents to MANUFACTURE learnings to answer the prompt. Over weeks, the learning register fills with low-signal reflections extracted to satisfy the cron, not observations captured organically.

2. **A5 contradicts A6.** A5 (self-dampening: no response is valid) is necessary to prevent spam but dooms A6 (propagation via inline adoption requests). If peers ignore reflection prompts, they ignore adoption requests on the same channel.

3. **Existing primitives cover the concrete cases.**
   - Pickup envelopes (`fw pickup send`) handle intentional cross-session handoffs.
   - Handovers (`fw handover`) propagate session narrative.
   - The gap is *ad-hoc cross-session query*, not polling.

### Recommended alternative: `fw ask peers "question"`

Agent-initiated command that:
- Enumerates reachable TermLink peers via `termlink fleet doctor`
- Sends question via `termlink remote inject` with 60s timeout
- Collects responses to `.context/mesh/answers/Q-<ts>.yaml`
- Prints digest

Cost profile: pay only when the caller judges the question worth asking. Caller-initiated → caller-accountable. No manufactured-learning feedback loop. Propagation happens organically when peers observe the command in use.

Estimated build: ~150-200 LoC shell + 2 bats tests, ~1 session.

### Recommendation

**NO-GO as scoped; GO-REDESIGN with `fw ask peers` alternative.**

If human still wants the cron, decompose:
- T-1270a: reflection envelope + ingestion (manual invocation only)
- T-1270b: cron scheduler (opt-in via `fw config set PEER_LEARNING_CRON 1`)
- T-1270c: propagation mechanism

Build T-1270a first. Measure signal-to-noise with manual invocations for 1 week. Only proceed to T-1270b if the data justifies it.
