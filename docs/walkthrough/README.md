# Framework Walkthrough

A guided tour of the Agentic Engineering Framework's 12 subsystems.

## Choose Your Track

| Track | Audience | Time | Focus |
|-------|----------|------|-------|
| [New User](01-new-user.md) | First-time adopter | ~30 min | Core governance cycle: tasks, commits, audits, handovers |
| [Contributor](02-contributor.md) | Framework contributor | ~45 min | How subsystems connect, where to add features, testing patterns |
| [Agent Implementer](03-agent-implementer.md) | Building a new agent integration | ~45 min | Hook system, gate enforcement, context budget, memory model |

## Subsystem Map (Dependency Order)

```
Task Management ──→ Git Traceability ──→ Audit System
       │                    │                  │
       ▼                    ▼                  ▼
 Hook Enforcement    Handover System    Healing Loop
       │                    │                  │
       ▼                    ▼                  ▼
Context Budget ────→ Context Fabric ──→ Learnings Pipeline
       │                    │
       ▼                    ▼
 Framework Core ──→ Component Fabric ──→ Watchtower
```

Each track visits subsystems in this dependency order — you understand the foundations before the layers built on top.

## Quick Reference

- **Generated component docs:** `docs/generated/components/` (127 files)
- **Subsystem deep-dives:** `docs/articles/deep-dives/` (20 articles)
- **AI-generated articles:** `docs/generated/articles/` (13 articles)
- **Web UI explorer:** http://localhost:3000/fabric (interactive topology)
- **Web UI docs:** http://localhost:3000/docs (generated documentation)
