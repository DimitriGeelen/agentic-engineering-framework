# Deep Dive #18: Blast Radius

## Title

Blast Radius — why every AI agent commit should know what it touches before it lands

## Post Body

**In enterprise programme management, the most expensive failures are not the ones that break one thing. They are the ones that break one thing which quietly breaks six others.**

A programme manager who modifies a shared interface — a data format, a handoff protocol, a service contract — without checking who depends on it will discover the damage days later, through complaints from teams downstream. The fix was a 10-minute change. The blast radius was three workstreams, two weeks of rework, and a missed milestone. The root cause was not incompetence. It was invisibility: the dependency chain existed, but nobody could see it before committing the change.

AI coding agents have this problem in a more concentrated form. A human developer builds tacit knowledge over months: "if I change the auth module, I need to check the middleware." An AI agent has no tacit knowledge. Every session, the codebase is fresh. It sees the file it is editing. It does not see the six files that import from it, the three templates that render its output, or the two hooks that trigger on its changes.

The Agentic Engineering Framework tracks every significant component, the subsystem it belongs to, and the dependency edges between them. Without visibility into that graph, an agent editing one node is flying blind about all the others.

### What blast radius analysis does

Before a commit lands, blast radius analysis answers one question: **what does this change touch beyond the files you edited?**

```bash
$ fw fabric blast-radius HEAD

Blast radius: HEAD
  T-503: TermLink Phase 0 complete — fw route, help entry, CLAUDE.md section

bin/fw (fw)
    writes → agents/termlink/termlink.sh
    writes → agents/context/context.sh
    writes → agents/handover/handover.sh

Registered component(s) changed: bin/fw
```

The commit modified `bin/fw`. The Component Fabric knows that `bin/fw` calls dozens of other scripts and is in turn called or sourced by dozens of components. That single file change has a wide potential blast radius. The output makes this visible before anyone discovers it through a failure.

### How it works

The Component Fabric maintains a YAML card for every significant file in the project:

```yaml
# .fabric/components/fw.yaml
id: fw
name: fw
type: script
subsystem: framework-core
location: bin/fw
purpose: "Main CLI entry point — routes to all agents and subsystems"
depends_on:
  - target: create-task
    type: calls
  - target: update-task
    type: calls
  - target: context-dispatcher
    type: calls
  # ...
depended_by:
  - source: plugin-audit
    type: called_by
  - source: fabric
    type: called_by
  # ...
```

When `fw fabric blast-radius HEAD` runs, it extracts changed files from the commit via `git diff-tree`, looks up each file's component card, and reports its dependency edges. The algorithm is deliberately shallow — direct dependencies only. Full transitive impact (what depends on the things that depend on your change) is available via `fw fabric impact <path>`, but the blast radius command optimises for speed and clarity at commit time.

Files without a component card show as unregistered — a signal that the fabric has drifted and needs updating:

```bash
  CLAUDE.md (no fabric card)
```

This is not a failure. It is a nudge. Drift detection (`fw fabric drift`) catches unregistered files, orphaned cards, and stale dependency information systematically.

### Where it runs

Three enforcement points, from softest to hardest:

**Post-commit hook.** Every commit triggers a blast radius summary automatically. The agent sees the output immediately after committing. If a changed component has high connectivity, the hook flags it with a warning. This catches the common case: an agent edits a utility function without realising it is called by multiple subsystems.

**CLAUDE.md procedural rule.** Before setting any task to `work-completed`, the agent must run blast radius analysis if source files changed. This is a governance instruction — the agent's operating manual says to do it. It is soft enforcement: the agent can forget, but the rule is explicit.

**Verification gate.** Tasks can include `fw fabric blast-radius HEAD` in their `## Verification` section. The completion gate runs these commands mechanically. If blast radius shows unexpected impact, the task author can make it a blocking check. This is hard enforcement: the task cannot complete until impact is reviewed.

### The value of visibility over prevention

Blast radius analysis does not block commits. It does not reject changes. It does not force the agent to update all downstream files before proceeding. This is a deliberate design decision.

Prevention — blocking a commit because it affects too many files — would be brittle and counterproductive. Some high-impact commits are necessary. A deliberate refactoring that touches many components is fine. A one-line fix that accidentally touches just as many is a problem. The blast radius tool cannot distinguish between these two cases. A human or an informed agent can.

**The value is in making hidden impact visible at the moment it matters: before the change propagates.** A programme manager who sees "this interface change affects three workstreams" can plan accordingly. An agent who sees the downstream impact of its edit can proactively check each affected file. Without visibility, neither the programme manager nor the agent knows there is a problem until downstream failures arrive.

This aligns with the framework's second directive: **reliability means predictable, observable, auditable execution.** Blast radius analysis makes the impact of every change observable. The decision to act on that observation remains with the human or the agent.

### What it has caught

The Component Fabric was born from a real incident. During an early task, multiple files were modified in a single session without traceability — a silent corruption chain where changes cascaded through dependencies that nobody tracked. The damage was discovered after the fact, through symptoms, not through visibility. The inception that designed the Component Fabric cited this incident as the primary motivation.

Since integration into the post-commit hook, every commit shows its structural impact. The high-connectivity warning has flagged the main CLI entry point, the context dispatcher, and the web application — the files where a careless edit has the widest downstream consequences. These are precisely the files where an agent, working without a structural map, would cause the most damage.

The framework now runs `fw fabric blast-radius` after every commit. When a recent integration modified the main CLI entry point — the most connected file in the project — the post-commit output flagged it automatically: *"High connectivity — consider: fw fabric blast-radius HEAD."* The agent saw this warning mechanically, without needing to remember that the file is important. Structural awareness replaced tacit knowledge.

### Why agents need this more than humans

A senior developer who has worked on a codebase for two years carries a mental model of its structure. They know, without looking, that the config module is imported everywhere, that the middleware chain is fragile, that the database layer has been refactored three times and has scar tissue. This knowledge is tacit, accumulated, never written down.

An AI agent starts every session from zero. It reads the files it needs, executes the task it is given, and produces output. If the task says "modify the authentication module," it modifies the authentication module. It does not check what depends on the authentication module because it does not know what depends on the authentication module. This is not a limitation of the agent's capability. It is a limitation of the information available to it.

Blast radius analysis converts tacit structural knowledge into explicit, queryable data. The agent does not need two years of experience with the codebase. It runs one command and sees the full dependency chain. The information asymmetry between a senior developer and a fresh agent session shrinks from months to milliseconds.

### The broader principle

Impact analysis is not an AI-specific technique. It predates software engineering entirely. Civil engineers calculate the blast radius of demolition charges. Epidemiologists model the blast radius of an outbreak from a single case. Programme managers assess the blast radius of a schedule delay on dependent workstreams. In each domain, the principle is identical: **before changing something, understand what it touches.**

The Agentic Engineering Framework applies this principle to AI agent commits using a structural topology map (the Component Fabric), shallow dependency traversal (blast radius), and three escalating enforcement points (post-commit hook, procedural rule, verification gate). The implementation is a short bash script and a set of YAML cards. The principle is as old as engineering itself.

**A commit without blast radius analysis is a change without impact awareness. The domain changed from civil engineering to AI agent governance. The principle did not.**

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
cd my-project && fw init --provider claude

# Register key files
fw fabric register src/auth.ts
fw fabric register src/api/routes.ts

# Check impact before committing
fw fabric blast-radius HEAD

# See full dependency chain
fw fabric deps src/auth.ts

# Detect structural drift
fw fabric drift

# Explore the interactive graph
fw serve  # http://localhost:3000/fabric
```

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

---

## Platform Notes

**LinkedIn:** Open with "In programme management, the most expensive failures are not the ones that break one thing. They are the ones that break one thing which quietly breaks six others." The cross-domain bridge (civil engineering, epidemiology, programme management) resonates with the governance audience. Keep to 400 words — cut the "How it works" section and the code blocks.
**Reddit (r/ClaudeAI):** Lead with the incident: "An agent refactored auth.ts without knowing 6 other files imported from it. The project stopped building. The agent did nothing wrong — it just couldn't see the blast radius." Include the terminal output screenshot.
**Dev.to / Hashnode:** Full article. Can expand with the Component Fabric YAML schema, the traverse.sh implementation, and the Watchtower dependency graph visualisation.

## Hashtags

#AgenticEngineering #ClaudeCode #BlastRadius #ImpactAnalysis #ComponentFabric #BuildInPublic #OpenSource
