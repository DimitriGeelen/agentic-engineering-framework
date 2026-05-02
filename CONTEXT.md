# Agentic Engineering Framework

The framework's domain language. Captured during the orchestrator-as-triage architectural rethink (T-1687 / forthcoming arc). Add terms only when they have been explicitly resolved during a grilling session — do not pre-populate from speculation.

## Language

**Agent**:
The parent Claude Code session running the project's CLAUDE.md. The single source of reasoning in the framework. Performs orchestration (triage + envelope composition + dispatch) as part of its job — not a separate entity.
_Avoid_: Main agent, parent agent, framework agent (all redundant — there is only one Agent in a session).

**Orchestration**:
The Agent's responsibility to (a) triage incoming work, (b) decide between doing it inline vs delegating, (c) when delegating, compose a delegation envelope. A verb, not a noun-entity.
_Avoid_: Routing (too narrow — orchestration includes the inline-vs-delegate decision), Dispatch (only the last step of orchestration).

**Worker**:
A dispatched executor that runs a delegation envelope. Three flavours today: Task tool sub-agent (in-session, shares context), TermLink dispatched session (separate process, isolated context), or a non-Claude provider (local llama / OpenRouter — not yet wired). Always strictly downstream of the Agent.
_Avoid_: Sub-agent (ambiguous — Claude Code's "sub-agent" concept conflates Task tool and TermLink), Specialist (overloaded with TermLink's specialist registry).

**Delegation envelope**:
The structured input to a Worker. Composed by the Agent at triage time. Fields: `worker_kind` (Task | TermLink | provider), `model`, `prompt`, `context_pack` (tailored CLAUDE.md fragment, MCP subset, tool allowlist, command allowlist), `cwd`. The unit of dispatch.
_Avoid_: Job, Request, Task (collides with the framework's Task concept, T-XXX).

## Relationships

- The **Agent** runs on a model configured per-project (default `opus`). The configured model is *the* orchestration model — there is no separate orchestration tier.
- The **Agent** issues **Delegation envelopes** to **Workers**.
- A **Delegation envelope** is the only artefact a **Worker** sees from the **Agent**.
- The **Agent** observes Worker outcomes and updates its routing memory (today: `route_cache.json`).

## Example dialogue

> **User:** "Run the orchestrator audit refactor."
> **Agent (mentally):** Triage — this is a substantive build. Delegate? Yes — different model class needed for the implementation than for triage. Compose envelope: TermLink worker, model=sonnet, prompt=<crafted>, context_pack={CLAUDE.md fragment scoped to build-task, MCPs limited to read+edit+test, tools={Read, Edit, Bash, Grep}, cwd=this repo}. Dispatch.
> **Worker:** runs the build, writes results, exits.
> **Agent:** observes outcome, updates route_cache, reports to user.

## Flagged ambiguities

- "Framework agent" was used informally to refer to (a) the parent Claude Code session, (b) a hypothetical separate orchestrator entity. **Resolved 2026-05-02**: there is no separate orchestrator. The Agent (singular) does orchestration as one of its responsibilities. "Framework agent" should be retired in favour of "Agent."
- "Orchestrator" was used as a noun-entity in early drafts of the rethink. **Resolved 2026-05-02**: orchestration is a verb the Agent performs, not a separate entity. Speak of "orchestration" (the responsibility), not "the orchestrator" (the thing).
