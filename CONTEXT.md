# Agentic Engineering Framework

The framework's domain language. Captured during the orchestrator-as-triage architectural rethink (T-1687 / forthcoming arc). Add terms only when they have been explicitly resolved during a grilling session — do not pre-populate from speculation.

## Language

**Orchestrator**:
The routing layer that, when invoked at a delegation moment, composes a delegation envelope (model, prompt, context, tools) for a worker to execute. Structurally distinct from the parent agent session. Runs on a configured model — default `opus`, settable per project.
_Avoid_: Router (too narrow — orchestration is more than model picking), Supervisor (vague), Main agent (ambiguous with parent session).

## Relationships

- The **Orchestrator** runs on a configurable model; today's default is `opus`.
- The **Orchestrator** is invoked BY the parent agent (claude-code session); it is not the parent itself.

## Flagged ambiguities

- "Framework agent" was used informally to refer to both (a) the parent claude-code session running the framework's CLAUDE.md, and (b) the orchestrator triage layer. Resolved: when "agent" is used without qualifier, it means the parent session. The orchestrator is its own term.
