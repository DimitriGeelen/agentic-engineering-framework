---
id: T-479
name: "Primary development platform: GitHub vs OneDev — source of truth, CI, issues, community interaction for post-launch"
description: >
  Inception: Primary development platform: GitHub vs OneDev — source of truth, CI, issues, community interaction for post-launch

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [infrastructure, launch, portability]
components: []
related_tasks: [T-334, T-442, T-443, T-476]
created: 2026-03-14T12:51:19Z
last_update: 2026-03-14T12:51:19Z
date_finished: null
---

# T-479: Primary development platform: GitHub vs OneDev — source of truth, CI, issues, community interaction for post-launch

## Problem Statement

The framework currently treats OneDev as primary (source of truth) and GitHub as a mirror (public visibility). Launch is imminent (T-334 — Show HN, r/ClaudeAI). When people find the project, they'll find it on GitHub. They'll file issues on GitHub. They'll open PRs on GitHub. They won't have access to OneDev.

This creates a mismatch: the community interaction layer is on the mirror, not the source. The question is whether to flip the relationship — make GitHub primary for community-facing work — or keep the current model and build bridges (GitHub Issues → tasks sync, etc.).

### Current state

- **OneDev** (`onedev.docker.ring20.geelenandcompany.com`): Private instance on LXC, source of truth, all development happens here, no CI pipeline configured, no external access
- **GitHub** (`github.com/DimitriGeelen/agentic-engineering-framework`): Public mirror, pushed after OneDev, has T-476 GitHub Actions workflow (bats tests), token scope issue blocking pushes to workflow files
- **Local enforcement**: Pre-push audit hook runs 99 checks before every push — this IS the CI today
- **Task system**: File-based (`.tasks/`), not tied to either platform's issue tracker
- **Related work**: T-442/T-443 (OneDev PR-to-task cron — now questionable if GitHub becomes primary)

### The trigger

T-476 added a GitHub Actions workflow. Pushing it requires a `workflow`-scoped token. This is a small friction — but it surfaced a bigger question: why is CI on the mirror instead of the source? And if CI should be on GitHub, should everything else follow?

### Options

**Option A: Keep OneDev primary, GitHub as mirror**
- Current model. No change needed.
- Build GitHub Issues → `.tasks/` sync if community interaction grows
- CI stays local (pre-push audit). Remove GitHub Actions workflow.
- Risk: community friction — contributors interact on GitHub but truth lives elsewhere

**Option B: Flip to GitHub primary, OneDev as backup**
- GitHub becomes source of truth for code, issues, PRs, CI
- OneDev becomes private backup/mirror (reverse current flow)
- GitHub Actions workflow makes sense
- T-442/T-443 (OneDev PR sync) becomes irrelevant; GitHub Issues sync matters instead
- Risk: dependency on GitHub infrastructure, portability directive (D4)

**Option C: GitHub for community, OneDev for development**
- Split by function: development workflow stays on OneDev (where the developer works), community interaction happens on GitHub (where contributors find the project)
- Requires clear sync strategy between the two
- Risk: complexity of maintaining two-way sync, unclear source of truth

## Assumptions

- A1: Post-launch community interaction will primarily happen on GitHub (issues, PRs, discussions)
- A2: OneDev provides infrastructure independence that has ongoing value (not just inertia)
- A3: The file-based task system (`.tasks/`) means the source of truth for work management is in git, not in either platform's issue tracker
- A4: A single developer can maintain dual-remote sync without significant overhead
- A5: GitHub Actions CI adds value beyond what the pre-push audit already provides (contributor coverage, visibility)

## Exploration Plan

### Spike 1: Audit current OneDev usage (30min)
What does OneDev provide that GitHub doesn't? CI pipelines, PR workflows, access control, integrations? Is anything actively used beyond git hosting? What would be lost if OneDev became a mirror?

### Spike 2: GitHub community readiness (30min)
What's needed for GitHub to serve as the community front door? Issue templates, PR templates, contributing guide, CI workflow, branch protection? How much of this already exists?

### Spike 3: Sync strategy evaluation (1h)
If both platforms remain active, what's the minimal sync strategy? Push to both remotes (current), GitHub Issues → tasks cron, bi-directional or one-way? What's the operational cost?

## Technical Constraints

- OneDev runs on LXC 170 (192.168.10.170) — private network, no public access without VPN/tunneling
- GitHub token needs `workflow` scope for pushing workflow files
- The framework's file-based task system is platform-agnostic — `.tasks/` lives in git, synced to both
- Traefik routes currently point to OneDev for Watchtower — this is deployment infra, separate from the code platform question
- The `fw` CLI has no GitHub or OneDev dependencies — it works on bare git repos

## Scope Fence

**IN scope:**
- Deciding primary vs. mirror relationship between GitHub and OneDev
- CI strategy (GitHub Actions, OneDev CI, local-only, or hybrid)
- Community interaction model (issues, PRs, discussions)
- Impact on existing tasks (T-442, T-443, T-476)

**OUT of scope:**
- Migrating Watchtower deployment (stays on LXC regardless)
- Building the actual sync tooling (post-GO build task)
- Evaluating other platforms (GitLab, Codeberg, etc.)
- Changing the file-based task system itself

## Acceptance Criteria

### Agent
- [x] Current OneDev usage audited — what would be lost?
- [x] GitHub community readiness assessed
- [x] Sync strategy evaluated with operational cost estimate
- [x] Research artifact written to `docs/reports/T-479-platform-decision.md`

### Human
- [ ] [REVIEW] Decision made: which option (A, B, or C) and why
  **Steps:**
  1. Read `docs/reports/T-479-platform-decision.md`
  2. Review the directive scoring and recommendation (Option B: GitHub primary)
  3. Consider: does the portability concern (D4) outweigh community usability (D3)?
  4. Decide: approve Option B, choose Option A, or request more investigation
  **Expected:** Clear direction on primary platform before T-334 launch
  **If not:** Note specific concerns for further analysis

## Go/No-Go Criteria

**GO (flip to GitHub primary) if:**
- OneDev provides no critical capability beyond git hosting for this project
- GitHub community readiness gap is <1 day of work
- Sync overhead of dual-remote is acceptable or eliminable

**NO-GO (keep OneDev primary) if:**
- OneDev CI or features are actively used and valuable
- Portability concern (D4) outweighs community convenience
- Single-developer workflow doesn't benefit from the switch

## Verification

test -f docs/reports/T-479-platform-decision.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
