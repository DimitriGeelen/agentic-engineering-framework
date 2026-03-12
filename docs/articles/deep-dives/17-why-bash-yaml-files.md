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

### The hard questions

My brother Marc read the above and came back with five pointed questions. They are the questions any experienced engineer would ask, and they deserve honest answers rather than defensive ones. For each, I will steelman the objection (make the strongest possible case against our choice) and then give the actual reasoning.

---

**1. "Windows does not support bash. Not out of the box."**

**Steelman (strongest case against us):** You claim portability as a constitutional directive, but the world's most popular desktop operating system cannot run your framework natively. That is not portable — that is UNIX-portable. Actual portability means PowerShell, cmd.exe, or at minimum a language that compiles to native Windows binaries. Every developer on a corporate Windows machine without WSL approval is excluded. You have confused "runs on the systems I use" with "runs everywhere."

**Strawman (weakest version of this objection):** Just install WSL, it takes 5 minutes.

**Our honest position:** Marc is right that this is a real limitation, and we should not pretend otherwise. The framework targets developer machines running AI coding agents — Claude Code, Cursor, Aider. These tools overwhelmingly run on macOS and Linux, or Windows via WSL2. We chose POSIX portability (any UNIX-like system) over Windows-native portability because our actual user base is developers with terminals. WSL2 on Windows is functional and most AI coding agent users already have it. But if the goal were to serve enterprise Windows shops without WSL, bash would be the wrong choice.

**What we would do differently:** If Windows-native were a hard requirement, we would write the enforcement layer in Python (not bash) and accept the runtime dependency. The governance rules would be identical — only the implementation language changes. This is architecturally possible because bash is the mechanical layer, not the intelligence layer.

---

**2. "Python only runs predictably in a venv."**

**Steelman:** Python dependency management is a notorious disaster. System Python, user Python, Homebrew Python, pyenv Python, conda Python — each with different site-packages, different versions, different PATH resolution. Your framework uses Flask, PyYAML, ruamel.yaml, markdown2, bleach. Installing these with pip on a system Python can break OS tools (looking at you, Ubuntu). Without a venv, "pip install flask" is a dice roll. You chose a language with a well-known dependency problem for your web layer.

**Strawman:** Just pip install it, it works fine.

**Our honest position:** Partially right, partially overstated. The framework's Python dependencies are minimal (5 packages) and stable — no bleeding-edge APIs, no version-sensitive behavior. For the web UI specifically, these install cleanly on any Python 3.8+ system. But Marc's broader point stands: we should provide a venv setup. We do not currently, and that is a gap.

The critical nuance: **bash has zero dependency management issues.** The enforcement layer (hooks, gates, agents) is pure bash with coreutils. It requires nothing to be installed. The Python dependency only matters for the web UI (Watchtower), which is optional — governance works without it. This is deliberate: the thing that must never break (enforcement) has no dependencies; the thing that is nice to have (dashboard) requires pip install.

If the Python dependency were load-bearing for enforcement, Marc would be completely right and we would need to fix it. Because it is limited to the convenience layer, we can live with "pip install flask pyyaml" as a documented prerequisite while acknowledging the venv gap.

---

**3. "If the system already depends on Python, why use the less powerful bash?"**

**Steelman:** This is the strongest objection. You have Python in the stack. Python can do everything bash does — file manipulation, process management, JSON/YAML parsing, git commands via subprocess — and it does all of it with better error handling, proper data structures, testable functions, and IDE support. Bash gives you string manipulation and exit codes. Python gives you objects, exceptions, type hints, and a debugger. You are maintaining two languages where one would suffice. Every bash script could be a Python script with better error handling and actual unit tests.

**Strawman:** But bash is faster to write for simple things.

**Our honest position:** This is the question that keeps me honest. The technical case for all-Python is strong. Here is why I still use bash for the enforcement layer:

**Failure mode matters more than power.** A bash script that fails does exactly one thing: it exits with a non-zero code and prints to stderr. There is no exception hierarchy, no silent catch, no middleware that swallows errors. The Claude Code PreToolUse hook needs a binary signal: allow (exit 0) or block (exit 2). Bash gives exactly that with no ceremony. A Python equivalent would work, but it introduces failure modes that bash literally cannot have — uncaught exceptions, import errors, encoding issues in exception handlers.

**Boot cost.** Python interpreter startup is ~30-50ms. Bash is ~5ms. Every PreToolUse hook runs on every file edit. Four hooks on every Write/Edit means 120-200ms of Python startup overhead versus 20ms of bash. This matters when the agent edits 50 files in a session.

**Auditability.** A 30-line bash script that checks "does this file exist, does this grep match" is readable by anyone who has used a terminal. The equivalent Python would be cleaner code but longer, with imports, exception handling, and Path objects — more correct but less auditable at a glance.

If I were starting over today with the benefit of hindsight, I would probably still use bash for the hooks and gates, but I would write the agents (handover, audit, context management) in Python. The agents are complex enough that bash's limitations cause real pain — string parsing YAML in bash is genuinely terrible. The honest answer is that the current split is roughly right but the boundary could move.

---

**4. "Why not zsh?"**

**Steelman:** macOS has shipped zsh as the default shell since Catalina (2019). Every Mac developer has zsh. Zsh has better arrays, better string manipulation, better globbing, associative arrays that actually work, and a more predictable scripting model. If you are going to write shell scripts, write them in the shell that developers actually use.

**Strawman:** It is basically the same thing.

**Our honest position:** Every script in the framework starts with `#!/bin/bash`, not `#!/bin/zsh`, for one reason: bash is the lowest common denominator across all target environments. It is pre-installed on every Linux distribution, every Docker container, every CI runner, every cloud VM. Zsh is not.

macOS ships zsh as the interactive shell, but bash is still available (`/bin/bash`, version 3.2). More importantly, the framework runs in environments where nobody installs interactive shell preferences: Docker containers, systemd services, cron jobs, CI pipelines. These all have bash. Many do not have zsh.

The tradeoff is real: zsh's scripting features are genuinely better. But "works in Docker Alpine without installing anything" beats "nicer array syntax." We chose reach over elegance.

---

**5. "What are the unit tests for bash?"**

**Steelman:** You claim reliability as the second constitutional directive. Reliable systems have tests. Where are the tests for your 30+ bash scripts? You have a task gate, a tier 0 gate, a budget gate, a build readiness gate, an inception gate — each making decisions that block or allow work. How do you know they work? "It blocked me once" is an anecdote, not a test suite. Professional software has unit tests, integration tests, regression tests. Your enforcement layer has none. That is not reliable — that is lucky.

**Strawman:** Bash is hard to test.

**Our honest position:** Marc is right, and this is our weakest point. We do not have a unit test suite for the bash scripts. We should.

What we have instead is a different testing model:

- **Verification gates** — every task has shell commands that must pass before completion. This is integration testing at the task level, not unit testing at the function level.
- **ShellCheck** — static analysis catches common bash errors (unquoted variables, useless cat, etc.)
- **Self-testing in production** — the G-020 build readiness gate blocked its own implementation task (T-471) during development. That was an accidental integration test that proved the gate works. But accidental tests are not a strategy.
- **470+ tasks as evidence** — the hooks have processed thousands of tool calls across 470 tasks. Failures are caught by human intervention and recorded as gaps. But this is testing by observation, not by assertion.

What we lack and need:

- **bats-core** (Bash Automated Testing System) test suite for each gate script
- Tests for edge cases: empty YAML, missing fields, concurrent access, Unicode in file paths
- Regression tests for each governance bypass we have caught (G-020 should have a test that reproduces the original failure and verifies the gate catches it)

This is a genuine gap. A framework that preaches structural enforcement should structurally enforce its own correctness. We have not done that for the enforcement layer itself. Marc caught a real hole.

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
