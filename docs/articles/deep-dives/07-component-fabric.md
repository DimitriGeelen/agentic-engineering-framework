# Deep Dive #7: Component Fabric

## Title

Governing AI Agents: The Component Fabric — structural awareness for AI agents

## Post Body

**You cannot govern what you cannot see.**

In enterprise architecture, one of the earliest governance activities is building a structural map — what components exist, how they connect, what depends on what. A programme manager who does not know the dependency chain between workstreams cannot assess the impact of a delay. A hospital administrator who does not know which departments share a sterilisation unit cannot plan maintenance. The map is not documentation for its own sake. It is the basis for impact analysis: before changing something, understand what it touches.

AI coding agents operate without this map. An agent asked to refactor the authentication module will produce clean code, good abstractions, well-tested output. It will also change function signatures without knowing that six other modules import from the file it modified. The project will not build. The agent did nothing wrong. It simply did not know what it could not see.

The Agentic Engineering Framework had excellent temporal memory — it knew what happened (tasks, decisions, episodic histories). But it had almost zero spatial memory. It did not know what exists, where things are, or how they connect. I recognised this gap during a conversation about research persistence (session S-2026-0219): **as the codebase grows, reading all documents will not work anymore. The system needs a structural map.**

### The Component Fabric

The Component Fabric (`.fabric/`) is a topology map of every significant file in the project. Every file gets a component card:

```yaml
# .fabric/components/lib-auth.yaml
id: lib-auth
name: Authentication Module
type: library
subsystem: auth
location: lib/auth.ts
purpose: "Core authentication logic — token validation, session management"
interfaces:
  - validateToken(token: string): boolean
  - createSession(userId: string): Session
depends_on: [lib-crypto, lib-config]
depended_by: [api-auth-check, api-login, api-register, api-oauth, worker-token-refresh]
```

Before changing a file, the agent checks what depends on it:

```bash
$ fw fabric deps lib/auth.ts

lib/auth.ts
  Depends on:    lib/crypto.ts, lib/config.ts
  Depended by:   6 files (auth-check, login, register, oauth, token-refresh, auth.test)
```

Six dependents. The agent now knows: changing a function signature in `auth.ts` requires updating six files.

### Blast radius

The fabric enables blast radius analysis — run it before committing to see what changes affect downstream:

```bash
$ fw fabric blast-radius HEAD

Changes in this commit:
  Modified: lib/auth.ts

Direct dependents: 6
Transitive impact: 3 more (via auth-check.ts middleware)
Total blast radius: 9 files
```

Before the commit reaches production, the full impact is visible. The agent can proactively check and update each affected file.

### Drift detection

Code evolves. New files appear. Old files are deleted. Dependencies change. The fabric detects when its map drifts from reality:

```bash
$ fw fabric drift

Unregistered:  lib/auth-v2.ts (created 2 days ago, no card)
Orphaned:      lib-old-auth.yaml points to deleted file
Stale:         lib/auth.ts — new import of lib/rate-limiter.ts not in card
```

The structural map stays accurate over time. This is not optional maintenance — drift detection runs automatically and flags discrepancies.

### The research behind the design

The Component Fabric was born from a formal inception (T-191) that ran across multiple sessions and produced 8 research documents: genesis discussion, research landscape (14 sources across 7 domains), topology prototype, UI patterns research, requirements analysis, data model, enforcement design, and architecture proposal.

Five design principles emerged:

1. **Structural self-awareness** — the system knows what it is, not just what happened
2. **Earn your detail** — granularity is adaptive (coarse by default, detailed where complexity warrants)
3. **UI as first-class** — UI elements documented as explicitly as backend (agents cannot see screens)
4. **Enforced, not optional** — component registration is a gate, not a suggestion
5. **"The thinking trail IS the artifact"** — every step of the research process is persisted

That last principle is meta — it was learned during the Component Fabric inception itself and then applied to all future research tasks. If you lose the final deliverable, the thinking trail can reconstruct it. If you lose the thinking trail, the final deliverable is an unjustified assertion.

A later integration spike (T-222) validated three aspects: CLAUDE.md awareness (zero existing mentions of fabric), task-component linking (72% automatic file resolution, 0% false positives), and drift detection. The fabric does not need to be perfect. 72% automatic resolution with zero false positives is already a substantial improvement over the alternative — hoping the agent reads the right files.

### Why agents need spatial memory

Human developers build mental models of their codebase over months. They know implicitly: "if I change auth, I need to check the middleware." This knowledge is tacit, accumulated through experience, never written down.

AI agents do not have tacit knowledge. Every session, they see the codebase fresh. Without a structural map, they can only see what they are directly looking at — not the ripple effects of their changes. The Component Fabric makes structural knowledge explicit and queryable. The agent does not need months of experience. It checks the blast radius before every change.

**Temporal memory without spatial memory is half a governance model. The domain changed from enterprise architecture to AI agent awareness. The principle did not.**

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
cd your-project && fw init

# Register key files
fw fabric register lib/auth.ts
fw fabric register api/routes/login.ts

# Check dependencies before making changes
fw fabric deps lib/auth.ts
fw fabric blast-radius HEAD
```

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

---

## Platform Notes

**Dev.to / Hashnode:** Use as-is. Can expand with the full component card schema and the interactive Watchtower graph visualisation.
**LinkedIn:** Open with "In enterprise systems, no one changes a shared interface without impact analysis. AI agents need the same discipline."
**Reddit (r/ClaudeAI):** Shorten. Lead with the "refactored one file, broke six" scenario.

## Hashtags

#ClaudeCode #AIAgents #DevTools #Architecture #OpenSource #ImpactAnalysis
