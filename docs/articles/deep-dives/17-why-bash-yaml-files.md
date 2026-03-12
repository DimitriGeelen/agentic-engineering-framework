# Deep Dive #17: Why Bash, YAML and Files

## Title

Why Bash, YAML and Plain Files — the deliberately anti-enterprise stack behind the Agentic Engineering Framework

## Post Body

**Every technical person who sees the repo asks the same question: why bash scripts and YAML files? Why not a proper language, a database, a real framework?**

It is a fair question. The stack looks primitive. Shell scripts orchestrating YAML files, cron jobs polling every 15 minutes, a Flask app with 14KB of vendored JavaScript. No ORM, no build step, no npm install. My brother Marc asked me this week, and I realised the answer is worth writing down because it is not "we could not be bothered" — it is a deliberate architectural position traced through 50+ recorded decisions.

### The four directives

Every technology choice in the framework traces back to four constitutional directives we set on day one, in priority order:

1. **Antifragility** — the system must strengthen under stress, not collapse
2. **Reliability** — predictable, observable, auditable; no silent failures
3. **Usability** — joy to use, extend, and debug
4. **Portability** — zero provider, language, or environment lock-in

Portability is the fourth directive, but it drove the most consequential technology decisions. Every time we evaluated a "proper" alternative, it failed on portability. Every time.

### Why not a database

This is the one people find hardest to accept. The framework manages tasks, decisions, learnings, patterns, gaps, component cards, audit history — hundreds of structured records. Surely that needs a database.

It does not. We evaluated SQLite and Redis early (Decision D-013, task T-045) and rejected both for the same reason: **adding a database creates two sources of truth.** The framework already stores everything in YAML and Markdown files tracked by git. A database would duplicate that data and introduce sync problems.

Consider what files give you that a database does not:

- **Version control is free.** Every change to every record is in git history. You can `git blame` a decision made three months ago and see exactly who changed it, when, and why. Try that with a SQLite table.
- **Offline by default.** No connection string, no service to start. The framework works on an airplane.
- **Human-readable without tools.** When something breaks — and things break — you can open any file in a text editor and understand the state. No query language required. No client tool.
- **Grep is your query engine.** Finding every decision that references portability is `grep -r "portability" .context/project/decisions.yaml`. Finding every task with status issues is `grep "status: issues" .tasks/active/*.md`. The filesystem is the database and UNIX tools are the query language.

The web UI (Watchtower) reads directly from these files. No ORM, no migrations, no connection pooling. Flask opens a YAML file, parses it, renders a template. If Watchtower goes down, the governance system keeps working. The web layer is a convenience, not a dependency.

### Why bash instead of a proper language

The framework is a governance layer. It enforces rules on how AI agents work — blocking edits without a task, gating destructive commands, enforcing commit traceability. This is not application logic. It is orchestration.

Bash is the right tool for orchestration because:

**It runs everywhere.** Linux, macOS, BSD, Windows WSL, Docker containers, CI/CD pipelines, Proxmox VMs. No runtime to install. No version conflicts. No package manager.

**It fails loudly.** A bash script either exits 0 or it does not. There is no silent exception swallowing, no null reference hiding in a stack trace. When the task gate blocks an edit, it writes to stderr and exits 2. The agent sees the block immediately. This matters enormously for reliability — the second directive.

**It is auditable.** Every hook, every gate, every agent script is a text file you can read in 30 seconds. When we investigate a governance bypass (and we have had them), the entire enforcement chain is visible. No compiled binaries, no framework magic, no dependency injection.

We codified this as Practice P-006 on the first day: **hybrid agent architecture.** Every agent is two layers. A bash script handles the mechanical, deterministic work. A Markdown file (AGENT.md) carries the intelligence and judgment guidance. The bash layer is portable and reliable. The Markdown layer is adaptable and readable by any LLM.

The design principle is "automate downward" (AD-004): stable logic sinks to scripts, as far from LLM inference as possible. The agent handles judgment — should we run this? Bash handles execution — how do we run this? The most critical code is the most auditable.

### Where Python enters (and where it stops)

Python appears in exactly four places:

1. **YAML parsing** — `yaml.safe_load()` is robust; bash YAML parsing is not
2. **The web UI** — Flask, because it is the thinnest web framework that exists
3. **Token counting** — parsing Claude Code's JSONL transcripts for budget management
4. **Data analysis** — tool call statistics, error pattern classification

Each of these is a place where bash genuinely cannot do the job well. We did not reach for Python because it is comfortable — we reached for it because bash hit a real wall. The boundary is deliberate.

### Why Flask and 14KB of JavaScript

Decision D-012, also from task T-045: *"Portability directive — no provider lock-in, no npm ecosystem. Single 14KB JS file, vendored dependencies, works fully offline."*

We evaluated React and Next.js. Both require Node.js, npm, a build step, and hundreds of transitive dependencies. For a governance dashboard that renders tables and status badges, that is absurd overhead. Flask serves HTML. htmx handles interactivity with 14KB of vendored JavaScript. Pico CSS handles styling. No bundler, no transpiler, no node_modules.

If the npm registry goes down, the framework does not notice. If Node.js releases a breaking change, the framework does not care. That is what portability means in practice.

### Why cron instead of event-driven architecture

The framework runs compliance audits every 15 minutes. A webhook-based system would react instantly to changes. We chose polling anyway (Decision D-040).

Webhooks require infrastructure: a reachable endpoint, delivery guarantees, retry logic, dead letter queues, possibly a message broker. Polling requires one line in crontab. If an audit fails, it runs again next cycle. The complexity difference is orders of magnitude, and for a governance check that runs every 15 minutes, instant reaction is not worth the infrastructure.

### The real argument: what breaks at 3am

The honest engineering question is not "what is the most modern stack" — it is "what happens when something goes wrong and nobody is watching."

With files and bash scripts: you open the YAML file, you read it, you understand the state. You `grep` the logs. You `git log` the history. You fix it with a text editor.

With a database, an ORM, a React frontend, and an event bus: you check the database connection, you check the migration state, you check the webpack build, you check the message queue, you check the container orchestration. Each layer is another thing that can fail and another thing that requires specialised knowledge to debug.

The framework governs AI agents. It must be more reliable than the thing it governs. A governance system that needs its own ops team is not governance — it is another source of risk.

### The tradeoffs we accept

This stack has real costs:

- **No query optimisation.** Grep is fast, but if we ever have 10,000 tasks, file-based search will be slow. We do not have 10,000 tasks. We have 470. If we get there, it will be a good problem to have.
- **No concurrent writes.** Two agents editing the same YAML file will produce a conflict. Git handles this with merge — but it requires attention. A database handles it with transactions.
- **Limited UI interactivity.** htmx is powerful but it is not React. Complex client-side state management is harder. The dashboard does not need complex state management.
- **Bash is not beautiful.** Shell scripts are harder to read than Python or C#. We accept this for portability and reliability.

These are conscious tradeoffs, not oversights. Each one was evaluated against the four directives and accepted because the alternative (a database, a build system, a JavaScript framework) would compromise portability or reliability for a problem we do not actually have.

### Why this matters beyond our framework

The broader principle is this: **governance infrastructure should be the simplest technology that works, not the most sophisticated technology available.** When you build a system whose job is to enforce rules and maintain auditability, every layer of abstraction is a place where enforcement can silently fail. Plain text files in git cannot silently lose data. Bash scripts cannot silently swallow exceptions. Cron jobs cannot silently stop running without crontab showing you why.

Simplicity is not a limitation. For governance, it is a feature.

---

**Decisions referenced:**
- D-002: YAML for audit history
- D-005: Coherent git agent over scattered scripts
- D-012: Flask + htmx, no build step
- D-013: Files as source of truth, no database
- D-040: Polling over webhooks
- AD-004: Automate downward composition
- AD-008: Markdown + YAML frontmatter dual format
- P-006: Hybrid agent architecture

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

---

## Platform Notes

**LinkedIn:** Strong piece for technical audience. The "what breaks at 3am" framing resonates with anyone who has been on-call. Lead with the brother question — personal hook into technical content.
**Reddit (r/ClaudeAI, r/programming):** The anti-enterprise angle will generate discussion. Expect pushback on "no database" — have the D-013 rationale ready.
**Dev.to / Hashnode:** Can expand with code snippets showing the actual hook enforcement (bash) vs what it would look like in C# for comparison.

## Hashtags

#AgenticEngineering #ClaudeCode #BuildInPublic #Bash #YAML #NoDatabase #Portability #OpenSource
