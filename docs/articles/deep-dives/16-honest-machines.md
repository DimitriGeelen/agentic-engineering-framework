# Deep Dive #16: Honest Machines

## Title

A Few Thousand Views, One Star, and Some Fabricated Statistics — An Honest Week of Building in Public

## Post Body

**The last few days I have been posting about the Agentic Engineering Framework — something I am genuinely enthusiastic about. A few thousand views, one or two comments, a couple of likes, one star on the repo. Nobody has used it.**

I do not know if that is because there is so much noise in this space, or because what I am doing and enthusiastic about is just an illusion. As many things are.

So yesterday I asked three different AI agents to critically review what I have been building. Beat the hell out of it. The README, the deep-dive articles, the positioning, the technical claims. They did.

### What they found

The README was positioning the framework as a competitor to assistant runtimes — LangGraph, CrewAI, OpenClaw. It is not. It is a governance layer, not an orchestration engine. The opening lines were wrong. The complexity was front-loaded. There was no five-minute demo.

Worse: I had 15 deep-dive articles. An external reviewer read them all and the verdict was stark. Articles 1 through 7 were genuinely good — real incidents, real task IDs, specific failures that motivated each feature. Articles 8 through 15 were agent-generated filler. Four of them opened with "Governance begins with X." One copied the opening sentence from article 1 word for word. Article 14 included a YAML timestamp from 2023. The framework did not exist in 2023.

Article 9 claims "68% of audit failures stemmed from missing contextual metadata." Article 11 says "32% of pre-implementation commits lacked task linkage, leading to a 47% increase in post-audit rework." These numbers appear nowhere in the project data. The agent invented them because "article with specific percentages" is a stronger pattern than "article with honest uncertainty."

The reviewer's line: "You can feel exactly where the writing changed hands from you to the agent."

### Why I built this in the first place

The critical reviews produced something useful beyond fixing the content. They forced me to articulate why this project exists, stripped of the marketing layer.

The real reason: agents break things. Not occasionally — routinely. You start building something, you get momentum, and then the agent modifies 47 files in a direction you did not intend, or loses context mid-session, or completes a task without consulting you. You cannot restore what you had. The work is gone. That is frustrating in a way that is hard to explain to someone who has not experienced it.

I built the framework to stop that from happening. Task gates that block edits without a declared intent. Context budget monitoring that triggers a handover before the session crashes. Tier 0 enforcement that catches destructive commands before they execute. And it works — I am not getting those breakdown situations anymore. The agent still operates with broad initiative, but within structural constraints that prevent the catastrophic losses.

That is the actual value proposition. Not "governance framework with 12 subsystems and 153 components." Not the ISO 27001 comparison. Just: the agent cannot destroy your work if the gates are in place.

### What is actually valuable here

The critical reviews also surfaced something I had not articulated well. There are two layers of value, and I had been leading with the wrong one.

The first layer is the tooling itself. Task gates, enforcement hooks, session continuity, failure memory. Practical, concrete, solves a real problem that anyone working with AI coding agents will eventually encounter.

The second layer — and the one I find more interesting — is the act of engineering itself. The dogmatic analysis. The deep dives. Exploring options, going back to design decisions, mapping the blast radius of a change before committing it. Agents are a great companion for this work. Not because they replace the thinking but because they make the analytical process tractable at a scale and speed that would be impractical alone.

450 tasks created. 312 completed. Every decision recorded and searchable. Every failure pattern logged. Every learning captured. The framework is its own most elaborate case study — or its own most elaborate yak-shave, depending on your perspective. But the experience of building it, the fluency with agentic systems, the understanding of where they break and how to make them reliable — that is transferable. Not only transferable as a skill itself but transferable in that you can apply agentic engineering techniques to optimise and improve the speed and quality of any work you do.

### The framework governing its own content failure

Here is the part that is self-referential, and I think honestly so.

The framework did not catch the fabricated statistics. No audit rule checks whether a percentage in a markdown file traces to actual project data. The content was generated, committed, and sat in the repository for days.

What the framework did do was structure the response. Within minutes of the review:
- Two tasks created — one for the articles that need an editing pass, one for the articles that need a gut rewrite
- Acceptance criteria with specific verification steps for each
- The project history searched for real incidents to replace the fabricated ones
- The bypass log (596 lines of real enforcement events), learnings database, and episodic memory mined for authentic material

The framework did not prevent the problem. It structured the fix. That is not the same thing, but it is not nothing.

### The harder question

My wife asks where this goes. Does it have any use. That is a legitimate question and she is right to ask it.

The honest answer is that I do not know yet. The adoption metrics say no — one star, no users. The space is noisy and what I am building requires discipline that most developers will not maintain under deadline pressure. The AI tooling landscape moves fast enough that what feels like a gap today may be solved natively by Claude Code or Cursor in six months.

But the "waste of time" framing only holds if the goal is adoption metrics. If the goal is understanding — how these systems behave, how to make them reliable, what breaks and why — then the work is the value. I love the building, the analytics, the discovery, the methodical process. That comes through in the codebase, and it is building something that does not show up in star counts: a fluency with agentic systems at exactly the moment that fluency is becoming valuable.

Whether the project lands as a product, a consulting angle, a methodology, or just the foundation of something else I cannot see yet — I genuinely do not know. What I do know is that the framework caught a high-severity enforcement bypass (T-232), logged 58 Tier 0 approval events, tracked a runaway auto-handover that produced 25 commits in 10 minutes (T-136), and is now governing the fix for its own fabricated content.

The domain changed from human operators to AI agents. The principle did not. And sometimes the most useful thing you can build is the process of building it.

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
cd my-project && fw init --provider claude

# The gate activates immediately — the agent cannot touch a file without a task
fw work-on "My first governed task" --type build

# Start the dashboard to see your tasks
fw serve  # http://localhost:3000
```

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

---

## Platform Notes

**LinkedIn:** Open with "The last few days I have been posting about something I built. A few thousand views, one star, nobody has used it. So I asked three AI agents to beat the hell out of it. Here is what they found."
**Reddit (r/ClaudeAI):** Lead with the agent-breaking-your-work problem — "You start building, you get momentum, and then the agent modifies 47 files in a direction you did not intend." The community will relate immediately.
**Dev.to / Hashnode:** Use as-is. The meta-honesty angle works well for technical audiences who are tired of AI hype.

## Hashtags

#ClaudeCode #AIAgents #AgenticEngineering #BuildInPublic #OpenSource #HonestAI
