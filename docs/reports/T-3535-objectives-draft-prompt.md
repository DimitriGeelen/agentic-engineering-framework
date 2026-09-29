You are drafting the PROJECT OBJECTIVES for the Agentic Engineering Framework (AEF) repo at /opt/999-Agentic-Engineering-Framework. Read-only everywhere EXCEPT the one output file below. Do not commit, do not run fw task/inception/arc verbs.

## Why this exists
Arcs (feature/initiative containers, .context/arcs/*.yaml) now carry an `objective` and a `supports: []` field that should point at project objective IDs — but no project objectives exist. The layer's main job is to make work DECLINABLE: 20 arcs are in progress, 5 stale, 325 tasks await review, and nothing gives a basis for saying no. Background and design: docs/reports/T-3535-per-project-objectives.md and .tasks/active/T-3535-*.md (read both first). The human operator will see your draft ONCE, after an independent review, and correct it, so it must be faithful to sources, not inventive.

## Sources (read them; cite them)
- 001-Vision.md (the project's original goals doc; its "Current State"/stage statuses are stale since 2026-02-14; use its intent, not its status)
- 005-DesignDirectives.md and the "Four Constitutional Directives" in CLAUDE.md
- every .context/arcs/*.yaml: name, status, headline_mechanic, and where present purpose/objective (continuous-run, readme-first-run, orchestrator-rethink carry T-3563 story fields)
- recent operator rulings: .tasks/active/T-3557-*.md (human review for RISK only; independent agent reviewer for everything else), docs/reports/T-3558-circuit-address-everywhere.md (agents working together efficiently, effectively, securely across sessions/projects/hosts), docs/reports/T-3563-arc-story.md (arcs explain themselves; context fabric)
- policy/value-drivers.yaml (the value drivers; objectives must not merely restate D1-D4; they are outcome states the directives serve)

## Deliverable
Write /opt/999-Agentic-Engineering-Framework/docs/reports/T-3535-objectives-draft.md containing:

1. A YAML block (the proposed content of .context/project/objectives.yaml):

```yaml
headline: <one sentence, <=25 words: what this project is for and for whom>
objectives:
  - id: O-1
    text: <outcome state, <=30 words; a state of the world, NOT an activity>
    measure: <how progress is observed; prefer something computable from repo state (tasks, arcs, audits, jsonl ledgers); name the source; say "not yet measurable" honestly if so>
    sources: [<file paths / decision ids that justify it>]
out_of_scope:
  - <explicit non-goals, each with a source>
```

3 to 5 objectives. Fewer and sharp beats more and vague. Each must be able to make some current arc DECLINABLE, i.e. it must be possible for an arc to serve none of them.

2. An arc mapping table: every arc in .context/arcs/ -> the objective(s) it would serve (`supports:` proposal) or NONE, plus status and a one-line reason. Arcs mapping to NONE are the point; list them, do not stretch objectives to cover them.

3. A short "what I was unsure about" list: places where sources conflict, or where an objective is your inference rather than something a source states. Be explicit; the reviewer and operator need this.

Constraints: plain, concrete English; no marketing tone; no invented facts or numbers; every claim traceable to a cited file. When done, print only: the output path, the headline, the objective one-liners, and the count of arcs mapped to NONE.
