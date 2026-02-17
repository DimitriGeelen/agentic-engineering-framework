---
id: T-102
name: Build comprehensive CLAUDE.md template for external projects
description: >
  The generated project CLAUDE.md (lib/init.sh generate_claude_md, ~44 lines) is a thin cheat sheet. The framework CLAUDE.md (506 lines) contains 14 governance sections critical for agent operation. An agent working on an external project gets none of: Constitutional Directives, Authority Model, Enforcement Tiers, Error Escalation Ladder, Context Budget Management (P-009), Sub-Agent Dispatch Protocol, Session Start/End Protocol, full agent command reference, Task File Format, Workflow Types, Instruction Precedence. TASK: Extract universal governance from framework CLAUDE.md into a template. Separate into: (1) universal rules (goes in every project ~350 lines), (2) framework-dev-specific (stays in framework CLAUDE.md only), (3) project-specific sections (generated per project: name, tech stack, conventions). Create lib/templates/claude-project.md as the master template. Update generate_claude_md() in lib/init.sh to use it. ACCEPTANCE: Generated CLAUDE.md includes all enforcement tiers, escalation ladder, context budget, session protocols, dispatch protocol, full fw command reference. DEPENDS ON: Nothing, parallel with T-103. Files: lib/init.sh:197-253, CLAUDE.md (source of truth).
status: work-completed
workflow_type: build
owner: agent
tags: [critical, fw-init, claude-md, template, external-project]
related_tasks: []
created: 2026-02-17T08:53:24Z
last_update: 2026-02-17T08:53:24Z
date_finished: null
---

# T-102: Build comprehensive CLAUDE.md template for external projects

## Context

Discovered during deep architectural analysis session S-2026-0217-0920. Three investigation agents confirmed the generated CLAUDE.md lacks 14 governance sections. This is the highest-value single fix for external project support.

## Dependencies

- **Blocks:** T-104 (wizard needs the template)
- **Blocked by:** Nothing — parallel with T-101, T-103
- **Related:** T-101 (hook fix), T-103 (init hardening)

## Implementation Guide

### Sections to Include (Universal Governance)

From the framework CLAUDE.md, extract these sections verbatim or adapted:

| Section | Lines in CLAUDE.md | Priority | Notes |
|---------|-------------------|----------|-------|
| Core Principle | ~1 line | Critical | "Nothing gets done without a task" |
| Four Constitutional Directives | ~8 lines | Critical | Antifragility, Reliability, Usability, Portability |
| Authority Model | ~6 lines | Critical | Human/Framework/Agent roles |
| Task System (format, lifecycle, workflow types) | ~30 lines | Critical | Agent needs to create valid tasks |
| Enforcement Tiers table | ~8 lines | Critical | What's blocked, how to escalate |
| Error Escalation Ladder (A/B/C/D) | ~15 lines | Critical | Including Proactive Level D |
| Context Budget Management (P-009) | ~20 lines | Critical | Token awareness, commit cadence |
| Sub-Agent Dispatch Protocol | ~40 lines | Medium | Result management rules, max 5 parallel |
| Session Start Protocol | ~10 lines | Critical | Init → handover → focus |
| Session End Protocol | ~8 lines | Critical | Capture → handover → commit |
| Agent command reference (all fw commands) | ~40 lines | Medium | Full quick reference table |
| Working with Tasks | ~15 lines | Critical | Before/during/after task protocol |
| Context Integration | ~5 lines | Medium | Three memory types |
| Instruction Precedence | ~10 lines | Medium | Framework > user > skills |

### Sections to EXCLUDE (Framework-dev-specific)

- Self-referential examples ("T-097 analyzed sub-agent dispatching across 96 tasks...")
- Framework-specific spec file references (005-DesignDirectives.md)
- The framework's own Project Overview section

### Sections to GENERATE Per-Project

- `## Project Overview` — name, description (from fw setup Step 1)
- `## Tech Stack and Conventions` — languages, test framework (from fw setup Step 3)
- `## Project-Specific Rules` — empty placeholder for user additions

### Approach

1. Create `lib/templates/claude-project.md` with placeholder markers: `__PROJECT_NAME__`, `__PROJECT_DESCRIPTION__`, `__TECH_STACK__`
2. Update `generate_claude_md()` in `lib/init.sh` to read the template and substitute placeholders
3. Keep the existing generate function as fallback for `--provider generic`

### Acceptance Criteria

- [x] `lib/templates/claude-project.md` exists with all critical sections (19 sections)
- [x] `fw init /tmp/test --provider claude` generates CLAUDE.md with enforcement tiers, escalation ladder, etc.
- [x] Generated CLAUDE.md is 300-400 lines (not 44, not 506) — 407 lines (slightly over due to comprehensive Quick Reference)
- [x] Generated CLAUDE.md has no framework-development-specific content
- [x] Generated CLAUDE.md has placeholder sections for project-specific content

## Updates

### 2026-02-17T09:15:00Z — work-completed [claude-code]
- **Action:** Created lib/templates/claude-project.md (407 lines) with 19 governance sections. Updated generate_claude_md() in lib/init.sh to use template with sed substitution, falling back to inline generation.
- **Output:** Verified: `fw init /tmp/test-proj --provider claude` generates 407-line CLAUDE.md with 0 un-substituted placeholders. All critical sections present: Constitutional Directives, Authority Model, Enforcement Tiers, Escalation Ladder, Context Budget, Sub-Agent Dispatch, Session protocols, all 8 agents, full Quick Reference table.
- **Context:** Template excludes framework-dev-specific content (T-097 examples, JSONL transcript paths). Includes empty placeholder sections for Tech Stack and Project-Specific Rules.

### 2026-02-17T08:53:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-102-build-comprehensive-claudemd-template-fo.md
- **Context:** Initial task creation
