# T-327: Project Visibility & Growth Strategy — Research Synthesis

**Date:** 2026-03-05
**Method:** 5-agent parallel research (GitHub, content, community, ecosystem, launch)
**Sources:** /tmp/fw-agent-{github-visibility,content-marketing,community,ecosystem,launch}.md

---

## Executive Summary

The timing is ideal: 2025 was "AI writes code fast," 2026 is "but is it safe?" Only 6% of organizations have AI agent security strategies despite 40% planning to embed agents by end of 2026. No existing project occupies the "governance framework for ALL AI coding agents" position.

**Category to own:** "AI Agent Governance" / "Agentic Guardrails"

**Core message:** "AGENTS.md tells agents what to do. This framework ensures they actually do it."

---

## Top 15 Actions (Ranked by ROI)

### Tier 1 — Do This Week (High Impact, Low Effort)

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 1 | **Set 20 GitHub topics** (ai-agents, claude-code, cursor, governance, etc.) + rewrite About description | 10 min | High — 3-5x search impressions |
| 2 | **Enable GitHub Discussions** (Q&A, Ideas, Show & Tell categories) | 5 min | High — indexed, async community |
| 3 | **Create release v1.0.0** with semantic versioning | 15 min | High — signals maturity |
| 4 | **Add AGENTS.md** alongside CLAUDE.md for cross-agent compatibility | 30 min | Medium — aligns with 60K+ repo standard |
| 5 | **Record 3-min demo video** showing Tier 0 block + task gate + audit pass | 1 hr | High — reusable across all channels |

### Tier 2 — Do This Month (High Impact, Moderate Effort)

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 6 | **Write "I built guardrails for Claude Code"** article on dev.to | 2 hrs | Very High — narrative hook + trending tool |
| 7 | **Create Homebrew Tap** (`brew install DimitriGeelen/tap/fw`) | 1 hr | High — standard CLI distribution |
| 8 | **Submit to 3 awesome lists** (e2b-dev/awesome-ai-agents, kyrolabs/awesome-agents, awesome-copilot) | 1.5 hrs | High — permanent backlinks |
| 9 | **Build GitHub Action** for `fw audit` in CI/CD pipelines | 2-3 hrs | High — captures compliance market |
| 10 | **CONTRIBUTING.md + tag 5-10 good first issues** | 1.5 hrs | High — contributor onboarding |

### Tier 3 — Launch Sequence (Week -1 to +2)

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 11 | **Soft launch on r/ClaudeAI** with "here's what I built" framing | 1 hr | High — most receptive audience |
| 12 | **Submit to Console.dev + TLDR newsletters** | 30 min | Medium — 30K+ and 1.2M+ reach |
| 13 | **Show HN** (Tuesday 9 AM PT, link to GitHub, 200-word intro comment) | 30 min + 6hr engagement | Highest variance, highest ceiling |
| 14 | **Product Hunt launch** 1-2 weeks after HN (needs landing page + hunter) | 3 hrs | Medium — leverage HN momentum |
| 15 | **Submit CFPs** — AI Engineer Europe (Apr 8-10), AI DevSummit (May 27-28) | 2 hrs | Medium — "What happens after vibe coding?" |

---

## Competitive Positioning

| Competitor | They Do | We Do | One-Liner |
|------------|---------|-------|-----------|
| **AGENTS.md** | Config file standard | Structural enforcement with gates | "AGENTS.md is the rules. We enforce them." |
| **Aider** | AI pair programming | Governs what gets committed | "Aider writes code. We make sure it's tracked." |
| **Continue.dev** | IDE AI integration | Pre-operation structural gates | "Continue suggests. We ensure there's a task first." |
| **OpenHands/Devin** | Autonomous agents | Guardrails for autonomous agents | "OpenHands acts. We ensure it can't exceed authority." |
| **Commitizen** | Commit formatting | Full lifecycle governance | "Commitizen formats messages. We enforce the lifecycle." |

---

## Content Calendar (4 Weeks)

| Week | Content | Platform |
|------|---------|----------|
| 1 | 3-min demo video | Twitter/X, Reddit |
| 1 | "I built guardrails for Claude Code" | dev.to, cross-post Hashnode |
| 2 | Share article + discussion | r/ClaudeAI, r/opensource |
| 2 | LinkedIn post (enterprise governance angle) | LinkedIn |
| 3 | Twitter thread: "5 things AI agents should never do autonomously" | Twitter/X |
| 3 | Submit to Console.dev, TLDR, Changelog | Newsletters |
| 4 | Show HN launch (Tuesday 9 AM PT) | Hacker News |
| 4 | YouTube "Getting Started in 10 minutes" | YouTube |

---

## Ecosystem Integrations (Priority Order)

1. **P0:** GitHub Action for `fw audit` — CI/CD compliance gate
2. **P1:** MCP Server on smithery.ai/glama.ai — native Claude Code/Cursor integration
3. **P1:** Homebrew Tap + npm wrapper — standard distribution
4. **P1:** `.cursorrules` template — easy Cursor onboarding
5. **P2:** Docusaurus docs site on GitHub Pages
6. **P2:** VS Code extension (task sidebar, audit status)
7. **P3:** JetBrains plugin

---

## SEO Terms to Target

- "Claude Code best practices" (highest volume)
- "AI agent guardrails" / "AI agent governance"
- "AI code audit trail"
- "Claude Code hooks" / "CLAUDE.md setup"
- "AGENTS.md best practices"
- "autonomous coding agent risks"

---

## Key Timing Hooks

- **Singapore AI Governance Framework** (Jan 2026) — regulatory alignment
- **AAIF/Linux Foundation** stewards AGENTS.md — position as "the layer above"
- **Claude Code's 24% market share** — growing audience for governance tools
- **4% of GitHub commits AI-generated** — stat hook for articles

---

## Community Playbook

1. **Now:** GitHub Discussions (async, zero cost)
2. **At 50+ users:** Discord with #general, #support, #ideas, #show-your-setup
3. **Ongoing:** Be present in r/ClaudeAI, Anthropic Discord, AI engineering communities
4. **Self-case-study:** "325 tasks, 96% traceability" — the framework governs itself

---

## Launch Prerequisites Checklist

- [ ] README passes 10-second test (done — T-326)
- [ ] `git clone && fw doctor` works in <2 min
- [ ] 90-second demo video recorded
- [ ] At least 2 example projects showing framework in action
- [ ] CONTRIBUTING.md exists
- [ ] Good first issues tagged (5-10)
- [ ] GitHub topics set (20)
- [ ] Release v1.0.0 tagged
- [ ] AGENTS.md file added
- [ ] Landing page live (GitHub Pages minimum)
