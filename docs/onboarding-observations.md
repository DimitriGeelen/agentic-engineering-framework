# New Project Onboarding Observations

Captured during sprechloop (001-sprechloop) first-session experience.
Source: T-124 (Document new-project onboarding tutorial)

## Observations Log

### O-001: No conversation history to resume
- **When:** User typed `fw context init` in brand new project
- **What happened:** Claude searched for LATEST.md, found none. Ran `fw resume quick` — got "Focus: null". Had to improvise orientation.
- **Impact:** Disorienting first experience. No guided "welcome to your new project" flow.
- **Potential fix:** `fw init` could generate a project-brief.md or seed LATEST.md with a "first session" handover. Or `fw context init` detects first-ever session and prints a welcome with guided steps.

### O-002: Options presented without identifiers
- **When:** Claude presented next-step choices after context init
- **What happened:** Options were prose paragraphs — user couldn't reply "1" or "b". Had to type full sentences.
- **Impact:** Friction, especially for quick decisions.
- **Potential fix:** CLAUDE.md template should instruct agents: "Always present choices as numbered/lettered list so user can reply with just the identifier."

### O-003: Agent ran ahead without user interaction
- **When:** User told Claude to fill inception template
- **What happened:** Claude filled the template, committed it, then immediately built the spike script and committed that too — all without pausing for user review or approval.
- **Impact:** User lost control of the process. Inception tasks are supposed to be exploratory with human-in-the-loop decisions. The agent treated it like a build task.
- **Potential fix:** CLAUDE.md should instruct: "For inception tasks, present the completed template for review before executing any spikes. Pause and ask for approval at each phase boundary." Could also be a framework gate — inception tasks require explicit `fw inception approve-plan` before spike execution.

### O-004: `fw resume quick` unhelpful for new projects
- **When:** First session, no history
- **What happened:** Output was "Focus: null | 1 uncommitted" — technically correct but useless
- **Impact:** Provides no orientation value
- **Potential fix:** Detect empty project state and return something like "New project — no history. Active tasks: T-001. Run `fw work-on T-001` to start."

### O-005: Agent kept building without pausing (escalation of O-003)
- **When:** After filling inception template and building spike script
- **What happened:** Claude committed the spike, then switched to local Whisper (detecting RTX 5060 Ti), then started building a full Flask web app (`spike/app.py` + `spike/static/index.html`) — 4 commits deep, still no user check-in.
- **Impact:** User completely out of the loop. What started as "fill the inception template" turned into a full app build. The inception go/no-go decision was never made, yet code is being written.
- **Potential fix:** Framework should enforce: inception tasks cannot have build commits until `fw inception decide T-XXX go` is recorded. Also, CLAUDE.md should say "After each commit, briefly report what you did and ask if the user wants to continue."

### O-006: Web app built but not started — user not informed
- **When:** Claude built spike/app.py (Flask app with Whisper integration)
- **What happened:** A working web app exists but was never started. User expected to see something running. No mention of how to access it.
- **Impact:** User can't see or interact with what was built. Disconnection between "code exists" and "user can use it."
- **Potential fix:** After building a web app, agent should: (1) start it, (2) report the URL, (3) check port availability first. `fw init` could include a "project portal" concept — auto-start on init with project dashboard.

### O-007: No port/network discovery during project setup
- **When:** Project initialization
- **What happened:** No check for available ports, no awareness of network accessibility (localhost only vs LAN vs internet).
- **Impact:** User has to manually figure out what port to use, whether the app is accessible from other devices (iPhone for pronunciation practice).
- **Potential fix:** `fw init` or first web app startup should: (1) scan for available ports, (2) detect network interfaces, (3) ask user preference: localhost-only / LAN accessible / internet, (4) report access URLs (e.g. "Access from iPhone: http://192.168.x.x:5000"). Store preference in `.framework.yaml` or project config.

### O-008: No way to inject guardrails into a running session
- **When:** User wanted to stop runaway agent in other console
- **What happened:** Hooks snapshot at session start. CLAUDE.md already loaded. Task file changes might not be re-read. No mechanism to interrupt an agent mid-session except typing in the console.
- **Impact:** If the agent goes off-rails, the only option is direct user intervention. No remote kill switch or injection point.
- **Potential fix:** (1) Framework could provide a "circuit breaker" file (e.g. `.context/working/STOP`) that a PostToolUse hook checks — if file exists, agent must pause and report. (2) Commit-count guardrail: PostToolUse hook counts commits since last user message, warns after N consecutive agent-only commits. (3) Inception-specific gate: hook blocks commits on inception tasks if no `fw inception decide` has been recorded.

### O-009: CLAUDE.md template drifted from framework CLAUDE.md
- **When:** Comparing framework (599 lines) vs sprechloop (414 lines, generated from template)
- **What happened:** T-102 built the template carrying almost everything. But after T-102, the framework CLAUDE.md got: Verification Gate (P-011), Horizon scheduling, Task Sizing Rules, plugin bypass warning. The template (`lib/templates/claude-project.md`) was never updated.
- **Impact:** New projects miss critical governance sections. The agent in sprechloop didn't know about verification gates, horizon scheduling, or task sizing rules.
- **Root cause:** No sync mechanism between framework CLAUDE.md and the project template. Manual drift.
- **Potential fix:** (1) `fw audit` should diff framework CLAUDE.md sections against template and warn on drift. (2) Template could be auto-generated from framework CLAUDE.md by stripping framework-specific sections. (3) Add a "template sync" check to the doctor command.

### O-010: Browser API constraints not discovered during inception
- **When:** User tried to use the pronunciation app from a device
- **What happened:** `getUserMedia` (microphone access) requires HTTPS or localhost. Agent built HTTPS with self-signed certs (commit 0333585) but self-signed certs trigger browser warnings and may still block on some devices. This is a fundamental constraint for any web app that records audio.
- **Impact:** The agent built a full web app without discovering this constraint during the inception spike. An inception task should surface blockers like this BEFORE building.
- **Potential fix:** (1) Inception templates should include a "Technical Constraints" section that forces the agent to enumerate platform/browser limitations before building. (2) For web apps with hardware access (mic, camera, GPS), the inception spike should test the API access path FIRST, not build the full app and discover it later. (3) Framework could provide a "constraint checklist" for common web app patterns.

### O-011: Analysis paralysis — agent burned entire context on planning, zero implementation
- **When:** After cycle 1 observations were collected
- **What happened:** Dispatched 3 analysis agents, wrote 3 docs, re-scoped T-124, created 5 child tasks, discussed strategy — consumed entire context window without implementing a single fix. The framework session itself exhibited the same runaway pattern (O-003/O-005) but for analysis instead of building.
- **Impact:** Critical. Full session wasted on planning. Zero fixes shipped. User had to emergency-stop.
- **Severity:** P0
- **Potential fix:** Time-box analysis to 20% of session. After analysis, IMPLEMENT. "One cycle = one fix" not "one cycle = perfect plan."

---

_Keep adding observations below as the session progresses._
