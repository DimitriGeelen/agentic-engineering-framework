# Deep Dive #7: Component Fabric

## Title

My AI agent "fixed" one file and broke 6 others. Here's how I gave it structural awareness.

## Post Body

I asked the agent to refactor the authentication module. Simple enough — extract some shared logic, clean up the interfaces.

It did a great job on the auth module. Clean code, good abstractions, well-tested.

Problem: 6 other modules imported from the auth module. The agent changed the function signatures without knowing those dependents existed. The project wouldn't build.

The agent didn't do anything wrong. It just didn't know about the downstream impact. It had no structural map of how files depend on each other.

### Impact analysis before editing

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) includes a Component Fabric — a structural topology map of every significant file in the project:

```bash
# Before changing auth.ts, check what depends on it
$ fw fabric deps lib/auth.ts

lib/auth.ts
  Depends on:
    lib/crypto.ts (encryption utilities)
    lib/config.ts (auth configuration)

  Depended by:
    api/middleware/auth-check.ts
    api/routes/login.ts
    api/routes/register.ts
    api/routes/oauth.ts
    workers/token-refresh.ts
    tests/auth.test.ts
```

Six dependents. Now you know: if you change a function signature in `auth.ts`, these six files need to be updated too.

### Blast radius

The fabric's killer feature is blast radius analysis — run it before committing to see what your changes affect downstream:

```bash
$ fw fabric blast-radius HEAD

Changes in this commit:
  Modified: lib/auth.ts

Direct dependents (6):
  api/middleware/auth-check.ts
  api/routes/login.ts
  api/routes/register.ts
  api/routes/oauth.ts
  workers/token-refresh.ts
  tests/auth.test.ts

Transitive impact (3 more):
  api/routes/profile.ts (via auth-check.ts)
  api/routes/settings.ts (via auth-check.ts)
  api/app.ts (via middleware)

Total blast radius: 9 files
```

Before this commit reaches production, you know exactly which 9 files might be affected. The agent can proactively check (and update) each one.

### How the fabric works

Every significant file gets a component card:

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
  - refreshToken(session: Session): string
depends_on: [lib-crypto, lib-config]
depended_by: [api-auth-check, api-login, api-register, api-oauth, worker-token-refresh]
```

The fabric is queryable:

```bash
# Search by keyword
fw fabric search "authentication"

# Full transitive dependency chain
fw fabric impact lib/auth.ts

# Detect unregistered or stale components
fw fabric drift
```

### Drift detection

Code evolves. New files get added. Old files get deleted. Dependencies change. The fabric detects when its map drifts from reality:

```bash
$ fw fabric drift

Unregistered (new files without component cards):
  lib/auth-v2.ts — created 2 days ago, no card

Orphaned (cards pointing to missing files):
  .fabric/components/lib-old-auth.yaml → lib/old-auth.ts (deleted)

Stale (dependency changes detected):
  lib/auth.ts — new import of lib/rate-limiter.ts not in card
```

This keeps the structural map accurate over time, even as the codebase evolves.

### The thinking behind this

The Component Fabric was born from a conversation during session S-2026-0219. I was discussing sub-agent research persistence (T-190) when I realized the deeper problem:

> "As our codebase grows, we get functions, routines, sequences of steps and dependencies that make up the application functionality. It becomes more and more difficult to debug and enhance the application. Going forward as the app gets more complex, reading all documents will not work anymore."

The framework had excellent **temporal memory** — it knew what happened (tasks, decisions, episodic histories). But it had almost zero **spatial memory** — it didn't know what exists, where things are, or how they connect.

This became a formal inception (T-191) that ran across 5-10 sessions and produced **8 research documents**:

1. **Genesis discussion** — problem framing and 6 use cases
2. **Research landscape** — 14 sources across 7 domains (architecture mining, dependency analysis, UI documentation)
3. **AEF topology sample** — prototype structural map of the actual framework
4. **UI patterns research** — how to make UI elements identifiable without visual inspection
5. **Requirements** — 6 validated use cases, all scored HIGH priority
6. **Data model** — component card schema with 10 prototype cards
7. **Enforcement design** — proactive gates + retroactive drift detection
8. **Architecture proposal** — build decomposition into 11 tasks

Five key design principles emerged from the research:

1. **Structural self-awareness** — the system knows what it is, not just what happened
2. **Earn your detail** — granularity is adaptive (starts coarse, deepens where complexity warrants)
3. **UI as first-class** — UI elements documented as explicitly as backend (agents can't see screens)
4. **Enforced, not optional** — component registration is a gate, not a suggestion
5. **"The thinking trail IS the artifact"** — every step of the intellectual process is persisted

That last principle is meta — it was learned during the Component Fabric inception itself and then applied to all future research tasks. If you lose the final deliverable, the thinking trail can reconstruct it. If you lose the thinking trail, the final deliverable is an unjustified assertion.

### Why agents need this

Human developers build mental models of their codebase. They know "if I change auth, I need to check the middleware." This knowledge is implicit, built over months of working with the code.

AI agents don't have implicit knowledge. Every session, they see the codebase fresh. Without a structural map, they can only see what they're directly looking at — not the ripple effects of their changes.

We validated this during a later integration spike (T-222) that tested three gaps: CLAUDE.md awareness (zero mentions of fabric), task-component linking (72% file resolution, 0% false positives), and drift detection. The fabric doesn't need to be perfect — 72% automatic resolution with zero false positives is already a massive improvement over "hope the agent reads the right files."

The Component Fabric makes structural knowledge explicit and queryable. The agent doesn't need months of experience with your codebase. It can check the blast radius before every change.

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/install.sh | bash
cd your-project && fw init

# Register your key files
fw fabric register lib/auth.ts
fw fabric register api/routes/login.ts

# Check dependencies before making changes
fw fabric deps lib/auth.ts
fw fabric blast-radius HEAD
```

GitHub: https://github.com/DimitriGeelen/agentic-engineering-framework

---

## Platform Notes

**Reddit (r/ClaudeAI, r/ChatGPTCoding):** The "refactored one file, broke six" scenario is extremely common. Developers will relate instantly.
**LinkedIn:** Frame as architecture — "In enterprise systems, we'd never change a shared interface without impact analysis. AI agents need the same discipline."
**Dev.to:** Expand with the full component card schema, how to auto-generate cards from imports, and the interactive Watchtower graph visualization.

## Hashtags

#ClaudeCode #AIAgents #DevTools #Architecture #OpenSource #ImpactAnalysis
