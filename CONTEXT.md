# Agentic Engineering Framework

The framework's domain language. Captured during the orchestrator-as-triage architectural rethink (T-1687 / forthcoming arc). Add terms only when they have been explicitly resolved during a grilling session — do not pre-populate from speculation.

## Language

**Agent**:
The parent Claude Code session running the project's CLAUDE.md. Authoritative for (1) task lifecycle — create, ensure-updates, close-with-guards — and (2) work that requires extensive mid-stream operator interaction (inception, grilling, design dialogue). All other substantive work is routed to Workers via dispatch. The Agent does as little of (3) — non-interactive substantive work — as possible.
_Avoid_: Main agent, parent agent, framework agent (all redundant — there is only one Agent in a session). Also avoid framing the Agent as a general reasoning engine — that overstates its role; substantive reasoning on dispatchable work belongs to Workers.

**Orchestration**:
The Agent's responsibility to (a) match incoming work to a Workflow, (b) compose a Delegation envelope from that Workflow's defaults, (c) dispatch the Worker. A verb, not a noun-entity. The Agent does NOT make ad-hoc inline-vs-delegate calls on substantive work. The decision rule is structural: **interactive** work stays inline with the Agent because Workers have no efficient operator-interaction channel; **non-interactive** substantive work dispatches.
_Avoid_: Routing (too narrow — orchestration includes envelope composition, not just lookup), Dispatch (only the last step), Reasoning (overstates — orchestration is mostly table-driven).

**Workflow**:
A named, human-curated configuration that maps a task_type to a Delegation envelope template. Stored as **one YAML file per workflow** in `.context/project/workflows/<task_type>.yaml` — same one-file-per-entity pattern as `.context/arcs/<id>.yaml` and `docs/adr/000X.md`. v1 schema per file (six required fields, plus `worker_kind` and `inline`):
```yaml
# .context/project/workflows/build.yaml
task_type: build
worker_kind: TermLink          # Task | TermLink | pi
model: sonnet                  # alias or full name
effort: medium                 # low | medium | high | xhigh | max
prompt_template: prompts/build.md
allowed_tools: [Read, Edit, Bash, Grep]
cost_cap_usd: 1.50             # optional
cwd: $PROJECT_ROOT
env:                           # optional; redirect endpoint per workflow
  ANTHROPIC_BASE_URL: http://localhost:8000  # e.g. proxy in front of ollama
```
```yaml
# .context/project/workflows/cheap-research.yaml
task_type: cheap-research
worker_kind: pi                # use pi for subscription-backed inference
provider: anthropic-pro        # pi-specific: which pi-backend
model: claude-sonnet-4-6
prompt_template: prompts/research.md
cost_cap_usd: 0                # subscription quota, $0/call
cwd: $PROJECT_ROOT
```
```yaml
# .context/project/workflows/inception.yaml
task_type: inception
inline: true                   # Agent does this; never dispatched
```
Additional fields (`mcp_config`, `add_dirs`, `system_prompt_mode`, `permission_mode`, `disallowed_tools`) graduate into the schema only when a real Worker pattern demands them — no speculation. The Agent reads the workflow file on every dispatch; if a task_type has no file, dispatch falls back to a documented default workflow.
_Avoid_: Profile, Preset, Recipe (all imply UI-decoration; Workflow is load-bearing config).

**Worker**:
A dispatched executor that runs a Delegation envelope. Three wired flavours in v1, each with distinct trade-offs:

- **`Task`** — Claude Code's Task tool sub-agent. In-session, shares context with the Agent. Cheapest to spawn; expensive in parent context budget. Best for quick read-only research within the active session.
- **`TermLink`** — Claude (or any Anthropic-protocol-speaking endpoint) via `claude -p` spawned through TermLink. Full Claude Code ecosystem: MCPs, plugins, all built-in tools, permission modes. Per-workflow `env:` redirects via `ANTHROPIC_BASE_URL` (binary-confirmed: 52 references in claude 2.1.126) — points at Anthropic API directly OR at a proxy (`litellm --anthropic_api_format`, `claude-code-router`, `claude-bridge`) that fronts ollama / OpenAI / OpenRouter / etc. LM Studio has native Anthropic-API-compat. **This is the default Worker path** for any work that benefits from the full Claude ecosystem.
- **`pi`** — `pi` (Pi mono coding-agent, github.com/badlogic/pi-mono) spawned in RPC mode (LF-delimited JSONL stdin/stdout). 23+ providers via API keys, plus **subscription-backed inference** (Anthropic Pro/Max, OpenAI Plus/Pro, GitHub Copilot — zero per-token cost on subscription quotas). Built-in tools only (read/write/edit/bash/grep/find/ls), no native MCP. Best for cost-optimized non-interactive work where subscription quota matters more than tool ecosystem.

The choice between `TermLink` and `pi` for non-Claude work is a trade-off between full Claude Code ecosystem (`TermLink` + proxy) and subscription-cost optimization (`pi`). Workflow files set `worker_kind` per task_type.

Always strictly downstream of the Agent. Workers do the substantive reasoning the Agent intentionally does not. **Envelope fidelity is full only for `TermLink` (with Anthropic-protocol endpoints)**: `allowed_tools`, `mcp_config`, and `permission_mode` map cleanly there. For `pi`, those reduce to its built-in toolset; `mcp_config` is silently ignored unless a pi extension supplies MCP. This asymmetry is intentional and surfaced in workflow validation.
_Avoid_: Sub-agent (ambiguous — Claude Code's "sub-agent" concept conflates Task tool and TermLink), Specialist (overloaded with TermLink's specialist registry).

**Delegation envelope**:
The structured input to a Worker. Composed by the Agent from a Workflow plus the live task context. v1 expansion of a Workflow entry: `worker_kind` (Task | TermLink | provider), `model`, `effort`, `prompt` (template rendered with task context), `allowed_tools`, `cost_cap_usd`, `cwd`. Workers always launch with `--bare` (skip hooks/plugins/auto-memory/CLAUDE.md auto-discovery) — that's a Worker invariant, not a per-workflow knob. The Agent may pass an `overrides` map to apply chat-time user instructions on top of the Workflow defaults. The unit of dispatch.
_Avoid_: Job, Request, Task (collides with the framework's Task concept, T-XXX).

## Relationships

- The **Agent** runs on a model configured per-project (default `opus`, key `AGENT_MODEL` in `.framework.yaml`). The configured model is *the* orchestration model — there is no separate orchestration tier.
- The **Agent**'s job has three slices: (1) **task management** — create, ensure-updates, close-with-guards — done by the Agent, authoritatively; (2) **interactive work** — inception, grilling, design dialogue, anything where operator interjection mid-stream is essential — done by the Agent because Workers cannot efficiently solicit operator input; (3) **dispatch** — all other substantive work, routed to Workers.
- The **Agent** consults **Workflow** files in `.context/project/workflows/<task_type>.yaml` to compose **Delegation envelopes**. The human curates these files (one per task_type); the Agent does not invent envelopes from scratch.
- A **Delegation envelope** is the only artefact a **Worker** sees from the **Agent**.
- The **Agent** observes Worker outcomes (success/failure, cost, duration) and writes them to two artifacts: `route_cache.json` (sparse aggregates per provider+model+task_type, used by the resolver — no info loss but lossy by design) and `dispatches.jsonl` (append-only per-dispatch log: `ts, task_id, workflow_id, provider, worker_kind, model, effort, cost_usd, duration_ms, exit_code, override_applied`). Cache feeds future dispatches; log feeds telemetry / auto-improvement / healing batch jobs. Log rotates monthly to `dispatches-YYYY-MM.jsonl`. Routing memory does NOT override `workflows.yaml` — the human-curated table wins.

## Example dialogue

> **User:** "Run the orchestrator audit refactor."
> **Agent (mentally):** Triage — this is a substantive build. Delegate? Yes — different model class needed for the implementation than for triage. Compose envelope: TermLink worker, model=sonnet, prompt=<crafted>, context_pack={CLAUDE.md fragment scoped to build-task, MCPs limited to read+edit+test, tools={Read, Edit, Bash, Grep}, cwd=this repo}. Dispatch.
> **Worker:** runs the build, writes results, exits.
> **Agent:** observes outcome, updates route_cache, reports to user.

## Flagged ambiguities

- "Framework agent" was used informally to refer to (a) the parent Claude Code session, (b) a hypothetical separate orchestrator entity. **Resolved 2026-05-02**: there is no separate orchestrator. The Agent (singular) does orchestration as one of its responsibilities. "Framework agent" should be retired in favour of "Agent."
- "Orchestrator" was used as a noun-entity in early drafts of the rethink. **Resolved 2026-05-02**: orchestration is a verb the Agent performs, not a separate entity. Speak of "orchestration" (the responsibility), not "the orchestrator" (the thing).
- "Agent reasons inline" was an early framing of how the delegation moment works. **Resolved 2026-05-02 (Q5)**: the Agent does NOT make case-by-case inline-vs-delegate decisions on substantive work. The cut is structural — interactive work (inception, grilling, design dialogue) stays inline because Workers can't efficiently ask the operator questions; everything else dispatches via Workflow lookup.
