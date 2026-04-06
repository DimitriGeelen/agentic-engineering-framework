# T-962: Orchestrator-Aware Design Patterns for Multi-Agent Terminal Routing

**Task:** T-962 (Inception — Web Terminal in Watchtower)
**Date:** 2026-04-06
**Scope:** Design consideration for v7 web terminal, not build scope

---

## 1. Multi-Agent Framework Analysis

### 1.1 CrewAI — Role-Based Orchestration

**Core abstraction:** An agent is defined by `role`, `goal`, `backstory`, and `tools`. This maps to how humans think about teams — each agent has a job title and purpose.

**Routing:** Tasks are assigned to agents within a "crew" using three process types:
- **Sequential** — agents run in order, output of one feeds the next
- **Hierarchical** — a manager agent delegates to workers, can override decisions
- **Consensual** — agents vote on decisions (rarely used in practice)

**State:** Task outputs pass between agents as structured data. No shared mutable state — communication is mediated through task outputs, not direct messaging.

**Provider:** Single-provider per agent (whichever LLM backs it). No built-in multi-provider abstraction.

**Strengths:** Under 20 lines of Python for a working multi-agent system. MCP support native. Developer experience is excellent.

**Weaknesses:** No checkpointing for long-running workflows. Error handling is coarse-grained. Limited control over agent-to-agent communication.

**Relevance to us:** The role/goal/backstory pattern maps well to our existing agent model (agents/{audit,context,git,healing}/AGENT.md already define purpose and scope). CrewAI's task-output-as-communication matches our bus protocol.

### 1.2 AutoGen (Microsoft) — Conversation-Based Orchestration

**Core abstraction:** Agents are conversational participants. A `GroupChatManager` orchestrates multi-agent conversations by selecting who speaks next.

**Routing:** Four selection strategies:
- **round_robin** — fixed order
- **random** — random selection
- **manual** — human picks
- **auto** — the manager's LLM selects based on conversation context (default)

**State:** Shared conversation history. All agents see all messages. The GroupChatManager broadcasts each message to all participants.

**Provider:** Originally single-provider. v0.4 (AG2) added pluggable LLM backends. Now merging with Semantic Kernel into Microsoft Agent Framework (MAF).

**Relevance to us:** The GroupChat pattern is closest to what a web terminal would do — multiple agents in a shared conversation space, with the human selecting which agent responds. The `auto` selection strategy (LLM picks the best agent) is a future v3+ feature.

### 1.3 LangGraph — Graph-Based Orchestration

**Core abstraction:** A DAG where nodes are agents/functions and edges are data flows. A centralized `StateGraph` maintains overall context.

**Routing:** Conditional edges route execution based on agent outputs or state conditions. Explicit, reducer-driven state schemas using Python's `TypedDict` and `Annotated` types.

**State:** Immutable state management — each agent receives current state, returns updated version. New state version created per step (no race conditions, but memory grows).

**Provider:** Provider-agnostic through LangChain's LLM abstraction layer.

**Relevance to us:** The state-graph pattern maps to our task lifecycle (`captured -> started -> issues -> completed`). LangGraph's conditional routing is how we'd implement "if agent fails, route to healing agent" in an automated orchestrator. The TypedDict state schema approach informs our session schema design.

### 1.4 Common Patterns Across Frameworks

| Pattern | CrewAI | AutoGen | LangGraph | Our Framework |
|---------|--------|---------|-----------|---------------|
| Agent identity | role/goal/backstory | system message | node function | AGENT.md |
| Task routing | crew process type | GroupChatManager | conditional edges | human selection |
| State passing | task outputs | conversation history | state graph | bus + context fabric |
| Agent registry | crew definition | GroupChat members | graph nodes | agents/ directory |
| Capability matching | tools list | agent descriptions | node metadata | AGENT.md capabilities |
| Provider abstraction | none (single LLM) | pluggable (v0.4+) | via LangChain | none (Claude only) |

**Universal pattern: the agent registry.** Every framework maintains a registry of available agents with their capabilities. This is the minimum viable abstraction for routing.

---

## 2. Multi-Provider Abstraction

### 2.1 LiteLLM — The De Facto Standard

LiteLLM provides a single OpenAI-compatible interface to 140+ providers (Claude, GPT, Gemini, Ollama, Bedrock, etc.). It handles:
- **Model routing** — map `model: "claude-sonnet-4-6"` to the right API
- **Cost tracking** — per-request token costs across providers
- **Load balancing** — distribute across multiple API keys/endpoints
- **Fallbacks** — if Provider A fails, try Provider B
- **Caching** — response caching for identical queries
- **Rate limiting** — respect provider rate limits

**Key insight:** LiteLLM normalizes everything to OpenAI's chat completion format. This means the routing layer doesn't need to know provider-specific details — it just sends `model: "provider/model-name"`.

### 2.2 Provider-Neutral Session Design

A provider-neutral session needs:

1. **Normalized input** — all providers accept messages in `{role, content}` format (OpenAI standard)
2. **Normalized output** — stream tokens as Server-Sent Events regardless of provider
3. **Capability flags** — not all providers support tools, vision, code execution
4. **Cost normalization** — token counts mapped to a common unit

**What this means for us:** The web terminal doesn't need to implement 4 different APIs. It implements ONE (the OpenAI chat format, which LiteLLM normalizes to) and routes via provider metadata.

### 2.3 The Claude Code Exception

Claude Code is NOT a chat API — it's an agentic CLI tool with its own session management, tool use, and context. A web terminal that routes to Claude Code is fundamentally different from one that routes to the Claude API:

| Aspect | Chat API (Claude/GPT/Gemini) | Claude Code CLI |
|--------|------------------------------|-----------------|
| Interface | HTTP API (request/response) | PTY (interactive terminal) |
| State | Stateless (messages array) | Stateful (conversation context) |
| Tools | API-defined tool use | File system, bash, MCP |
| Session | Ephemeral (per-request) | Persistent (long-running process) |

**Design implication:** The web terminal must support TWO session types from day one:
1. **PTY sessions** — interactive terminal processes (Claude Code, shell, future agentic CLIs)
2. **API sessions** — stateless chat completions (Claude API, OpenAI API, Ollama)

TermLink already handles type 1. Type 2 is new.

---

## 3. Session Data Model

### 3.1 Proposed Session Schema

```json
{
  "session": {
    "id": "S-20260406-1234",
    "name": "auth-refactor",
    "type": "pty | api | hybrid",
    "status": "active | idle | completed | failed",
    "created": "2026-04-06T12:34:00Z",
    "last_activity": "2026-04-06T12:45:00Z",

    "provider": {
      "name": "claude-code | claude-api | openai | ollama | shell",
      "model": "claude-opus-4-6 | gpt-4.1 | llama3 | null",
      "endpoint": "https://api.anthropic.com | http://localhost:11434 | null",
      "version": "1.0.40"
    },

    "task": {
      "id": "T-042",
      "name": "Add OAuth support",
      "type": "build"
    },

    "capabilities": {
      "tools": true,
      "vision": true,
      "code_execution": true,
      "file_system": true,
      "interactive": true,
      "streaming": true
    },

    "access": {
      "mode": "read-write | read-only | inject-only",
      "owner": "human",
      "observers": []
    },

    "metrics": {
      "tokens_in": 0,
      "tokens_out": 0,
      "tool_calls": 0,
      "duration_seconds": 0
    },

    "routing": {
      "fallback_provider": null,
      "max_tokens": null,
      "temperature": null,
      "tags": ["auth", "backend"]
    },

    "termlink": {
      "session_name": "worker-auth-refactor",
      "pid": 12345,
      "tty": "/dev/pts/3"
    }
  }
}
```

### 3.2 Field Rationale

| Field Group | v1 Use | v2+ Use |
|-------------|--------|---------|
| `id`, `name`, `status` | Session management | Same |
| `type` | Distinguish shell vs Claude Code | Add API sessions |
| `provider.name` | Always "claude-code" or "shell" | Route to any provider |
| `provider.model` | Display only | Model selection UI |
| `task` | Link to framework task | Auto-routing by task type |
| `capabilities` | Feature detection | Capability-based routing |
| `access.mode` | Observer vs interactive | Multi-user access control |
| `metrics` | Display token counts | Cost optimization, budget enforcement |
| `routing` | Not used in v1 | Fallback chains, load balancing |
| `termlink` | PTY session metadata | Same (PTY sessions only) |

### 3.3 Why These Fields Matter

**`type` field:** The most important v1 decision. PTY sessions (Claude Code, shell) use terminal I/O. API sessions use HTTP streaming. The UI rendering, input handling, and lifecycle management are fundamentally different. Getting this distinction into the schema from day one prevents a rewrite.

**`provider` object:** Even in v1 (Claude-only), having `provider.name` and `provider.model` as structured fields means the UI can display "Claude Code (opus-4-6)" and the backend can route without parsing strings. When v2 adds OpenAI, no schema change needed.

**`capabilities` flags:** Prevents the "does this session support file uploads?" problem. Instead of checking provider name, check `capabilities.vision`.

**`access.mode`:** Three levels:
- `read-write` — full interactive control (the session owner)
- `read-only` — observe output only (Watchtower dashboard view)
- `inject-only` — can send input but can't see output (automated dispatch)

---

## 4. Architecture Layers

```
+--------------------------------------------------+
|                    UI Layer                        |
|  Watchtower Web UI (Flask + xterm.js + WebSocket) |
|  - Session list with provider/status indicators   |
|  - Terminal emulator (PTY sessions)               |
|  - Chat interface (API sessions)                  |
|  - Session creation wizard (provider + model)     |
+--------------------------------------------------+
                        |
+--------------------------------------------------+
|                 Routing Layer                      |
|  Session Manager (Python)                         |
|  - Create/destroy sessions                        |
|  - Route input to correct backend                 |
|  - Aggregate metrics                              |
|  - [v2] Capability matching                       |
|  - [v2] Load balancing / fallback                 |
+--------------------------------------------------+
                        |
          +-------------+-------------+
          |                           |
+---------+----------+  +------------+---------+
|   PTY Backend      |  |   API Backend        |
|   (TermLink)       |  |   (v2 — LiteLLM)    |
|                    |  |                      |
| - Shell sessions   |  | - Claude API         |
| - Claude Code      |  | - OpenAI API         |
| - Future agentic   |  | - Ollama (local)     |
|   CLIs             |  | - Gemini API         |
+--------------------+  +----------------------+
```

### 4.1 Layer Responsibilities

**UI Layer** (Watchtower):
- Renders terminal (xterm.js) for PTY sessions
- Renders chat UI for API sessions (v2)
- Session list sidebar showing all active sessions with status badges
- "New Session" dialog: select type (shell/Claude Code/[v2: API provider])
- WebSocket for real-time terminal I/O

**Routing Layer** (Session Manager):
- Maintains session registry (in-memory + `.context/sessions/` on disk)
- Creates sessions by dispatching to the correct backend
- Proxies input/output between UI and backend
- Tracks metrics (tokens, duration, tool calls)
- [v2] Implements capability-based routing
- [v2] Handles provider fallback chains

**PTY Backend** (TermLink):
- Manages actual terminal processes
- Provides `spawn`, `interact`, `pty inject/output` primitives
- Handles process lifecycle (start, monitor, kill)
- Session discovery via tags

**API Backend** (v2 — LiteLLM or direct):
- Manages stateless chat completion sessions
- Normalizes provider APIs to common format
- Handles streaming (SSE)
- Tracks token usage per request

### 4.2 Data Flow: PTY Session

```
User types in xterm.js
  → WebSocket message to Flask
  → Session Manager looks up session by ID
  → Routes to PTY backend (TermLink)
  → termlink pty inject <session> <input>
  → Process receives input
  → Process writes output to PTY
  → termlink pty output <session> (polled or event-driven)
  → WebSocket message to xterm.js
  → User sees output
```

### 4.3 Data Flow: API Session (v2)

```
User types in chat UI
  → WebSocket message to Flask
  → Session Manager looks up session by ID
  → Routes to API backend
  → HTTP POST to provider (streaming)
  → SSE chunks arrive
  → WebSocket messages to chat UI
  → User sees response tokens
```

---

## 5. Routing Patterns

### 5.1 v1 — Human Selects

The simplest pattern: human picks "Shell" or "Claude Code" when creating a session. No automated routing.

```
[New Session]
  > Shell (bash)
  > Claude Code
```

This is sufficient for v1 and matches how Claude Code is used today — the human decides when to use it.

### 5.2 v2 — Human Selects Provider + Model

Extend the selector with provider and model:

```
[New Session]
  > Shell (bash)
  > Claude Code (opus-4-6)
  > Claude API (sonnet-4-6)
  > OpenAI (gpt-4.1)
  > Ollama (llama3 — local)
```

The session schema already supports this — `provider.name` and `provider.model` are first-class fields.

### 5.3 v3 — Framework-Assisted Routing

The framework suggests the best agent based on task metadata:

```
Task T-042 (type: build, tags: auth, backend)
  → Framework suggests: Claude Code (opus) for code changes
  → Alternatives: Claude API (sonnet) for quick questions

Task T-043 (type: inception, tags: research)
  → Framework suggests: Claude API (opus) for research
  → Alternatives: OpenAI (gpt-4.1) for second opinion
```

This requires:
- Agent capability registry (what can each provider/model do?)
- Task-to-capability mapping (what does this task type need?)
- Cost/performance heuristics (which option is cheapest for this capability?)

### 5.4 v4 — Automatic Orchestration

Full multi-agent orchestration: the framework decomposes a task and dispatches sub-tasks to the optimal agent/provider combination. This is where CrewAI/LangGraph patterns apply.

**Not in scope for the web terminal inception.** But the session schema and routing layer should not block it.

---

## 6. TermLink as Session Layer

### 6.1 Current TermLink Session Model

TermLink sessions today carry:
- `name` — unique identifier (e.g., "worker-auth-refactor")
- `tags` — key-value pairs (e.g., "task=T-042")
- Events — inter-session signaling (e.g., "worker.done")
- PTY access — inject input, read output

The framework wrapper (`agents/termlink/termlink.sh`) adds:
- Dispatch metadata: `meta.json` with name, project, timeout, task, started, status
- Worker lifecycle: prompt file, result file, exit code, stderr log
- Cleanup: orphan detection and kill

### 6.2 Can TermLink Carry Provider Metadata?

**Yes, via tags.** TermLink tags are arbitrary key-value pairs:

```bash
termlink spawn --name worker-1 --tags "task=T-042,provider=claude-code,model=opus-4-6"
termlink discover --tags "provider=claude-code"
```

This works for PTY sessions. But API sessions don't have a terminal process — they can't be TermLink sessions.

### 6.3 Recommendation: TermLink as PTY Backend, Not Session Registry

TermLink is the right abstraction for PTY sessions. It should NOT be the universal session registry because:

1. API sessions have no PTY — forcing them into TermLink would be a leaky abstraction
2. TermLink's lifecycle is process-based (spawn/kill) — API sessions are request-based
3. Session discovery needs to work across both types — a unified registry is simpler

**Architecture:**
```
Session Registry (framework-level, in-memory + YAML)
  ├── PTY sessions → TermLink backend
  └── API sessions → HTTP backend (v2)
```

TermLink remains the PTY implementation layer. The Session Manager owns the unified registry.

---

## 7. What v1 Needs to NOT Block v2

These are the minimum data model decisions that must be made in v1 to avoid rewriting when multi-provider arrives.

### 7.1 MUST DO in v1

1. **Session schema includes `provider` and `type` fields** — even though v1 only has "shell" and "claude-code". The UI and backend code should reference `session.provider.name` not hardcoded strings.

2. **Session registry is a separate concern from TermLink** — don't store session state only in TermLink tags. Maintain a `sessions.yaml` or in-memory dict that TermLink sessions sync to.

3. **WebSocket protocol is session-type-aware** — messages include `session_id` and `type`. The frontend dispatches to xterm.js (PTY) or chat renderer (API) based on type. Even if v1 only has xterm.js, the protocol should carry the type field.

4. **"New Session" UI is extensible** — use a provider registry (even if hardcoded to two entries) rather than an if/else for "shell" vs "claude-code".

5. **Token metrics are per-session** — track `tokens_in`, `tokens_out` from the start, even for PTY sessions (parse from Claude Code output or estimate). This feeds v2 cost tracking.

### 7.2 Provider Registry (v1 Implementation)

```python
PROVIDERS = {
    "shell": {
        "type": "pty",
        "display_name": "Shell (bash)",
        "command": ["bash"],
        "capabilities": {"interactive": True, "streaming": True},
    },
    "claude-code": {
        "type": "pty",
        "display_name": "Claude Code",
        "command": ["claude", "-p"],
        "capabilities": {"tools": True, "code_execution": True, "interactive": True, "streaming": True},
    },
    # v2: add these entries, no structural change needed
    # "claude-api": { "type": "api", "endpoint": "https://api.anthropic.com/...", ... },
    # "openai": { "type": "api", "endpoint": "https://api.openai.com/...", ... },
    # "ollama": { "type": "api", "endpoint": "http://localhost:11434/...", ... },
}
```

This is a dictionary lookup, not an if/else chain. Adding a provider means adding an entry.

---

## 8. What v1 Can IGNORE

These features are safely deferred without creating architectural debt, as long as the schema decisions in section 7 are respected.

1. **API session backend** — v1 is PTY-only. The schema supports it; the backend doesn't exist yet.

2. **Capability-based routing** — v1 is human-selects. The `capabilities` field exists in the schema but isn't used for routing.

3. **Provider fallback chains** — v1 has one provider. The `routing.fallback_provider` field exists but is null.

4. **Load balancing** — Single instance, no need for request distribution.

5. **Cost tracking** — Token counts are captured in metrics, but no cost calculations. LiteLLM or manual mapping adds this in v2.

6. **Multi-user access control** — v1 is single-user. The `access.mode` field exists but everything is `read-write`.

7. **Agent auto-selection** — v1 is manual. The task-to-agent mapping is a v3 feature.

8. **LiteLLM integration** — Not needed until API sessions are added in v2.

9. **Session handoff** (start with Claude, continue with GPT) — Complex state migration problem. Defer entirely.

10. **Chat UI component** — v1 is terminal-only (xterm.js). Chat rendering for API sessions comes with v2.

---

## 9. Design Principles (from Framework Analysis)

### 9.1 Design for N, Build for 1

The session schema supports N providers. The v1 implementation handles 2 (shell, Claude Code). Adding provider 3 should require:
- One entry in the provider registry
- One backend adapter (PTY or API)
- Zero schema changes

### 9.2 Registry Over Routing Logic

All three frameworks (CrewAI, AutoGen, LangGraph) use an agent registry as the foundation. The routing logic reads from the registry. Our provider registry follows the same pattern — declarative data, not procedural routing.

### 9.3 State Separation

LangGraph's immutable state pattern is instructive: session state should be separate from session I/O. The session schema (metadata, capabilities, metrics) lives in the registry. The session content (terminal output, chat history) lives in the backend (TermLink PTY buffer or API message array).

### 9.4 Two Session Types, One Interface

The web terminal must render both PTY and API sessions through a single session list. The UI treats them uniformly (name, status, provider badge, metrics). Only the rendering component differs (xterm.js vs chat). This is the AutoGen GroupChat insight: multiple agent types, one conversation space.

---

## 10. Summary Table

| Decision | v1 | v2 | v3+ |
|----------|----|----|-----|
| Session types | PTY only | PTY + API | PTY + API + hybrid |
| Providers | shell, claude-code | + claude-api, openai, ollama | + gemini, bedrock, custom |
| Routing | Human selects | Human selects from expanded list | Framework-assisted |
| Session registry | In-memory + YAML | Same + provider metadata | Same + capability index |
| TermLink role | PTY backend | PTY backend (unchanged) | PTY backend (unchanged) |
| Provider abstraction | Hardcoded registry | LiteLLM for API sessions | LiteLLM + custom adapters |
| Cost tracking | Token counts only | Token counts + cost mapping | Budget-aware routing |
| Multi-agent | Single session | Multiple independent sessions | Orchestrated multi-agent |

---

## Sources

- [CrewAI Documentation — Agents](https://docs.crewai.com/en/concepts/agents)
- [AutoGen — Conversation Patterns](https://microsoft.github.io/autogen/0.2/docs/tutorial/conversation-patterns/)
- [AutoGen — Group Chat](https://microsoft.github.io/autogen/stable//user-guide/core-user-guide/design-patterns/group-chat.html)
- [LangGraph — Agent Orchestration Framework](https://www.langchain.com/langgraph)
- [LiteLLM — Multi-Provider Gateway](https://docs.litellm.ai/)
- [Multi-Agent Architecture: Patterns & Production Reality](https://www.truefoundry.com/blog/multi-agent-architecture)
- [Google ADK — Multi-Agent Patterns](https://developers.googleblog.com/developers-guide-to-multi-agent-patterns-in-adk/)
- [Best Multi-Agent Frameworks in 2026](https://gurusup.com/blog/best-multi-agent-frameworks-2026)
- [Microsoft Multi-Agent Reference Architecture](https://microsoft.github.io/multi-agent-reference-architecture/docs/reference-architecture/Reference-Architecture.html)
