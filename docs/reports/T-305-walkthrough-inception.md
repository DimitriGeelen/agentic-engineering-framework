# T-305: Scope In-Depth Framework Component Walkthrough — Research

**Date:** 2026-03-09
**Method:** Survey of existing documentation + format analysis

---

## What Already Exists

| Layer | Content | Count | Location |
|-------|---------|-------|----------|
| Layer 0 | README.md, FRAMEWORK.md, CLAUDE.md | 3 | Root |
| Layer 1 | Auto-generated component reference docs | 127 | docs/generated/components/ |
| Layer 2 | AI-generated subsystem articles (Ollama) | 13 | docs/generated/articles/ |
| Deep-dives | Hand-crafted concept articles | 20 | docs/articles/deep-dives/ |
| Reports | Inception research, analysis | 90 | docs/reports/ |
| Web UI | Watchtower with fabric explorer, docs route | Running | localhost:3000/docs, /fabric |

**Key insight:** The content is largely BUILT. What's missing is a **guided path** through it — sequencing, audience routing, and progressive disclosure.

## The 12 Subsystems

1. Watchtower (37 components) — Web dashboard
2. Context Fabric (13) — Persistent memory
3. Framework Core (10) — CLI, init, metrics
4. Git Traceability (7) — Task-referenced commits
5. Component Fabric (7) — Topology/dependency graph
6. Healing Loop (5) — Error diagnosis/mitigation
7. Learnings Pipeline (4) — Capture → storage → display
8. Context Budget Management (3) — Token tracking
9. Task Management (2) — Create/update, AC gates
10. Audit System (2) — Compliance checking
11. Handover System (1) — Session continuity
12. Hook Enforcement (1) — PreToolUse/PostToolUse

## Format Options

1. **Ordered markdown walkthrough** — Sequence existing docs into a learning path
2. **Watchtower web walkthrough** — Interactive guided tour in the web UI
3. **CLI guided tour** — `fw walkthrough` command stepping through subsystems
4. **Hybrid** — CLI scaffolding linking to web/markdown for depth

## Recommendation

**The walkthrough is a sequencing/routing problem, not a content creation problem.** 127 component docs + 13 subsystem articles + 20 deep-dives already exist. A walkthrough should:

1. Define 2-3 audience tracks (new user, contributor, agent implementer)
2. Order subsystems by dependency (Task Management → Git → Audit → Healing → Context → etc.)
3. Link to existing docs at each step — don't duplicate content
4. Optionally add a `fw walkthrough` CLI command or Watchtower route

**Proposed GO deliverable:** A `docs/walkthrough/` directory with ordered guides per audience track, linking to existing generated docs. Optionally a Watchtower `/walkthrough` route.
