# Prompts

Reusable agent prompts — drafted once, retrieved by any session or fleet agent
via `fw prompt`. Storage is plain markdown + YAML frontmatter so the files are
diffable, reviewable, and git-trackable (T-1283 B1).

## Schema

```markdown
---
id: <slug>                        # filename stem; unique within this repo
name: "Human-readable name"
description: "One-line description"
kind: agent|system|user           # who the prompt is for
tags: [a, b]                      # free-form, comma-separated
variables: [name, host]           # auto-populated from {{...}} in body
created: 2026-04-18T09:00:00Z
updated: 2026-04-18T09:00:00Z
---

Prompt text goes here. It may contain `{{var}}` placeholders that
`fw prompt copy --var name=world` will substitute.
```

## CLI

```bash
fw prompt create --name "upgrade+test+fix" --kind agent \
    --body "Upgrade via .agentic-framework/bin/fw upgrade && fw test all on {{host}}"

fw prompt list
fw prompt show upgrade-test-fix
fw prompt copy upgrade-test-fix --var host=ring20-dashboard
```

## Design reference

`docs/reports/T-1283-prompt-register.md` — the inception artifact with all 6
design decisions (Q1–Q6).

Later build units add:

- B2 — cross-agent ID namespacing (`<agent-id>/P-NNN`)
- B3 — Watchtower list + detail + copy UI
- B4 — Watchtower composer form
- B5 — TermLink fleet sync (`fw prompt push/pull/sync`)
- B6 — Conflict-resolution policy + review surface
