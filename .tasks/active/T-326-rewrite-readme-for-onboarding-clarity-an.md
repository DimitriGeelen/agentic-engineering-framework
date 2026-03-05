---
id: T-326
name: "Rewrite README for onboarding clarity and showcase"
description: >
  README scores 2.5-3.7/10 across personas. Rewrite with: (1) concrete value prop and problem/solution
  framing, (2) terminal GIF or screenshot of enforcement in action, (3) progressive disclosure
  (highlights → install → quickstart → deep docs), (4) provider-neutral framing with clear
  Claude/Cursor/Copilot paths, (5) team lead section with CI/CD and Watchtower, (6) fix
  lib/setup.sh reference (should be lib/preflight.sh).

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [docs, onboarding, ux]
components: [README.md]
related_tasks: [T-300, T-312]
created: 2026-03-05T00:24:42Z
last_update: 2026-03-05T00:25:33Z
date_finished: null
---

# T-326: Rewrite README for onboarding clarity and showcase

## Context

5-agent research (session S-2026-0305-0037) found the README fails at its primary job — convincing
new visitors to try the framework. Scores: Skeptic 2/5, Eager Adopter 3/5, Team Lead 1/5,
Contributor 2/5. Research artifacts in `/tmp/fw-agent-readme-*.md` (5 files — copy to
`docs/reports/T-326-*.md` before starting work as they're in /tmp).

Key research files:
- `fw-agent-readme-best-practices.md` — comparison with Ruff, uv, Mise, Just, Biome
- `fw-agent-onboarding-audit.md` — 11+ friction points in install→init→first-task flow
- `fw-agent-provider-neutrality.md` — non-Claude users are lost
- `fw-agent-persona-analysis.md` — 4 persona evaluations
- `fw-agent-readme-showcase.md` — 18 features ranked by wow/differentiation/value

### Structural Idea: Use Component Fabric as README Skeleton

The Component Fabric maps 12 subsystems — use these as the organizing principle for the
"What's Inside" or "Features" section. Each subsystem gets a short description + what it does
for the user. Run `fw fabric overview` for the current topology:

| Subsystem | README angle |
|-----------|-------------|
| **Watchtower Web UI** (37 components) | Live dashboard — task board, audit results, discovery scanner, metrics |
| **Context Fabric** (13 components) | 3-layer memory — working/project/episodic. Agents remember across sessions |
| **Framework Core** (10 components) | `fw` CLI — single entry point for all operations |
| **Git Traceability** (7 components) | Every commit traces to a task. Hooks enforce it structurally |
| **Component Fabric** (7 components) | Structural topology map — blast radius, impact analysis, dependency tracking |
| **Healing Loop** (5 components) | Self-healing — failures become patterns, patterns prevent repeat failures |
| **Learnings Pipeline** (4 components) | Knowledge graduation — learnings → practices → framework rules |
| **Context Budget** (3 components) | Prevents context window exhaustion. Auto-handover at critical |
| **Task Management** (2 components) | Task-first enforcement. File edits blocked without active task |
| **Audit System** (2 components) | Continuous compliance checking — cron + pre-push + on-demand |
| **Handover System** (1 component) | Session continuity — structured handover docs for next session |
| **Hook Enforcement** (1 component) | PreToolUse/PostToolUse gates — task gate, Tier 0, budget gate |

### Missing from Current README (explicitly requested)
- **Watchtower dashboard** — not mentioned beyond a one-line link. Should show screenshots.
- **Component Fabric** — not mentioned at all. Blast radius, dependency tracking, drift detection.
- **Context Fabric** — not mentioned. 3-layer memory, semantic search, episodic recall.
- **Natural language search** — `fw ask`, `fw recall`, semantic search across all project knowledge.
- **Healing loop** — not mentioned. Self-diagnosing, pattern-matching error recovery.
- **Audit system** — barely mentioned. 30-min cron, 90+ checks, discovery scanner.

## Acceptance Criteria

### Agent
- [ ] Opening line is concrete and audience-aware (not "governance framework for systematizing")
- [ ] Value proposition section with before/after or problem/solution framing
- [ ] Highlights section (5-6 bullet points) before install section
- [ ] Progressive disclosure: overview → install → quickstart → deep docs
- [ ] Provider-neutral framing: universal core + provider-specific setup paths
- [ ] "What's Inside" section structured around the 12 Component Fabric subsystems
- [ ] Watchtower dashboard showcased with description of task board, audit results, discovery scanner
- [ ] Component Fabric showcased — blast radius, dependency tracking, drift detection
- [ ] Context Fabric showcased — 3-layer memory (working/project/episodic), semantic search
- [ ] Natural language search mentioned — `fw ask`, `fw recall`, semantic search across knowledge
- [ ] Healing loop showcased — self-diagnosing error recovery, pattern matching
- [ ] Audit system showcased — 90+ checks, cron schedule, discovery scanner
- [ ] Team/CI section mentioning Watchtower dashboard and audit integration
- [ ] Architecture section explains structure (not just a directory listing)
- [ ] Fix `lib/setup.sh` reference → `lib/preflight.sh`
- [ ] Collapsible sections (`<details>`) for secondary information
- [ ] All links valid (`grep -r` check)

### Screenshots (via Playwright MCP)
Use `browser_navigate` + `browser_take_screenshot` to capture Watchtower pages for the README.
Target screenshots (save to `docs/screenshots/`):
- [ ] `watchtower-dashboard.png` — Cockpit/main dashboard overview
- [ ] `watchtower-tasks.png` — Task board with status columns
- [ ] `watchtower-fabric.png` — Component Fabric dependency graph
- [ ] `watchtower-audit.png` — Audit results page
- [ ] `watchtower-discovery.png` — Discovery scanner findings

Watchtower runs at http://localhost:3000. Ensure it's started before capturing.

### Human
- [ ] README passes the "10-second test" — visitor understands WHAT and WHY within 10 seconds
  **Steps:**
  1. Open https://github.com/DimitriGeelen/agentic-engineering-framework
  2. Read only the first screen (no scrolling)
  3. Can you explain to someone else what this does and why they'd want it?
  **Expected:** Yes, clearly
  **If not:** The opening section needs further work

- [ ] Terminal GIF or screenshot effectively demonstrates enforcement in action
  **Steps:**
  1. View the GIF/screenshot in the README on GitHub
  2. Does it show the "blocked without task → fw work-on → success" flow?
  **Expected:** The value is obvious without reading any text

- [ ] Non-Claude user can identify their setup path within 30 seconds
  **Steps:**
  1. Open README as a Cursor user
  2. Can you find Cursor-specific instructions without reading the entire page?
  **Expected:** Clear section or link visible

## Verification

# README exists and has content
test -s README.md

# No broken internal links
grep -oP '\[.*?\]\(((?!http)[^)]+)\)' README.md | grep -oP '\(([^)]+)\)' | tr -d '()' | while read f; do test -e "$f" || echo "BROKEN: $f"; done | grep -c BROKEN | grep -q '^0$'

# lib/setup.sh reference is gone
! grep -q 'lib/setup' README.md

# Progressive disclosure: details tags present
grep -q '<details>' README.md

# Provider-neutral: mentions at least 2 non-Claude agents
grep -cEi 'cursor|copilot|cline|aider' README.md | grep -qv '^0$'

# Key subsystems mentioned
grep -qi 'watchtower' README.md
grep -qi 'component fabric' README.md
grep -qi 'context fabric\|memory system\|episodic' README.md
grep -qi 'healing' README.md
grep -qi 'semantic search\|natural language\|fw ask\|fw recall' README.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives. -->

## Updates

### 2026-03-05T00:24:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Context:** Initial task creation

### 2026-03-05T00:28:00Z — research-complete
- **Action:** 5-agent research completed, findings synthesized
- **Findings:** README scores 2.5-3.7/10. Top issues: abstract opening, no visuals, no value prop, non-Claude users lost, Team Lead persona completely unserved
- **Research:** 5 files in /tmp/fw-agent-readme-*.md (ephemeral — copy to docs/reports/ before work)
