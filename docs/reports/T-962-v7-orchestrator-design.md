# T-962 v7: Orchestrator-Aware Architecture for Multi-Agent Multi-Provider Terminal Routing

**Task:** T-962 (Inception -- web terminal in Watchtower)
**Date:** 2026-04-06
**Purpose:** Design the session data model, routing architecture, and provider abstraction layer that enables Watchtower's web terminal to manage sessions across multiple AI providers and local shells -- without coupling v1 to decisions that block v2.

---

## 1. Multi-Agent Framework Patterns

### 1.1 CrewAI -- Role-Based Task Routing

CrewAI structures multi-agent work as **Crew -> Agent -> Task** with a process model (sequential, hierarchical, or consensual). Key patterns:

| Concept | Pattern | Relevance to Watchtower |
|---------|---------|------------------------|
| **Agent** | Role + goal + backstory + tools | Maps to our agent definitions (`agents/*/AGENT.md`) -- role-based identity |
| **Task** | Description + expected output + agent assignment | Already modeled in `.tasks/` -- task-agent binding exists |
| **Process** | Sequential (chain), hierarchical (manager delegates), consensual (vote) | Hierarchical maps to our dispatch model (orchestrator -> workers) |
| **Delegation** | Agent can delegate sub-tasks to other agents | Exists via `fw termlink dispatch` and Task tool |
| **Memory** | Short-term (conversation), long-term (vector DB), entity (knowledge graph) | Maps to working/project/episodic memory in `.context/` |

**What we can steal:** CrewAI's `process` enum (sequential/hierarchical) is a clean abstraction for routing. A Watchtower terminal session could declare its process model, and the orchestrator routes accordingly. We don't need CrewAI's agent DSL -- our agents are shell scripts + markdown, not Python classes.

**What we should ignore:** CrewAI's tight coupling between agents and LLM configuration (each agent binds to a specific model). In our model, the session binds to a provider -- the agent is provider-agnostic.

### 1.2 AutoGen -- Conversation Patterns

AutoGen (Microsoft) models multi-agent interaction as **conversations between agents**. Key patterns:

| Concept | Pattern | Relevance |
|---------|---------|-----------|
| **ConversableAgent** | Every agent can send/receive messages | Our agents don't converse -- they dispatch and return results |
| **GroupChat** | N agents in a shared conversation with a manager | Not needed -- our orchestrator is the only conversation hub |
| **Two-agent chat** | Pair of agents ping-ponging | Sequential TDD pattern (T-058) is this |
| **Nested chats** | Agent triggers sub-conversation as a tool | TermLink dispatch is this -- a spawned worker is a nested conversation |
| **Human-in-the-loop** | Human approval at specific steps | Our Tier 0/sovereignty model, but more structural |

**What we can steal:** AutoGen's "termination condition" concept -- conversations end when a condition is met (max turns, keyword, function return). Our dispatch workers use `exit_code` as implicit termination, but we lack explicit termination conditions for interactive sessions. A web terminal session needs: max idle time, max cost, explicit user close.

**What we should ignore:** AutoGen's conversation-centric model. Our agents are task-executors, not conversationalists. The overhead of modeling every dispatch as a "conversation" adds complexity without value.

### 1.3 LangGraph -- State Machine Orchestration

LangGraph models workflows as **directed graphs with state**. Key patterns:

| Concept | Pattern | Relevance |
|---------|---------|-----------|
| **StateGraph** | Typed state flows through nodes | Our task lifecycle (`captured -> started -> issues -> completed`) is a state machine |
| **Nodes** | Functions that transform state | Our agents are nodes -- `create-task.sh`, `healing.sh`, etc. |
| **Edges** | Conditional routing between nodes | Task status transitions are conditional edges |
| **Checkpointing** | State is persisted at each node | Handovers are our checkpoints |
| **Human-in-the-loop** | Graph pauses at specific nodes for human input | Sovereignty gates are this |
| **Subgraphs** | Nested state machines | TermLink dispatch workers are subgraphs |

**What we can steal:** LangGraph's checkpoint model is the closest analog to what we need. A terminal session is a stateful node in a graph. When the session pauses (idle, context exhaustion, human review), its state must be checkpointable and resumable. Our handover system already does this for Claude Code sessions -- the question is whether we can generalize it for arbitrary provider sessions.

**What we should ignore:** LangGraph's graph compilation and execution engine. We're building a session manager, not a workflow engine. The graph topology is implicit in our task system.

### 1.4 Synthesis: What These Frameworks Agree On

All three frameworks converge on these primitives:

1. **Session identity** -- Every agent interaction has a unique, traceable ID
2. **State persistence** -- Sessions can be paused, resumed, and inspected
3. **Termination conditions** -- Sessions end for a reason (success, failure, timeout, budget)
4. **Routing** -- Someone decides which agent/model handles which task
5. **Result collection** -- Results flow back to an orchestrator or shared state

Our framework already has 1 (task IDs), 2 (handovers), 3 (partial -- exit codes only), 4 (manual dispatch), and 5 (`fw bus`). The gap is making these work for interactive terminal sessions that may span multiple providers.

---

## 2. Multi-Provider Abstraction

### 2.1 Current State: `web/llm/provider.py`

The framework already has a clean Strategy-pattern provider abstraction for the Watchtower chat UI:

```
LLMProvider (ABC)
  +-- OllamaProvider    -- local models, streaming
  +-- OpenRouterProvider -- remote API, model catalog
```

`ProviderManager` handles registration, hot-switching, and fallback. This works for **chat completions** -- a request/response cycle with streaming.

**The gap:** Terminal sessions are fundamentally different from chat completions:

| Dimension | Chat (current) | Terminal Session (needed) |
|-----------|-----------------|--------------------------|
| Lifecycle | Request -> Stream -> Done | Spawn -> Interactive -> Persist -> Close |
| State | Stateless (messages in, tokens out) | Stateful (conversation context, file edits, process state) |
| Control | User sends message, waits | User can observe, inject, pause, resume, kill |
| Cost model | Per-request tokens | Continuous (idle cost, context window consumption) |
| Provider API | `chat_stream()` | Provider-specific CLI or API (claude, openai, ollama run) |

### 2.2 Provider Landscape: How They Differ

| Provider | Terminal/Agent Mode | API | Session Model | Local/Remote |
|----------|-------------------|-----|---------------|-------------|
| **Claude Code** | `claude -p "prompt"` or `claude -c` (interactive) | Anthropic API | Context window per session, handover-based continuity | Remote API, local CLI |
| **OpenAI** | `openai` CLI (limited), Codex agent (unreleased), API function calling | OpenAI API | Conversation threads, Assistant API with persistent threads | Remote API |
| **Ollama** | `ollama run model` (interactive REPL) | REST API (`/api/chat`, `/api/generate`) | Stateless per-request, no native session persistence | Local |
| **Gemini** | `gemini` CLI (Google), API streaming | Gemini API | Context caching (paid), no native CLI agent mode | Remote API |
| **Local (shell)** | `bash`, `zsh`, `fish` | PTY/WebSocket | OS process lifecycle, infinite persistence | Local |

**Key insight:** There is no uniform "agent session" API across providers. Each provider has:
- Different invocation mechanisms (CLI binary, API call, REPL)
- Different session persistence models (some stateless, some context-windowed, some thread-based)
- Different cost models (per-token, per-request, free/local)
- Different capability sets (tool use, file editing, code execution)

### 2.3 Abstraction Strategies

#### LiteLLM Pattern (API-Level Abstraction)

LiteLLM normalizes 100+ LLM providers behind OpenAI's chat completion interface. It translates `messages[]` + `model` into provider-specific API calls.

**Relevance:** LiteLLM solves the chat/completion abstraction. It does NOT solve terminal session management. We could use it (or our existing `ProviderManager`) for the chat layer, but terminal sessions need a higher-level abstraction.

**Verdict:** Useful for chat features in Watchtower, orthogonal to terminal session routing.

#### AI Gateway Pattern (Proxy-Level Abstraction)

AI Gateways (Portkey, Helicone, LiteLLM Proxy, Cloudflare AI Gateway) sit between the application and providers, adding:
- Request routing (by model, cost, latency)
- Caching (semantic dedup, prompt cache)
- Rate limiting and cost controls
- Observability (logging, metrics, tracing)
- Fallback chains (try Claude -> fall back to GPT-4 -> fall back to local)

**Relevance:** The gateway pattern is useful for cost control and observability across providers. But for terminal sessions, the "gateway" is not an HTTP proxy -- it's a process manager. The analog is our TermLink dispatch system.

**Verdict:** Gateway-pattern thinking should inform the session manager (cost tracking, fallback, observability) but the implementation is process management, not HTTP proxying.

#### Provider-Neutral Session Protocol (Our Approach)

What we actually need is a **session envelope** that wraps provider-specific invocation:

```
+----------------------------------------------+
|  Session Envelope (provider-neutral)          |
|  - ID, task, tags, status, cost               |
|  - Capabilities (read-only, read-write)       |
|  - Lifecycle (spawn, observe, kill)           |
+----------------------------------------------+
|  Provider Adapter (provider-specific)         |
|  - How to spawn (CLI binary, API call)        |
|  - How to observe (PTY, API polling)          |
|  - How to inject input (PTY, message)         |
|  - How to get cost (API, estimate)            |
|  - How to kill (SIGTERM, API cancel)          |
+----------------------------------------------+
```

This is the Strategy pattern at the session level, not the chat level.

---

## 3. Terminal Session Data Model

### 3.1 Current TermLink Session Model

TermLink dispatch workers store metadata in `/tmp/tl-dispatch/<name>/`:

```
/tmp/tl-dispatch/worker-1/
  prompt.md       # Dispatch prompt
  task            # T-XXX tag (single line)
  meta.json       # { name, project, timeout, task, started, status }
  run.sh          # Worker execution script
  result.md       # Worker output
  exit_code       # Completion marker (0 = success)
  finished_at     # ISO timestamp
  stderr.log      # Error output
  window_id       # macOS terminal window tracking
```

**Strengths:**
- File-based, inspectable, no database dependency
- Task-tagged for traceability
- Event-based completion signaling (`termlink event emit`)

**Weaknesses:**
- No provider metadata (always assumes `claude -p`)
- No cost tracking
- No capability declaration
- No session type distinction (shell vs. AI agent vs. REPL)
- Volatile (`/tmp/` -- lost on reboot)
- No schema enforcement (ad-hoc files, not structured JSON)

### 3.2 Proposed Session Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "TerminalSession",
  "description": "Provider-neutral terminal session descriptor for Watchtower orchestrator",
  "type": "object",
  "required": ["id", "type", "provider", "status", "created"],
  "properties": {

    "id": {
      "type": "string",
      "description": "Unique session identifier",
      "pattern": "^S-[0-9]{4}-[0-9]{4}-[A-Za-z0-9]{4}$",
      "examples": ["S-2026-0406-a1b2"]
    },

    "type": {
      "type": "string",
      "enum": ["shell", "agent", "repl"],
      "description": "Session type: shell (local PTY), agent (AI provider), repl (language REPL)"
    },

    "provider": {
      "type": "object",
      "required": ["name"],
      "properties": {
        "name": {
          "type": "string",
          "enum": ["local", "claude", "openai", "ollama", "gemini", "custom"],
          "description": "Provider identifier"
        },
        "model": {
          "type": ["string", "null"],
          "description": "Model ID if applicable (null for local shell)",
          "examples": ["claude-opus-4-6", "gpt-4o", "llama3:70b", "gemini-2.5-pro"]
        },
        "endpoint": {
          "type": ["string", "null"],
          "description": "API endpoint or binary path",
          "examples": ["https://api.anthropic.com", "/usr/local/bin/ollama", null]
        },
        "version": {
          "type": ["string", "null"],
          "description": "Provider CLI or API version",
          "examples": ["1.0.47", "v1", null]
        }
      }
    },

    "task": {
      "type": ["string", "null"],
      "description": "Framework task reference (null for ad-hoc sessions)",
      "pattern": "^T-[0-9]+$",
      "examples": ["T-962", null]
    },

    "tags": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Freeform tags for filtering and discovery",
      "examples": [["inception", "research"], ["build", "frontend"]]
    },

    "status": {
      "type": "string",
      "enum": ["spawning", "active", "idle", "paused", "completed", "failed", "killed"],
      "description": "Current session lifecycle state"
    },

    "capabilities": {
      "type": "object",
      "properties": {
        "mode": {
          "type": "string",
          "enum": ["read-only", "read-write", "inject-only", "observe-only"],
          "description": "What the operator can do with this session"
        },
        "file_edit": {
          "type": "boolean",
          "description": "Can this session edit files in the project?"
        },
        "tool_use": {
          "type": "boolean",
          "description": "Does this provider support tool/function calling?"
        },
        "streaming": {
          "type": "boolean",
          "description": "Does this provider support streaming output?"
        },
        "context_window": {
          "type": ["integer", "null"],
          "description": "Provider context window in tokens (null if not applicable)",
          "examples": [300000, 128000, null]
        },
        "persistent_thread": {
          "type": "boolean",
          "description": "Does the provider maintain conversation state server-side?"
        }
      }
    },

    "cost": {
      "type": "object",
      "description": "Token usage tracking (tokens only, never dollars)",
      "properties": {
        "input_tokens": { "type": "integer", "default": 0 },
        "output_tokens": { "type": "integer", "default": 0 },
        "cache_read_tokens": { "type": "integer", "default": 0 },
        "cache_write_tokens": { "type": "integer", "default": 0 },
        "total_tokens": { "type": "integer", "default": 0 },
        "model": {
          "type": ["string", "null"],
          "description": "Model used for cost attribution"
        }
      }
    },

    "process": {
      "type": "object",
      "description": "OS-level process tracking (local sessions only)",
      "properties": {
        "pid": { "type": ["integer", "null"] },
        "tty": { "type": ["string", "null"], "examples": ["/dev/pts/3"] },
        "termlink_session": {
          "type": ["string", "null"],
          "description": "TermLink session name if registered"
        },
        "websocket_id": {
          "type": ["string", "null"],
          "description": "WebSocket connection ID for web terminal"
        }
      }
    },

    "created": {
      "type": "string",
      "format": "date-time",
      "description": "Session creation timestamp (ISO 8601)"
    },

    "last_activity": {
      "type": ["string", "null"],
      "format": "date-time",
      "description": "Last observed activity (input or output)"
    },

    "finished": {
      "type": ["string", "null"],
      "format": "date-time",
      "description": "Session end timestamp"
    },

    "exit_code": {
      "type": ["integer", "null"],
      "description": "Process exit code (null if still running or not applicable)"
    },

    "termination_reason": {
      "type": ["string", "null"],
      "enum": [null, "user_close", "task_complete", "timeout", "budget_exhausted", "error", "killed"],
      "description": "Why the session ended"
    },

    "prompt": {
      "type": ["string", "null"],
      "description": "Initial prompt or command (for dispatch workers)"
    },

    "result_path": {
      "type": ["string", "null"],
      "description": "Path to result file (for dispatch workers)",
      "examples": ["docs/reports/T-962-analysis.md", "/tmp/tl-dispatch/worker-1/result.md"]
    },

    "parent_session": {
      "type": ["string", "null"],
      "description": "ID of parent session (for nested/dispatched sessions)",
      "pattern": "^S-[0-9]{4}-[0-9]{4}-[A-Za-z0-9]{4}$"
    }
  }
}
```

### 3.3 Schema Design Decisions

| Decision | Rationale | Alternative Considered |
|----------|-----------|----------------------|
| **Session ID format `S-YYYY-MMDD-XXXX`** | Human-readable, sortable, avoids UUID opacity | UUIDs (too opaque for CLI use) |
| **`type` enum: shell/agent/repl** | Covers all current use cases without over-engineering | Finer-grained types (ssh, docker, etc.) -- deferred |
| **`provider.name` enum with `custom`** | Named providers get first-class support; `custom` is the escape hatch | Open string (no validation) |
| **`capabilities.mode` not per-user** | Session capability is determined at spawn time, not per observer | Per-user RBAC (v2 concern) |
| **`cost` in tokens, never dollars** | Framework convention (user preference); dollar conversion is display-layer | Mixed units |
| **`process.termlink_session`** | TermLink is optional -- field is nullable | Requiring TermLink (breaks portability) |
| **`parent_session`** | Enables dispatch tree reconstruction without a separate relationship table | Separate edges table (over-engineering) |
| **No `output` field** | Session output goes to files (`result_path`) or PTY stream, not the schema | Inline output (context explosion) |

### 3.4 Session Lifecycle State Machine

```
                    +----------+
                    | spawning |
                    +----+-----+
                         | process started / API connected
                         v
                    +----------+
              +---->|  active  |<----+
              |     +----+-----+     |
              |          |           |
              |    idle timeout      | user input / event
              |          |           |
              |          v           |
              |     +--------+      |
              |     |  idle  |------+
              |     +----+---+
              |          |
              |    manual pause
              |          |
              |          v
              |     +--------+
              +-----|  paused | (resume -> active)
                    +----+---+
                         |
          +--------------+--------------+
          |              |              |
     task_complete    timeout       error/kill
          |              |              |
          v              v              v
    +-----------+  +-----------+  +--------+
    | completed |  |  killed   |  | failed |
    +-----------+  +-----------+  +--------+
```

**Transition rules:**
- `spawning -> active`: Process started, PTY connected, or API handshake complete
- `active -> idle`: No I/O for configurable idle timeout (default: 300s)
- `idle -> active`: Any user input or scheduled event
- `active/idle -> paused`: Explicit user action (session preserved, resources held)
- `paused -> active`: Explicit resume
- `* -> completed`: Clean exit (exit code 0, task marked complete)
- `* -> failed`: Non-zero exit, API error, unrecoverable state
- `* -> killed`: User kill, budget exhaustion, timeout, SIGTERM

---

## 4. Architecture Layers

### 4.1 Layer Diagram

```
+-------------------------------------------------------------+
|                    Watchtower Web UI                         |
|  +----------+  +----------+  +----------+  +------------+  |
|  | Terminal  |  | Terminal  |  | Terminal  |  |  Session   |  |
|  |  Tab 1    |  |  Tab 2    |  |  Tab 3    |  |  Manager   |  |
|  | (xterm.js)|  | (xterm.js)|  | (xterm.js)|  |   Panel    |  |
|  +-----+-----+  +-----+-----+  +-----+-----+  +-----+------+ |
|        |              |              |              |        |
|        +--------------+--------------+              |        |
|                       | WebSocket                   | REST   |
+-------------------------------------------------------------+
|                 L4: Transport Layer                          |
|  +--------------------------------------------------------+ |
|  |  WebSocket Router                                      | |
|  |  /ws/terminal/<session-id> -> PTY bridge or API stream | |
|  +--------------------------------------------------------+ |
+-------------------------------------------------------------+
|                 L3: Session Manager                          |
|  +--------------------------------------------------------+ |
|  |  SessionRegistry                                       | |
|  |  - CRUD sessions (create, list, get, update, delete)   | |
|  |  - Lifecycle management (state transitions)            | |
|  |  - Discovery (by task, tag, provider, status)          | |
|  |  - Cost aggregation (per session, per task, per model) | |
|  |  - Persistence (.context/sessions/ YAML files)         | |
|  +--------------------------------------------------------+ |
+-------------------------------------------------------------+
|                 L2: Provider Adapters                        |
|  +----------+ +----------+ +----------+ +--------------+   |
|  |  Local    | |  Claude   | |  Ollama   | |  Future:     |   |
|  |  Shell    | |  Code     | |  Run      | |  OpenAI/     |   |
|  |  Adapter  | |  Adapter  | |  Adapter  | |  Gemini/etc  |   |
|  +----------+ +----------+ +----------+ +--------------+   |
|  Each adapter implements: spawn(), observe(), inject(),     |
|  kill(), get_cost(), capabilities()                         |
+-------------------------------------------------------------+
|                 L1: Process Layer                            |
|  +------------------+  +-------------------------------+    |
|  |  PTY Manager      |  |  TermLink (optional)          |    |
|  |  (pty.fork +      |  |  Session registration,        |    |
|  |   subprocess)     |  |  cross-terminal discovery,    |    |
|  |                   |  |  event signaling              |    |
|  +------------------+  +-------------------------------+    |
+-------------------------------------------------------------+
```

### 4.2 Layer Responsibilities

#### L1: Process Layer
- **What:** OS-level process lifecycle (fork, exec, signal, wait)
- **Components:** Python `pty` module, `subprocess`, optionally TermLink for registration/discovery
- **v1 scope:** `pty.fork()` for local shells, `subprocess.Popen` for `claude -p` / `ollama run`
- **TermLink role:** Optional enhancement -- if installed, sessions are registered for cross-terminal discovery. If not, sessions work fine but are invisible to other terminals.

#### L2: Provider Adapters
- **What:** Translate provider-neutral session operations into provider-specific invocations
- **Interface:** Each adapter implements a `SessionAdapter` protocol:

```python
class SessionAdapter(Protocol):
    """Provider-specific session management."""

    name: str  # "local", "claude", "ollama", etc.

    def spawn(self, config: dict) -> ProcessHandle:
        """Start a session. Returns PID + PTY fd or stream handle."""
        ...

    def capabilities(self) -> dict:
        """Declare what this provider supports."""
        ...

    def inject(self, handle: ProcessHandle, input: str) -> None:
        """Send input to the session (PTY write or API message)."""
        ...

    def observe(self, handle: ProcessHandle) -> AsyncIterator[bytes]:
        """Stream output from the session."""
        ...

    def kill(self, handle: ProcessHandle, signal: int = 15) -> None:
        """Terminate the session."""
        ...

    def get_cost(self, handle: ProcessHandle) -> dict | None:
        """Get current token usage (None for local shells)."""
        ...
```

- **v1 adapters:** `LocalShellAdapter` (bash/zsh via PTY), `ClaudeCodeAdapter` (claude -p via PTY)
- **v2 adapters:** `OllamaAdapter` (ollama run via PTY), `OpenAIAdapter`, `GeminiAdapter`

#### L3: Session Manager
- **What:** Business logic for session lifecycle, routing, and state management
- **Components:** `SessionRegistry` (CRUD + query), session state machine, cost aggregator
- **Persistence:** YAML files in `.context/sessions/` (consistent with framework's file-based pattern)
- **Discovery API:** Filter sessions by task, tag, provider, status -- used by both CLI and web UI
- **v1 scope:** Create/list/get/delete sessions, basic lifecycle transitions

#### L4: Transport Layer
- **What:** WebSocket routing between browser terminals and backend sessions
- **Components:** Flask-Sock WebSocket handler, connection multiplexer
- **Pattern:** One WebSocket per terminal tab, routed to the correct session by ID
- **v1 scope:** `/ws/terminal/<session-id>` endpoint, bidirectional byte stream

### 4.3 Provider Adapter Details

#### LocalShellAdapter (v1)

```python
class LocalShellAdapter:
    name = "local"

    def spawn(self, config):
        # pty.fork() -> returns (pid, fd)
        # Shell: config.get("shell", os.environ.get("SHELL", "/bin/bash"))
        # Working directory: config.get("cwd", PROJECT_ROOT)
        pid, fd = pty.fork()
        if pid == 0:
            os.execvp(shell, [shell])
        return ProcessHandle(pid=pid, fd=fd)

    def capabilities(self):
        return {
            "mode": "read-write",
            "file_edit": True,   # it's a shell, it can do anything
            "tool_use": False,
            "streaming": True,
            "context_window": None,  # no AI context
            "persistent_thread": False,
        }

    def get_cost(self, handle):
        return None  # local shells have no token cost
```

#### ClaudeCodeAdapter (v1)

```python
class ClaudeCodeAdapter:
    name = "claude"

    def spawn(self, config):
        # Spawn claude -p "prompt" or claude -c (interactive) via PTY
        # Unset CLAUDECODE env var (T-576: allow nested sessions)
        # Set PROJECT_ROOT for framework hooks
        cmd = ["claude"]
        if prompt := config.get("prompt"):
            cmd += ["-p", prompt, "--output-format", "text"]
        else:
            cmd += ["-c"]  # interactive/continue mode

        pid, fd = pty.fork()
        if pid == 0:
            env = os.environ.copy()
            env.pop("CLAUDECODE", None)
            env["PROJECT_ROOT"] = config.get("cwd", PROJECT_ROOT)
            os.execvpe(cmd[0], cmd, env)
        return ProcessHandle(pid=pid, fd=fd, provider_meta={"model": "claude-opus-4-6"})

    def capabilities(self):
        return {
            "mode": "read-write",
            "file_edit": True,
            "tool_use": True,
            "streaming": True,
            "context_window": 300000,  # FW_CONTEXT_WINDOW
            "persistent_thread": False,
        }

    def get_cost(self, handle):
        # Read from session JSONL transcript if available
        return parse_claude_session_cost(handle.pid)
```

#### OllamaAdapter (v2)

```python
class OllamaAdapter:
    name = "ollama"

    def spawn(self, config):
        model = config.get("model", "llama3:70b")
        cmd = ["ollama", "run", model]
        # Ollama run is an interactive REPL -- same PTY pattern as shell
        pid, fd = pty.fork()
        if pid == 0:
            os.execvp(cmd[0], cmd)
        return ProcessHandle(pid=pid, fd=fd, provider_meta={"model": model})

    def capabilities(self):
        return {
            "mode": "read-write",
            "file_edit": False,   # ollama run has no file editing
            "tool_use": False,    # no tool use in REPL mode
            "streaming": True,
            "context_window": None,
            "persistent_thread": False,
        }

    def get_cost(self, handle):
        return {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0,
                "model": handle.provider_meta["model"]}
```

---

## 5. Routing Patterns

### 5.1 Human Selects Provider (v1)

The simplest routing: user picks from a dropdown when creating a new terminal tab.

```
+-------------------------------------+
|  New Terminal                       |
|                                     |
|  Provider: [Local Shell v]          |
|            +------------------+     |
|            | Local Shell      |     |
|            | Claude Code      |     |
|            | Ollama (llama3)  |     |
|            +------------------+     |
|                                     |
|  Task: [T-962 v] (optional)        |
|  Tags: [inception, research]        |
|                                     |
|  [Open Terminal]                    |
+-------------------------------------+
```

**Implementation:** Watchtower renders available providers from `SessionManager.list_adapters()`. User selects one, submits form. Backend calls `adapter.spawn()`, creates session record, returns WebSocket URL for the xterm.js client.

**Why v1:** Zero AI routing logic needed. Users know what they want. The session schema captures the choice for later analysis.

### 5.2 Task-Aware Dispatch (v2)

The orchestrator suggests a provider based on task metadata:

```python
def suggest_provider(task: dict) -> str:
    """Suggest a provider based on task characteristics."""
    wtype = task.get("workflow_type")

    if wtype in ("build", "refactor", "test"):
        return "claude"  # needs file editing + tool use
    elif wtype == "inception":
        return "claude"  # needs research + reasoning
    elif wtype == "specification":
        return "ollama"  # local model, cheaper for drafting
    else:
        return "local"   # default to shell
```

**Why v2:** Requires understanding of task semantics and provider capabilities. v1 collects the data; v2 analyzes it.

### 5.3 Load Balancing / Fallback (v2+)

Multiple sessions across providers with automatic fallback:

```
Primary: Claude Code (best quality, highest cost)
    |
    +-- Rate limited? -> Fall back to Gemini
    +-- API down?     -> Fall back to Ollama (local)
    +-- Budget exceeded? -> Fall back to Ollama (free)
```

**Why v2+:** Requires cost tracking, provider health monitoring, and fallback chain configuration. None of these are v1 priorities.

### 5.4 Session Handoff (v3)

Transfer a conversation from one provider to another mid-session:

```
Claude Code session (context at 280K)
    -> Extract conversation summary (handover)
    -> Spawn new session on Gemini (fresh context)
    -> Inject summary as system prompt
    -> Continue work seamlessly
```

**Why v3:** Requires conversation export, cross-provider prompt translation, and state reconciliation. Our handover system is a manual version of this for Claude Code -> Claude Code transfers. Generalizing it across providers is a research problem.

---

## 6. TermLink as Session Layer: Assessment

### 6.1 What TermLink Provides

| Primitive | What It Does | Terminal Session Use |
|-----------|-------------|---------------------|
| `termlink spawn` | Create named session with tags | Session registration |
| `termlink interact` | Run command, get JSON output | Health checks, status queries |
| `termlink pty inject` | Send input to session | Command injection |
| `termlink pty output` | Read recent output | Session observation |
| `termlink event emit/wait` | Inter-session signaling | Completion notification |
| `termlink discover` | Find sessions by tags | Multi-session discovery |
| `termlink attach` | Full TUI mirror | Remote session access |
| `termlink list` | List all sessions | Session inventory |
| `termlink clean` | Deregister stale sessions | Cleanup |

### 6.2 TermLink Strengths for This Use Case

1. **Cross-terminal discovery** -- Watchtower can find and display sessions that were started from the CLI, not just web-created sessions
2. **Bidirectional attach** -- Remote observation of running sessions (the `attach` primitive)
3. **Event system** -- Worker completion signaling without polling
4. **Session tagging** -- Already supports `task=T-XXX` convention
5. **Platform-tested** -- 264 tests, real-world use in dispatch scenarios

### 6.3 TermLink Limitations

1. **macOS-centric** -- Terminal window management uses AppleScript. The Linux server (LXC 170) runs headless -- no Terminal.app windows to manage.
2. **PTY-only** -- TermLink manages terminal sessions (PTY processes). API-only providers (OpenAI, Gemini without CLI) don't have PTY sessions to manage.
3. **No web transport** -- TermLink speaks PTY, not WebSocket. The web terminal needs a WebSocket bridge regardless.
4. **No cost tracking** -- TermLink tracks process state, not token usage.
5. **Optional dependency** -- Framework works without TermLink installed. The session layer can't require it.

### 6.4 Verdict: TermLink as Optional Enhancement, Not Foundation

**TermLink is the right tool for cross-terminal coordination but the wrong foundation for the session layer.**

The session layer must:
- Work without TermLink installed (portability -- Directive 4)
- Handle both PTY sessions and API-only providers
- Bridge to WebSocket for the web UI
- Track cost and capabilities (TermLink doesn't do this)

**Recommended architecture:**

```
SessionManager (L3) -- owns the session lifecycle
    |
    +-- Always: SessionRegistry (YAML files in .context/sessions/)
    +-- Always: Provider Adapters (L2, spawn/observe/inject/kill)
    +-- Always: WebSocket Bridge (L4, xterm.js <-> PTY/stream)
    |
    +-- Optional: TermLink Integration
        +-- On session spawn: register with termlink (if installed)
        +-- On session kill: deregister
        +-- Enables: CLI discovery (termlink list shows web-created sessions)
        +-- Enables: CLI attach (termlink attach for remote observation)
        +-- Enables: Event-based completion signaling
```

TermLink enriches the session layer but doesn't define it. A session created from the web UI works fine without TermLink. If TermLink is installed, the session is additionally registered for cross-terminal visibility.

---

## 7. What v1 Needs to Not Block v2

These are the architectural commitments v1 must make to keep the door open:

### 7.1 Must Have (Architectural Commitments)

| Commitment | Why | Cost |
|------------|-----|------|
| **Session schema with `provider` field** | v2 needs multi-provider sessions; v1 must not hardcode "local shell" assumptions | Low -- schema design, no runtime cost |
| **Provider adapter interface** | v2 adds adapters; v1 must define the interface so adapters are drop-in | Low -- one Protocol class, two implementations |
| **Session ID format** | v2 needs to reference sessions across systems; v1 must use a stable, unique ID format | Zero -- pick a format, use it |
| **File-based session persistence** | v2 needs session history; v1 must write session records to `.context/sessions/` | Low -- YAML file per session |
| **WebSocket per session** | v2 needs multiplexed sessions; v1 must not use a single shared WebSocket | Low -- URL routing by session ID |
| **Capabilities declaration** | v2 routes by capability; v1 must capture what each session can do | Low -- static dict per adapter |
| **Cost tracking stubs** | v2 optimizes by cost; v1 must have the `cost` field even if it's always zeros for local shells | Zero -- schema field, null for local |

### 7.2 Should Have (Reduces v2 Risk)

| Feature | Why | Cost |
|---------|-----|------|
| **Two adapters: LocalShell + ClaudeCode** | Proves the adapter interface works for real with two different providers | Medium -- second adapter implementation |
| **Session list API** | v2 builds session management UI on top of list/filter APIs | Low -- CRUD endpoints |
| **TermLink registration on spawn** | v2 needs cross-terminal visibility; v1 can register sessions if TermLink is available | Low -- optional `termlink spawn` call |
| **Session state persistence across server restart** | v2 reconnects to surviving sessions; v1 must not lose session records on Watchtower restart (PTYs die, but records survive) | Low -- YAML file per session |

### 7.3 Explicitly NOT v1 (Can Safely Ignore)

| Feature | Why Not | v2+ Concern |
|---------|---------|-------------|
| **Auto-routing** | Users pick provider manually in v1 | v2: suggest based on task type |
| **Load balancing** | Single provider per session in v1 | v2+: multi-provider fallback |
| **Session handoff** | No cross-provider state transfer in v1 | v3: handover generalization |
| **Cost optimization** | No provider cost comparison in v1 | v2: cheaper provider for cheaper tasks |
| **Per-user RBAC** | Single-user in v1 (Watchtower is an ops tool) | v2+: if multi-user is needed |
| **OpenAI/Gemini adapters** | v1 ships with local + claude only | v2: add when providers have CLI agents |
| **Session recording/replay** | Not needed for v1 terminal | v2+: audit trail, debugging |
| **Conversation export** | No cross-provider handoff in v1 | v3: session handoff prerequisite |
| **AI-powered routing** | Human selection is fine for v1 | v2+: task-aware dispatch |
| **Hub infrastructure** | TermLink hub adds operational complexity | v2+: only if 3+ machines need coordination |

---

## 8. Implementation Sketch: v1 Session Manager

### 8.1 File Structure

```
web/
  terminal/
    __init__.py
    session.py          # SessionManager, Session dataclass
    registry.py         # SessionRegistry (CRUD, persistence)
    adapters/
      __init__.py
      base.py           # SessionAdapter protocol
      local_shell.py    # LocalShellAdapter (pty.fork)
      claude_code.py    # ClaudeCodeAdapter (claude -p via PTY)
    transport.py        # WebSocket handler (Flask-Sock)
    routes.py           # REST API endpoints (/api/sessions/*)
.context/
  sessions/             # Session YAML files (persistent)
    S-2026-0406-a1b2.yaml
    S-2026-0406-c3d4.yaml
```

### 8.2 Key Integration Points

#### With Existing Framework

| Integration | How |
|-------------|-----|
| **Task system** | Session schema has `task` field -> links to `.tasks/active/T-XXX.md` |
| **Context fabric** | Register `web/terminal/` components in `.fabric/components/` |
| **Budget system** | ClaudeCode adapter reads `.context/working/.budget-status` |
| **TermLink** | Optional: `termlink spawn` on session create, `termlink clean` on session destroy |
| **Bus system** | Dispatch workers can post results via `fw bus post` from within their session |
| **Watchtower UI** | New `/terminal` page with xterm.js tabs, session manager panel |

#### With xterm.js (from v1 research)

```javascript
// Client-side: create terminal + connect to session
async function openSession(sessionId) {
    const term = new Terminal({ cursorBlink: true });
    const fitAddon = new FitAddon.FitAddon();
    term.loadAddon(fitAddon);
    term.open(document.getElementById(`terminal-${sessionId}`));
    fitAddon.fit();

    const ws = new WebSocket(`ws://${location.host}/ws/terminal/${sessionId}`);
    const attachAddon = new AttachAddon.AttachAddon(ws);
    term.loadAddon(attachAddon);

    // Handle resize
    term.onResize(({ cols, rows }) => {
        ws.send(JSON.stringify({ type: 'resize', cols, rows }));
    });
}
```

### 8.3 Minimal v1 API Surface

```
POST   /api/sessions          Create session (provider, task, tags)
GET    /api/sessions          List sessions (filter by status, task, provider)
GET    /api/sessions/<id>     Get session details
DELETE /api/sessions/<id>     Kill and remove session
PATCH  /api/sessions/<id>     Update session (tags, status)
WS     /ws/terminal/<id>      WebSocket bridge to session PTY
```

---

## 9. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **PTY leaks** -- spawned processes not cleaned up on crash | Medium | High (zombie processes) | Session registry tracks PIDs; cleanup on startup; periodic reaper |
| **WebSocket storms** -- many tabs, many connections | Low | Medium (resource exhaustion) | Max sessions config; idle timeout; connection limits |
| **Provider API changes** -- Claude/OpenAI/Ollama CLI interfaces change | Medium | Medium (adapter breakage) | Adapter pattern isolates changes; version pinning |
| **TermLink unavailable** -- headless Linux server, no TermLink installed | High (LXC 170) | Low (optional feature degrades gracefully) | All TermLink calls are conditional; session layer works without it |
| **Context explosion** -- displaying session list with full metadata | Medium | High (if returned to AI context) | List API returns summary fields only; detail by explicit GET |
| **Security** -- web terminal as attack surface | Medium | High | Auth required; session-scoped PTY; no shared shell; CSP headers |

---

## 10. Open Questions for Human Decision

1. **Session storage location:** `.context/sessions/` (framework convention) or `web/data/sessions/` (web-specific)? Recommendation: `.context/sessions/` -- consistent with framework patterns, visible to CLI tooling.

2. **Multi-tab vs. multi-window:** Should Watchtower support multiple terminal tabs in one page (like VS Code) or one terminal per browser window? Recommendation: Multi-tab -- matches VS Code UX, enables session comparison, single WebSocket management point.

3. **Default provider:** When user opens a new terminal without selecting provider, should it default to local shell or Claude Code? Recommendation: Local shell -- lowest friction, no cost, no API dependency.

4. **Session persistence policy:** Should sessions survive Watchtower server restart? PTY processes will die, but should we attempt to re-spawn them? Recommendation: No auto-respawn. Mark sessions as `failed` with `termination_reason: "server_restart"`. User explicitly creates new sessions.

5. **TermLink registration scope:** Register all web-created sessions with TermLink, or only dispatch workers? Recommendation: All sessions -- enables `termlink list` to show the full picture.

---

## Sources

- CrewAI documentation and source (github.com/crewAIInc/crewAI)
- AutoGen documentation (microsoft.github.io/autogen/)
- LangGraph documentation (langchain-ai.github.io/langgraph/)
- LiteLLM documentation (docs.litellm.ai)
- Existing framework code: `web/llm/provider.py`, `agents/termlink/termlink.sh`, `lib/bus.sh`, `lib/dispatch.sh`
- T-962 v1 report (OSS terminal libraries)
- T-549 OpenClaw design patterns report
- T-598 dispatch/TermLink bridge research
- T-108 agent communication bus research
