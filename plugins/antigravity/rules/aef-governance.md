# Agentic Engineering Framework (AEF) Governance Rules

## Core Rules & Invariants
1. **P-002: Task-First Structural Enforcement**: No modification without an active task in `started-work`.
2. **Tier 0 Operations**: Destructive commands require explicit human approval via `fw tier0 approve`.
3. **Inceptions**: Architectural investigations end with human decision (`fw inception decide T-XXX go|no-go|defer`).
4. **Commit Discipline**: Every commit references a task ID (`git commit -m "T-XXX: ..."`).
5. **Component Fabric**: Architectural components are registered and tracked in `.fabric/`.
6. **Project Memory**: Capture learnings, decisions, and patterns into `.context/`.
