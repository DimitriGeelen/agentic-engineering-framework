# Agent role: task lifecycle + interactive work + dispatch-everything-else

The Agent's job is sliced into three parts: (1) **task lifecycle** — create, ensure-updates, close-with-guards — done authoritatively; (2) **interactive work** — inception, grilling, design dialogue, anything where mid-stream operator interjection is essential — done inline because Workers cannot efficiently solicit operator input; (3) **dispatch** — all other substantive work, routed to Workers via `workflows.yaml` lookup. The Agent does not make case-by-case inline-vs-delegate decisions on substantive work; the cut is structural (interaction-shape), not reasoning-driven.

This narrows the Agent to a task manager + interactive collaborator + envelope router, with substantive non-interactive work pushed to Workers where it can use cheaper / specialized models and isolated context. `workflows.yaml` is the human-curated routing table; the Agent consults it but does not invent envelopes from scratch.

## Considered Options

- **Pure-reasoning Agent (Q5 #3)** — Agent reasons per task whether to inline or dispatch. Rejected: hides the delegation moment in opaque per-step judgment, drift between operator expectations and Agent decisions becomes invisible.
- **Pure-table Agent (Q5 #2)** — every dispatch decision must be in `workflows.yaml`; nothing inline beyond table lookup. Rejected: forces interactive work (inception, grilling) into a table that can't model "operator may interject any moment", and starts empty so the Agent has nothing to do until the table is populated.
- **Pure-explicit (Q5 #1)** — Agent never delegates without an explicit `--dispatch` flag. Rejected: never closes G-064 (no autonomous workload), conflicts with the user's stated vision of "framework agent does triage".

## Consequences

- `workflows.yaml` schema must mark some task_types as `inline: true` (inception, grilling) so the Agent never tries to dispatch them.
- A worker that needs operator input has no path to ask — must either fail fast with a structured `needs_operator_input` outcome or be redesigned as inline.
- The Agent's CLAUDE.md fragments under `context_pack` for dispatched work can be much smaller than the full project CLAUDE.md, since Workers don't need task-management or interactive-collaboration sections.
