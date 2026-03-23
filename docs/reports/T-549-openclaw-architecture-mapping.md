# T-007: OpenClaw Architecture Mapping

## Overview

OpenClaw is a gateway-centric personal AI assistant. All communication flows through a WebSocket control plane (`ws://127.0.0.1:PORT`). The architecture is modular: channels are plugins, agents are isolated per-session, and the LLM provider is abstracted behind a multi-provider failover system.

## 1. Gateway Server

### Lifecycle

Entry: `startGatewayServer(port, opts)` in `src/gateway/server.impl.ts`

1. **Configuration** — Load config, validate, migrate legacy entries, auto-enable plugins
2. **State Init** — Create HTTP server, WebSocket server, gateway runtime state
3. **Sidecar Startup** — Spawn browser control, Gmail watcher, hooks, channels, plugins, model prewarm
4. **Event Loop** — Attach WebSocket handlers, broadcast managers, session lifecycle listeners
5. **Shutdown** — `gateway.close()` stops HTTP, closes WebSocket clients, SIGTERM handlers

Serves three surfaces:
- **WebSocket** — RPC from control UI, apps, external clients
- **HTTP** — Chat completions (OpenAI-compatible), OpenResponses API, plugin hooks, control UI
- **Canvas Host** — Visual workspace on internal port

### RPC Method Registry

`handleGatewayRequest()` at `src/gateway/server-methods.ts:100`

50+ methods in namespaced flat map. Each handler follows:
```typescript
type GatewayRequestHandler = (opts: GatewayRequestHandlerOptions) => Promise<void> | void
```

Authorization: role check (operator/node/admin) → scope validation → rate limiting.

Categories: `chat.*`, `sessions.*`, `channels.*`, `config.*`, `agent.*`, `nodes.*`, `wizard.*`, `health.*`, `cron.*`, `skills.*`, plus many more.

### Runtime State

`createGatewayRuntimeState()` holds:
- HTTP/WebSocket servers + listeners
- Client set (`GatewayWsClient`)
- Broadcasting functions (dispatch events to connected clients)
- Node registry (mobile/web nodes, subscription routing)
- Chat run state (message buffers, abort controllers per run ID)
- Session event subscriber registry
- Deduplication map (idempotency keys)
- Cron service, secrets, model catalog, exec approvals

### Key Patterns

1. **Request-scoped context** — Every RPC request gets a context object (loggers, state, broadcast fns)
2. **Subscription model** — Clients subscribe to session/chat/node events; gateway broadcasts changes
3. **Queue-based chat** — Chat runs queued per session (one active LLM run per session)
4. **Event-driven agent** — Pi agent emits events; gateway listens and broadcasts to WebSocket clients
5. **Deduplication** — Idempotency keys prevent duplicate processing
6. **Plugin hooks** — Methods extensible via plugin hook registry
7. **Rate limiting** — Control-plane writes rate-limited per client; auth brute-force protected

## 2. Agent Runtime

### Execution Model

**In-process embedded with gateway fallback:**
- **Primary:** Embedded Pi agent runtime (`pi-embedded-runner.ts`) using `@mariozechner/pi-coding-agent` SessionManager
- **Fallback:** Gateway RPC via WebSocket (for network-accessible agents)
- **Two paths:** `agentCommand()` (embedded, local) and `agentViaGatewayCommand()` (gateway HTTP POST)
- **Multi-agent routing:** Per-session agents via SessionKey, idle lanes + subagent lanes

### Tool Call Flow

```
LLM Decision → Tool Validation → Policy Enforcement → Execution → Result Storage

1. LLM emits tool_use via Pi agent streaming
2. Extract tool call from message
3. runBeforeToolCallHook() enforces:
   - Tool loop detection (max consecutive same-tool)
   - Policy checks (allowlist/deny, profile, group rules, subagent isolation)
4. Execute: tool.execute(toolCallId, params)
5. Store result in session history + transcript
6. Stream back to LLM for next turn
```

### Provider Abstraction

Multi-provider with failover:
- **Providers:** Anthropic, OpenAI, Google, Bedrock, Ollama, Vercel AI Gateway, custom, 10+ others
- **Auth:** Profile-based system with cooldown + failure recovery
- **Model selection:** Config primary → fallbacks → env overrides → auth profile rotation
- **Failover:** On auth/billing/overflow errors, auto-rotate to next profile or fallback model

### Key Types

| Type | Purpose |
|------|---------|
| `SessionManager` | Pi agent core: message history, tool execution loop |
| `AgentTool<T,R>` | Tool definition: name, schema, execute() |
| `ModelRef` | `{provider, model}` canonical LLM identifier |
| `ToolPolicy` | Allowlist/deny rules with profile inheritance |
| `OpenClawTools` | Aggregated tool set: core + plugin + channel tools |

## 3. Channel Routing

### Route Resolution

`resolveAgentRoute()` uses tiered binding matching:

1. `binding.peer` — Exact DM/group match
2. `binding.peer.parent` — Thread parent inheritance
3. `binding.guild+roles` — Discord guild + role
4. `binding.guild` — Discord guild only
5. `binding.team` — Teams org match
6. `binding.account` — Account-scoped fallback
7. `binding.channel` — Channel-wide default

Returns: agentId, sessionKey, mainSessionKey, matchedBy (for debugging).

Route cache: invalidates on config change, max 4000 entries.

### Session Key Derivation

Format: `agent:<agentId>:<scope>`

Variants:
- Main: `agent:main:main`
- Per-peer DM: `agent:main:direct:<peerId>`
- Per-channel-peer: `agent:main:<channel>:direct:<peerId>`
- Group: `agent:main:<channel>:group:<peerId>`

Identity links optional — unify user across channels.

### Access Control

- **Allowlists:** Compiled to O(1) sets. Source types: wildcard, id, name, tag, username, slug
- **Mention gating:** Groups can require bot mention. Bypass for authorized commands
- **Command gating:** Per-channel command access rules

## 4. Workspace Isolation

Each agent gets isolated workspace:
- Agent workspaces: `~/.openclaw/state/workspace-<agentId>`
- Agent config: `~/.openclaw/state/agents/<agentId>/agent/`
- Session isolation: different channels/accounts create distinct sessionKeys
- No shared state across sessions: independent conversation, memory, Pi execution context

## 5. Assessment

### Strengths
- **Clean gateway abstraction** — RPC-based, extensible, well-typed
- **Strong isolation** — Per-session agent execution, no shared state leakage
- **Excellent failover** — Multi-provider with automatic rotation and cooldown
- **Plugin architecture** — 80+ extensions via clean SDK contract
- **Event-driven** — Subscription model avoids polling, enables real-time streaming

### Weaknesses
- **Monolithic gateway** — 80+ TS files in src/gateway/, server-methods.ts is very large
- **Pi agent coupling** — Tightly bound to specific agent runtime (`@mariozechner/pi-coding-agent`)
- **Complex routing** — 7-tier binding priority can be hard to reason about
- **Session key complexity** — Many derivation variants, identity links add another layer

### Adoptable Patterns
1. **Request-scoped context** — Avoids global singletons, good for testing
2. **RPC method registry** — Flat map with authorization, extensible via hooks
3. **Queue-based chat** — Serializes LLM access per session, prevents race conditions
4. **Multi-provider failover** — Profile rotation with cooldown, auto-recovery
5. **Session key derivation** — Deterministic, composable, cacheable
6. **Plugin hook system** — Before/after hooks on methods for extension points
