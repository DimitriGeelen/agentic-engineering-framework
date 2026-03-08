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

### Why agents need this

Human developers build mental models of their codebase. They know "if I change auth, I need to check the middleware." This knowledge is implicit, built over months of working with the code.

AI agents don't have implicit knowledge. Every session, they see the codebase fresh. Without a structural map, they can only see what they're directly looking at — not the ripple effects of their changes.

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
