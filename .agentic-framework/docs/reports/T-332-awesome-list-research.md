# Awesome List Submission Research

**Date:** 2026-03-05
**Subject:** Where and how to submit the Agentic Engineering Framework to curated awesome lists
**Repo:** https://github.com/DimitriGeelen/agentic-engineering-framework

---

## 1. e2b-dev/awesome-ai-agents

**URL:** https://github.com/e2b-dev/awesome-ai-agents

**IMPORTANT:** This list explicitly states:
> "For adding AI agents'-related SDKs, frameworks and tools, please visit Awesome SDKs for AI Agents. This list is only for AI assistants and agents."

**Redirect to:** https://github.com/e2b-dev/awesome-sdks-for-ai-agents

### awesome-sdks-for-ai-agents (the correct target)

- **Star requirement:** None stated
- **Submission:** Pull request (no form, no CONTRIBUTING.md found)
- **Best category:** Listed among frameworks (single flat list, no sub-categories)
- **Alphabetical position:** Between entries starting with "A" — would appear near the top

**Entry format (verbatim template):**
```markdown
## [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework)
A governance framework for systematizing how AI agents work within engineering projects — task enforcement, context management, healing loops, and audit compliance via a CLI (`fw`).

<details>

<!-- ### Description -->
- Provider-neutral governance framework for agentic workflows (not an SDK or runtime)
- Structural enforcement: task gates, commit traceability, budget management, tier-based approval
- CLI entry point (`fw`) with agents for task creation, git, audit, healing, handover, and context
- Supports any file-based, CLI-capable AI agent (Claude Code, Aider, Cursor, etc.)
- Built-in antifragile healing loop, episodic memory, and Component Fabric for impact analysis

### Links
- [GitHub](https://github.com/DimitriGeelen/agentic-engineering-framework)

</details>
```

### awesome-ai-agents (the agent list — secondary option)

If the framework is positioned as a "meta-agent" (it orchestrates agent workflows), it could also fit here:

- **Star requirement:** None stated
- **Submission:** PR or Google Form at https://forms.gle/UXQFCogLYrPFvfoUA
- **Best category:** "Build your own" or "General purpose"
- **Alphabetical position:** After "Agent4Rec", before "AgentForge"
- **Contribution rule:** "Keep alphabetical order and in the correct category"
- **No CONTRIBUTING.md exists** — guidelines are inline in README

**Entry format:**
```markdown
## [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework)
A governance framework for systematizing how AI agents work within engineering projects — enforces task-driven workflows, context budgets, and audit compliance.

<details>

### Category
Build your own, Multi-agent

### Description
- Provider-neutral governance framework (works with Claude Code, Aider, Cursor, etc.)
- Structural enforcement: nothing gets done without a task
- CLI (`fw`) with agents for task creation, git, audit, healing, handover, and context
- Antifragile healing loop: failures become learning events via pattern capture
- Component Fabric for dependency tracking and blast-radius analysis

### Links
- [GitHub](https://github.com/DimitriGeelen/agentic-engineering-framework)

</details>
```

---

## 2. kyrolabs/awesome-agents

**URL:** https://github.com/kyrolabs/awesome-agents

- **Star requirement:** None stated explicitly, but CONTRIBUTING.md rejects "brand new vibe coded repo without demonstrated traction"
- **Submission:** Pull request only (not issues)
- **Contribution rules (from CONTRIBUTING.md):**
  - Must be open source
  - Must demonstrate traction (not brand new without users)
  - No abandoned/unmaintained repos
  - No duplicative entries lacking unique value
  - English only
  - New items go at the **bottom** of the category list
  - PRs not following guidelines face automatic closure
- **Best category:** **Frameworks** section
- **Alphabetical position:** The list is NOT strictly alphabetical within sections (e.g., LangChain appears after llama-agentic-system). New items go at the bottom per CONTRIBUTING.md.

**Entry format (verbatim template):**
```markdown
- [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework): A governance framework for systematizing how AI agents work within engineering projects — task enforcement, context management, healing loops, and audit compliance via CLI ![GitHub Repo stars](https://img.shields.io/github/stars/DimitriGeelen/agentic-engineering-framework?style=social)
```

**Placement:** Bottom of the **Frameworks** section (per CONTRIBUTING.md rule).

---

## 3. alebcay/awesome-shell

**URL:** https://github.com/alebcay/awesome-shell

- **Star requirement:** **50 stars minimum** (explicitly stated in CONTRIBUTING.md)
- **Self-promotion:** Explicitly allowed ("Self-promotion is okay!")
- **Submission:** Pull request
- **Best category:** **For Developers** section (contains git tools, task runners like `just`, pre-commit frameworks)
- **Alternative category:** **Shell Script Development** (contains bash frameworks like bashly, bashful)
- **Alphabetical position (For Developers):** Between `forgit` and `git-extra-commands`
- **Alphabetical position (Shell Script Development):** Between `Fishtape` and `getoptions`

**Entry format (verbatim template — For Developers):**
```markdown
* [fw](https://github.com/DimitriGeelen/agentic-engineering-framework) - A governance framework and CLI for systematizing how AI agents work within engineering projects, with task enforcement, context management, and audit compliance
```

**BLOCKER:** Requires 50+ GitHub stars before submission.

---

## Bonus: bradAGI/awesome-cli-coding-agents

**URL:** https://github.com/bradAGI/awesome-cli-coding-agents

This is a newer, highly relevant list specifically for CLI-based AI coding agents and their infrastructure.

- **Star requirement:** None stated
- **Submission:** Pull request
- **Best category:** **Agent infrastructure** (under "Harnesses & orchestration")
- **No alphabetical ordering required** — entries are loosely grouped by function

**Entry format (verbatim template):**
```markdown
**[Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework)** — Provider-neutral governance framework for CLI coding agents. Structural enforcement of task-driven workflows, context budget management, antifragile healing loops, and audit compliance. Works with Claude Code, Aider, Cursor, and any file-based agent.
```

---

## Summary & Recommended Submission Order

| # | List | Category | Star Req | Difficulty | Priority |
|---|------|----------|----------|------------|----------|
| 1 | bradAGI/awesome-cli-coding-agents | Agent infrastructure | None | Low | **Submit now** |
| 2 | kyrolabs/awesome-agents | Frameworks | Traction | Medium | **Submit now** (if repo has traction) |
| 3 | e2b-dev/awesome-sdks-for-ai-agents | Frameworks | None | Medium | **Submit now** |
| 4 | e2b-dev/awesome-ai-agents | Build your own | None | Medium | Secondary (redirects to SDK list) |
| 5 | alebcay/awesome-shell | For Developers | **50 stars** | Blocked | **Wait for 50 stars** |

### Pre-Submission Checklist
- [ ] Ensure GitHub repo is public
- [ ] Add a clear one-line description to the GitHub repo "About" section
- [ ] Verify README has badges (stars, license) for credibility
- [ ] For kyrolabs: demonstrate "traction" (stars, commits, contributors, issues)
- [ ] For awesome-shell: reach 50 stars first
