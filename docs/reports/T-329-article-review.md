## Factual Accuracy Review

**Article:** `docs/articles/launch-article.md`
**Source of Truth:** `README.md`
**Reviewed:** 2026-03-06

---

### Correct Claims

- **Core principle "nothing gets done without a task"** — matches README exactly (line 19: "File edits are blocked until an active task exists")
- **Enforcement flow diagram** (Task gate -> Budget gate -> Edit) — identical in both files, including "Context > 75%" threshold
- **Three-layer memory** (working, project, episodic) — descriptions match README lines 87-89
- **Authority model** (Human=Sovereignty, Framework=Authority, Agent=Initiative) — exact match with README lines 301-305
- **Enforcement tiers table** (Tier 0-3) — article table matches README table on lines 192-198; article descriptions are slightly condensed but accurate
- **Healing loop** with escalation ladder A/B/C/D — matches README lines 173-181
- **90+ compliance checks** — matches README line 24 ("90+ compliance checks") and line 184
- **Audit runs every 30 minutes, on every push, and on demand** — matches README lines 185-187
- **126 components across 12 subsystems** — matches README lines 67, 94, 326 ("126 components across 12 subsystems")
- **175 dependency edges** — matches README line 94
- **96% commit traceability** — matches README line 338
- **fw recall semantic search** — matches README lines 91, 237
- **`fw work-on` as the start command** — matches README line 57
- **`fw handover --commit` as session end** — matches README line 60
- **Task lifecycle: Captured, In Progress, Issues, Completed** — matches README line 65 implicitly (Kanban board description)
- **Install script URL** — matches README line 51
- **Apache 2.0 license** — matches README line 342
- **Provider support: Claude Code, Cursor, generic** — matches README lines 245-261
- **fw fabric deps / blast-radius / drift examples** — match README examples on lines 112-125
- **Component YAML cards in `.fabric/components/`** — matches README line 132
- **Git commit traceability enforcement** — matches README lines 165-171

### Issues Found

1. **"325 tasks completed" may be outdated** — Article says "325 tasks completed" (lines 187, 206, 229). README also says "325 tasks completed" (line 338). However, the actual `.tasks/completed/` directory currently contains **312 files**, and `.tasks/active/` contains **21 files** (333 total). The "325 completed" figure appears to be either (a) a snapshot from when the article/README was written that has since drifted (tasks may have been renumbered, merged, or the count includes tasks completed in a different way), or (b) slightly inflated. **Both article and README agree on 325, so internally consistent, but may not match actual file count (312 completed).**

2. **"Five things" vs "Four Constitutional Directives"** — Article claims effective intelligent action requires "five things" (line 12: clear direction, context awareness, resource constraints, impact awareness, engaged actors). The README's core principles section lists **Four Constitutional Directives** (Antifragility, Reliability, Usability, Portability — lines 293-299). These are different framings — the article's "five things" is the author's personal governance philosophy mapped to framework mechanisms, while the README's "four directives" are the framework's internal constitutional principles. **Not a contradiction** (they operate at different levels), but readers going from article to README will not find the "five requirements" table anywhere in the README. The article's mapping table (lines 57-63) is article-original content.

3. **Homebrew install mentioned in article but NOT in README** — Article includes `brew tap DimitriGeelen/agentic-fw && brew install fw` (line 240). The README has **no mention of Homebrew**. The Homebrew tap task (T-330) exists but appears to still be in active tasks with `status: work-completed` and `owner: human`, suggesting it may not yet be publicly available or is not documented in the README. **Unsupported claim** relative to README as source of truth.

4. **"install script, Homebrew tap, documentation, GitHub Action" (article line 227)** — Article lists four distribution mechanisms. README mentions install script (line 51) and GitHub Action (lines 267-274). README does NOT mention Homebrew tap. So **Homebrew tap is unsupported by README**.

5. **GitHub Discussions link** — Article links to `github.com/DimitriGeelen/agentic-engineering-framework/discussions` (line 257). README makes no mention of GitHub Discussions. **Not a factual error** (it may exist), but unsupported by README.

6. **Shell/Hypercare biographical claims** — Article makes several personal biographical claims (lines 14-15: "At Shell I built the Global Transition Management Framework — 8 assurance areas, 50+ templates, quality gates including Hypercare. Personally led 80+ transitions. Adopted as the global standard, used for 1,000+ transitions globally."). These are **not verifiable from the README** — they are biographical claims that exist only in the article. Not incorrect per se, but entirely unsupported by the README source of truth.

7. **"Over 325 tasks, these patterns compound" (article line 187)** — This is slightly different from "325 tasks completed" — "over 325" implies more than 325. The README says exactly "325 tasks completed." Minor inconsistency within the article itself (line 206 says "325 tasks completed" while line 187 says "over 325 tasks").

8. **Missing nuance: Provider enforcement depth** — Article says (line 220) "Full structural enforcement with Claude Code via hooks. CLI governance with Cursor and any other agent." The README provides more nuance (lines 245-261): Cursor gets `.cursorrules` + CLI + git hooks but "Write/Edit gates require manual discipline — Cursor doesn't support pre-operation hooks." Generic providers get "Structural enforcement is voluntary." The article's "CLI governance" undersells the difference — README makes clear that without hooks, enforcement is significantly weaker.

9. **Missing nuance: Budget gate threshold** — Both article and README show "Context > 75%" in the flow diagram. However, CLAUDE.md (the full reference) specifies the actual thresholds more precisely: 120K ok->warn, 150K warn->urgent, 170K urgent->critical, with blocking at >=150K (~75%). The article's 75% is a simplification that matches the README diagram, so this is consistent but simplified.

10. **Article commit log examples** — Article lines 211-215 show specific commits (27e8ed1, d8cd81e, etc.). These are real commits visible in the git log. **Verified correct.**

### Recommendations

1. **Reconcile task count.** Either update the "325 tasks completed" figure in both README and article to match the actual completed task count (currently 312), or clarify what "325" refers to (e.g., total tasks created including active ones: 333). The number should be consistent and verifiable.

2. **Add Homebrew to README or remove from article.** If the Homebrew tap is live, add it to the README Quickstart section. If it is not yet available, remove it from the article to avoid disappointing readers.

3. **Fix "over 325" inconsistency in article.** Line 187 says "over 325 tasks" but line 206 says "325 tasks completed." Pick one and be consistent.

4. **Consider adding nuance about provider enforcement.** The article could add one sentence clarifying that enforcement depth varies by provider, since this is a significant practical distinction that README covers well.

5. **Verify GitHub Discussions is enabled.** If the article links to Discussions, ensure it is actually enabled on the GitHub repository.

6. **The "five things" framing is effective but novel.** It does not appear in the README or CLAUDE.md. Consider whether to add it to the README's "Core Principles" section for consistency, since it is a compelling framing that readers may look for after reading the article.
# Completeness Review: Launch Article vs README

## Genuinely Valuable Omissions

### 1. Team Usage / CI/CD Integration (HIGH VALUE -- missing entirely)
The README has an entire **Team Usage** section describing:
- Git hooks that install per-repo for every team member (`fw git install-hooks`)
- A **GitHub Action** that gates PRs on compliance (`DimitriGeelen/agentic-engineering-framework@v1`)
- Watchtower deployment for team-wide visibility

The article reads as a solo-developer story. Mentioning that this scales to teams -- shared hooks, CI/CD gating, dashboard for team visibility -- would significantly broaden appeal for the dev.to audience, many of whom work in teams. A 2-3 sentence mention in the "Where it stands" section or a brief subsection would suffice.

### 2. Multi-Provider Support (MEDIUM-HIGH -- mentioned but buried)
The article says "It is provider-neutral" in one sentence near the end. The README dedicates a full section to three explicit setup paths:
- **Claude Code**: full structural enforcement via hooks
- **Cursor**: `.cursorrules` generation + CLI governance
- **Other agents (Copilot, Aider, Devin)**: FRAMEWORK.md as operating guide

This is a genuine differentiator. Most governance tools are provider-specific. A brief expansion (even 2-3 sentences with the `fw init --provider` commands) would signal "this works with YOUR tool" to a broader audience, not just Claude Code users. The current article's tags include "claudecode" but the body barely explains multi-provider support.

### 3. Learnings Pipeline / Knowledge Graduation (MEDIUM -- missing entirely)
The README describes a structured knowledge promotion system:
```bash
fw promote suggest        # Find graduation candidates
fw promote L-042 --name "Always validate inputs" --directive D1
```
This is where individual task learnings graduate to project-wide practices. The article mentions the healing loop (failure patterns), but not the explicit graduation mechanism that turns ad-hoc learnings into codified practices. This is the "institutional knowledge" lifecycle that completes the story -- and it maps well to the article's enterprise governance narrative.

### 4. Inception Phase (MEDIUM -- missing entirely)
The README describes structured exploration before committing to build:
```bash
fw inception start "Evaluate caching strategy"
fw inception decide T-099 go    # Records decision, creates build tasks
```
This is a meaningful differentiator: the framework has a formal "think before you build" phase with go/no-go gates. For the article's target audience (developers who've watched agents charge ahead without planning), this would resonate. Could be a single sentence in the "What I built" section.

### 5. "When to Use / When Not to Use" Honesty (MEDIUM -- partially covered)
The README has a crisp section on when to use and when NOT to use the framework. The article's "Where it stands" section covers the "alpha" caveat honestly, but doesn't give the practical guidance:
- Use when: AI agents work on your codebase regularly, you need audit trails, sessions span multiple days
- Skip when: Quick one-off prototypes, solo projects under a week

Adding 2-3 sentences of "this is designed for X, not Y" would help readers self-select and builds trust.

### 6. Watchtower Timeline View (LOW-MEDIUM -- screenshot exists in README, absent from article)
The README shows a timeline screenshot that visualizes session history across time. The article includes dashboard, task board, and fabric graph screenshots but not the timeline. This is visually compelling evidence of session continuity -- a core selling point. If the article has room for one more screenshot, this would be the strongest addition.

### 7. Semantic Search / `fw recall` (LOW -- mentioned in article but could be stronger)
The article mentions `fw recall` once with an example. The README emphasizes "find patterns by meaning, not just keywords." Given that semantic search across project knowledge is a genuinely novel capability, one additional sentence emphasizing this searches across ALL three memory layers (not just text matching) would strengthen the context fabric section.

## Features Appropriately Omitted (no action needed)
- Architecture diagram / directory structure -- too implementation-detailed for an article
- Full key commands table -- the article has enough CLI examples inline
- Four Constitutional Directives detail -- covered implicitly through the mechanisms described
- Homebrew tap -- already mentioned in the "Try it" section
- Detailed component card YAML format -- too granular

## Summary Recommendation
The highest-value additions are **Team Usage/CI/CD** (broadens audience from solo to team), **Multi-provider support** (broadens from Claude Code to all agents), and **Learnings Pipeline** (completes the institutional knowledge narrative). These three could be added in roughly 150-200 words total without exceeding the target length, likely by trimming some of the longer code blocks or the repeated Tier table.
# Tone & Voice Review: Launch Article

**Target voice:** Authoritative, experience-grounded, declarative. No hype. First person, understated confidence. Enterprise governance practitioner drawing parallels to AI agent governance. Factual, direct, never oversells.

**Overall assessment:** The article is strong. The voice is consistent across 80%+ of the text. The opening two paragraphs and the closing section are the best writing in the piece -- grounded, earned, precise. The issues below are mostly minor recalibrations, not structural problems.

---

## Tone Breaks

### 1. Line 34: "Not guidelines. Not best practices. Enforcement."
**Issue:** This is a copywriting rhythm (the three-beat staccato negation). It reads like a product landing page, not a governance practitioner writing from experience. The author's natural voice is longer declarative sentences with subordinate clauses (see the opening paragraph -- that is his rhythm).

**Suggestion:** Fold into a single declarative sentence: "The framework applies structural governance to AI coding agents -- not guidelines or best practices, but mechanical enforcement."

### 2. Line 36: "This is not a convention. It is a gate."
**Issue:** Same copywriting staccato. Two short sentences punching for effect. The author does this naturally in some places (e.g., "Initiative is not authority" on line 82 -- that one works because it is an analytical distinction, not a sales beat). Here it reads like emphasis for emphasis's sake.

**Suggestion:** "This is enforced as a gate, not a convention." One sentence, same meaning, matches the analytical voice.

### 3. Line 171: "This turns 'I changed a file, hope nothing breaks' into 'I know exactly what is downstream and I tested the right things.'"
**Issue:** The scare-quote paraphrasing ("hope nothing breaks") is a tech-blogger device. The rest of the article never uses this kind of imagined internal monologue. It is slightly glib for this author's register.

**Suggestion:** "The difference is between modifying a file without knowing its dependents and modifying it with a verified understanding of downstream impact." -- Drier, but that is the voice.

---

## Voice Inconsistency

### 4. Lines 131-137: Context Fabric section opening
**Issue:** "The most expensive failure in agent-assisted development is not a bug. It is lost context." -- This is a strong opening. But the bullet list that follows (lines 135-137) shifts into product-documentation voice. Phrases like "auto-generated at completion" and "Not raw logs. Structured summaries" read like README feature descriptions rather than a practitioner explaining why something matters.

**Suggestion:** Keep the bullets but ground each one in the *consequence* (the practitioner's perspective) rather than the *feature* (the product perspective). For example, project memory: instead of "patterns, decisions, and learnings that persist across all sessions. When the agent encounters a failure it has seen before, the resolution is already there" -- try "decisions and failure patterns that accumulate across sessions. The agent does not rediscover what was already learned."

### 5. Lines 57-63: The five-requirements mapping table
**Issue:** The table entries are written in mixed voice. "Clear direction" and "Engaged, capable actors" rows are crisp. But "Awareness of context window" includes "No session ends in an unrecoverable state" -- that is a guarantee claim, not a description. And "Awareness of impact" includes "Informed analysis, not guesswork" -- the negation pairing ("not guesswork") is a sales contrast, not a factual description.

**Suggestion:** Replace "No session ends in an unrecoverable state" with "Sessions hand over context before the agent loses coherence." Replace "Informed analysis, not guesswork" with "The agent queries the structural map before modifying files."

---

## Overstatement

### 6. Line 61: "No session ends in an unrecoverable state."
**Issue:** This is an absolute guarantee in an alpha framework. The author explicitly acknowledges bugs and rough edges on line 227. An absolute "no session" claim contradicts his own honesty section. This is the most significant overstatement in the piece.

**Suggestion:** "The framework triggers automatic handover before the agent loses coherence, preserving session state for the next session." -- Describes the mechanism and intent without guaranteeing perfection.

### 7. Line 187: "Over 325 tasks, these patterns compound. The framework learns from its own history."
**Issue:** "The framework learns" anthropomorphizes the system. The framework stores patterns and surfaces them. The human and agent learn; the framework is a record. This is a subtle overstatement but it clashes with the authority model's precision about what the framework does vs. what the agent does.

**Suggestion:** "Over 325 tasks, these patterns accumulate. Resolutions from prior failures are surfaced when similar issues recur."

### 8. Line 206: "96% commit traceability"
**Issue:** Not an overstatement per se, but the precision of "96%" invites the question: over what population and period? If the denominator is all 325 tasks, say so. If it is measured differently, clarify. A precise number without methodology can read as cherry-picked rather than rigorous -- which undermines the governance-practitioner credibility.

**Suggestion:** Add one clause: "96% of commits reference a task ID" or "96% commit traceability across the full 325-task history."

---

## Understatement

### 9. Line 14: "Adopted as the global standard, used for 1,000+ transitions globally."
**Issue:** This is buried in a dense paragraph and reads almost throwaway. The fact that the author's prior framework became Shell's global standard for 1,000+ transitions is the single strongest credential in the piece. It deserves its own sentence with slightly more weight, not a comma-separated clause in a list.

**Suggestion:** Break it out: "Shell adopted it as the global standard. It has been used for over 1,000 transitions worldwide." Two sentences. Still factual. But the reader registers the scale.

### 10. Lines 225-231: "Where it stands" section
**Issue:** This section is appropriately honest, but the pivot from "there are bugs" to "I use it daily" is slightly too fast. The daily-use claim is actually strong evidence, but it is undercut by being sandwiched between caveats. The practitioner voice should own the evidence more confidently before returning to the caveat.

**Suggestion:** Reorder: lead with the evidence ("I use this daily. 325 tasks completed. The governance model holds."), then the caveat ("That said, it is alpha. There are rough edges..."), then the invitation. The confidence should come first because it is earned.

---

## Wording Issues

### 11. Line 12: "And people who are genuinely engaged and capable of acting."
**Issue:** "Capable of acting" is vague. The other four requirements are concrete (direction, context, constraints, impact). This one trails off into abstraction. In the table on line 63 it maps to "Tiered authority model. The agent has initiative but not authority" -- that is much sharper.

**Suggestion:** "And actors who are engaged and empowered to act within clear boundaries." -- Mirrors the authority model more precisely.

### 12. Line 12: "requires five things" but the opening metadata says "four things"
**Issue:** The `description` field in the YAML frontmatter (line 4) says "requires four things." The body text (line 12) says "five things." The table on lines 57-63 lists five rows. This is a factual inconsistency, not a tone issue, but it undermines credibility.

**Fix:** Update the frontmatter description to say "five things."

### 13. Line 146: "the same way a well-run programme office does"
**Issue:** "Programme office" is British English and enterprise-specific jargon. The rest of the article uses it naturally (the author is British, this is his domain). But this specific instance appears at the end of a section aimed at developers who may not have programme office experience. It may land as opaque rather than illuminating.

**Suggestion:** "the same way institutional knowledge accumulates in a well-run organisation" -- slightly more accessible, same meaning.

### 14. Line 220: "same pattern as having one programme office, not five"
**Issue:** Similar to above -- the analogy assumes the reader knows what a programme office is and why having five would be bad. For the dev.to audience, this may not land.

**Suggestion:** "same pattern as a single governance interface regardless of how many teams are executing" -- more self-explanatory.

### 15. Line 68: "the same way a programme board works"
**Issue:** Third instance of programme-office jargon as analogy. One or two is the author's voice; three starts to feel like a tic. Consider keeping the strongest one (line 93, "quality gates in transition management" -- that one is the most specific and evocative) and generalising the other two.

---

## Summary

The article is well-written and the voice is largely consistent. The main risks are:
1. **Three instances of copywriting staccato** (lines 34, 36, 171) that break the practitioner register
2. **One absolute guarantee** (line 61) that contradicts the alpha caveat
3. **The four/five mismatch** in the frontmatter -- a factual error that should be fixed before publication
4. **Programme-office jargon density** -- natural for the author but may lose the dev.to audience in three spots

None of these require major rewriting. They are calibration adjustments.
# Technical Clarity Review: Launch Article for dev.to

**Reviewer:** Technical clarity reviewer (dev.to audience perspective)
**Article:** `/opt/999-Agentic-Engineering-Framework/docs/articles/launch-article.md`
**Reference:** `/opt/999-Agentic-Engineering-Framework/README.md`

---

## 1. What the Framework Does — Is It Clear Within 3 Paragraphs?

**Verdict: Almost, but not until paragraph 4.**

The first three paragraphs (lines 12-16) are about the author's background at Shell and the derivation of a universal principle. The framework is mentioned only as "So I built a framework for it" at line 16. A developer scanning quickly would not yet know what the framework *does* by the end of paragraph 3.

The "What I built" section (line 33 onward) is where clarity arrives. This is paragraph 5-6 for most readers.

**Recommendation:** The Shell/transition-management backstory is compelling but front-loads enterprise context before explaining the tool. Consider moving the core value proposition ("structural governance for AI coding agents — task-first enforcement, persistent memory, tiered authority") into the first or second paragraph, then use the Shell backstory as supporting credibility. The dev.to audience will decide within 10 seconds whether to keep reading; the current opening risks losing developers who see "Shell" and "programme governance" before they see what this does for their workflow.

---

## 2. How It Works — Technical Mechanisms

**Verdict: Good. The gate diagram and tier table are effective.**

The ASCII flow diagram (lines 38-53) is clear and immediately communicable. The tiered enforcement table (lines 86-91) is concise. The "before/after" bash comparison (lines 97-127) is the strongest explanatory section in the article.

**Issue:** The article references "five things" (line 12) but the mapping table (lines 56-63) lists five rows. However, one of the five — "Engaged, capable actors" — maps to the agent itself, not to a framework mechanism. This feels like a stretch. The other four have concrete enforcement. This one is a philosophical statement about tiered authority. It is not wrong, but a developer will notice the asymmetry.

**Issue:** The phrase "Context Fabric" appears first at line 129 as a section header. Prior to that, line 60 references it in the table but does not explain that it is the name of the memory subsystem. A reader hitting the table may momentarily wonder what "Context Fabric" means — is it a library? A file? A concept?

**Recommendation:** When first mentioning "Context Fabric" in the table (line 60), add a parenthetical: "Context Fabric (the framework's memory subsystem)" or similar.

---

## 3. Code Examples — Clear, Realistic, Copy-Pasteable?

**Verdict: Mostly yes, with two issues.**

**Good:**
- `fw work-on "Add JWT validation" --type build` (line 111) — clear, realistic
- `fw git commit -m "T-042: Add JWT validation middleware"` (line 114) — demonstrates the task-reference convention
- `fw healing diagnose T-015` (line 183) — minimal, understandable
- Install commands (lines 235-247) — clean and standard

**Issue 1: `fw recall` command (lines 141-143).** This is a compelling example, but it implies the command exists and returns formatted results. The README also mentions `fw recall` (line 237). If this command actually works as shown, excellent. If it requires Ollama or external dependencies to function, that should be noted. A developer who installs and immediately tries `fw recall "authentication timeout pattern"` and gets an error will lose trust.

**Issue 2: The `$` prefix is inconsistent.** Lines 159-168 use `$` prompts; lines 183-184 do not; lines 111-127 do not; lines 194-199 do not. This is a minor style inconsistency but noticeable on dev.to where code blocks are scrutinized.

**Recommendation:** Standardize the `$` prompt usage. Either always use it for commands that show output, or never use it. The common dev.to convention is to omit `$` for copy-paste friendliness (readers triple-click to select lines).

---

## 4. Jargon — Framework-Specific Terms Without Explanation

**Terms used without definition:**

| Term | First appearance | Issue |
|------|-----------------|-------|
| **Context Fabric** | Line 60 (table), 129 (header) | Named in passing before being explained in its own section |
| **Component Fabric** | Line 151 (header) | Introduced as a section header but "fabric" as a concept is never defined |
| **Episodic memory** | Line 137 | Borrowed from cognitive science. Meaning is clear from context, but some developers may not know why it is called "episodic" |
| **Healing loop** | Line 176 (header) | "Self-healing" is used in the README but not in the article. The concept is explained, but "healing loop" as a term may suggest automatic repair rather than assisted diagnosis |
| **Tier 0/1/2/3** | Lines 86-91 | Well-defined in the table. No issue |
| **Blast radius** | Line 163 | Common DevOps term, should be fine for dev.to audience |
| **Acceptance criteria** | Line 218 | Standard. No issue |

**Recommendation:** The word "Fabric" is used for two different subsystems (Context Fabric, Component Fabric). This is an internal naming convention that may confuse new readers. Consider a one-sentence explanation of the naming pattern: "The framework uses 'fabric' to describe structural maps — the Context Fabric maps memory, the Component Fabric maps code dependencies."

---

## 5. Diagrams and Tables

**Verdict: Effective.**

- The ASCII gate diagram (lines 38-53) is the most immediately useful visual. Clear flow, clear outcomes.
- The requirements mapping table (lines 56-63) is well-structured.
- The tier table (lines 86-91) is concise and scannable.
- The authority model (lines 77-80) is clean ASCII.

**No issues found.**

---

## 6. Screenshots — Do Captions Explain What the Reader Is Seeing?

**Verdict: Adequate but could be stronger.**

| Screenshot | Caption | Assessment |
|------------|---------|------------|
| Task Board (line 67-68) | "Tasks are not hidden in text files. They are visible, trackable, and auditable" | Good — explains the *why*, not just the *what* |
| Dashboard (line 148-149) | "surfaces tasks awaiting human verification, work direction, and system health" | Good — describes content areas |
| Dependency graph (line 173-174) | "filter by subsystem, switch layouts, click nodes" | Good — describes interactions |
| Task detail (line 222-223) | "acceptance criteria, verification commands, decisions, and episodic summary" | Good — lists what's visible |

**Issue:** None of the captions describe what the *data* in the screenshot represents. For example, the Task Board caption does not say "Each card is a task with its status, owner, and horizon." A developer unfamiliar with the framework might not understand the card structure.

**Minor issue:** The screenshots use `raw.githubusercontent.com` URLs. These will work on dev.to but may be slow to load and could break if the repository is renamed or the branch changes.

---

## 7. Install Instructions — Would a Reader Know How to Try This?

**Verdict: Yes, with one gap.**

The "Try it" section (lines 233-247) is clear:
1. Install via curl or Homebrew
2. `cd your-project && fw init`
3. `fw work-on "Set up project structure" --type build`

**Gap:** There is no mention of prerequisites. Does this require bash 4+? Python? Node.js? The README mentions Flask and htmx for Watchtower but does not list system requirements. A developer on macOS with bash 3.2 (Apple's default) may hit issues. A developer on Windows via WSL may have different questions.

**Gap:** After `fw init`, what happens? The README says it creates `.context/`, `.tasks/`, git hooks, and a provider config file. The article does not mention this. A developer running `fw init` in an existing project may wonder what just changed in their directory.

**Recommendation:** Add one line after the install block: "**Requires:** bash 4+, git. Optional: Python 3.8+ for Watchtower dashboard." And consider adding: "`fw init` creates `.context/`, `.tasks/`, and git hooks in your project directory."

---

## 8. Ambiguity — Sentences That Could Be Misunderstood

**Line 12:** "effective intelligent action ... requires five things" — but the list that follows contains five items only if you count them carefully. The sentence itself lists five phrases separated by periods, which could be read as four (with "Awareness of context" being one item, not split into sub-items). The mapping table later has five rows, which clarifies, but the initial enumeration is ambiguous.

**Line 36:** "The framework intercepts every file modification and blocks it unless an active task exists." — This is only true for Claude Code (via hooks). For Cursor and other agents, it is not intercepted — it relies on convention. The article later says "It is provider-neutral" (line 220) but does not clarify the enforcement asymmetry between providers until the README's "Agent Setup" section. A reader could believe all agents get full interception.

**Recommendation:** Add a qualifier: "With Claude Code, the framework intercepts every file modification..." or note the enforcement gradient.

**Line 191:** "90+ compliance checks run automatically — every 30 minutes, on every push, and on demand." This implies the cron audit is configured by `fw init`. Is it? If the user needs to set up cron separately, this is misleading.

**Line 206:** "325 tasks completed. 96% commit traceability." — These are impressive numbers but they describe the framework's own development, not a user's project. This is clear in context but could be misread as a claim about general outcomes.

---

## Overall Assessment

**Strengths:**
- The before/after bash comparison is the strongest section — leads with concrete developer experience
- The ASCII gate diagram is immediately legible
- The tier table is clean and actionable
- The "Where it stands" section (lines 225-231) is refreshingly honest about alpha status
- Code examples are realistic and demonstrate real workflows

**Weaknesses:**
- Opening paragraphs front-load enterprise backstory before explaining the tool
- "Context Fabric" and "Component Fabric" are used before being defined
- Enforcement asymmetry between Claude Code and other agents is not surfaced
- No prerequisites listed in install section
- The "five things" enumeration is slightly ambiguous on first read

**Overall readability for dev.to:** 7.5/10. The article is well-written and the technical content is sound. The main risk is losing readers in the first three paragraphs before they discover what the tool does. Reordering to lead with the developer problem and tool, then support with the governance backstory, would significantly improve engagement.
# Structure and Flow Review: Launch Article

**Reviewer focus:** Structure, flow, pacing, and reader retention for a dev.to audience.

---

## 1. Hook Quality

**Rating: Strong, with one risk.**

The opening paragraph is distinctive. It does not start with "I built a tool" — it starts with a principle derived from experience. The Shell credential (global standard, 1,000+ transitions) is specific and verifiable, which builds credibility fast. The five requirements framing gives the reader a mental model before any product is introduced.

**Risk:** The opening is dense. Two paragraphs of career context before any mention of AI agents. A dev.to reader scanning for "what is this tool" may bounce before reaching paragraph three ("When I started building with agentic coding tools"). Consider whether the Shell paragraph could be tightened to two sentences — the detail is impressive but could be moved lower. As-is, the payoff line ("So I built a framework for it") arrives at the end of paragraph three. On dev.to, most readers decide to continue or leave within the first 5 seconds of scrolling.

**Suggestion:** The transition sentence "When I started building with agentic coding tools I recognised the same pattern" is the hinge. It could be stronger if it appeared earlier — even as sentence two — with the Shell backstory following as evidence rather than preamble.

---

## 2. Logical Flow

**Rating: Very good. The backbone is sound.**

The article follows a classic structure: problem, solution, evidence, try-it, closing thesis. The progression is:

```
Hook (principle) → Problem (structural) → What I built (overview) → Authority model (deep dive)
→ Practice (before/after) → Context Fabric → Component Fabric → Healing loop → Audit
→ Evidence → Status/honesty → Try it → Closing thesis
```

This is logical. Each section builds on the previous. The "What I built" section correctly introduces the core mechanism (task gate) before expanding into subsystems.

**One structural issue:** The "How it works in practice" section (before/after bash examples) comes AFTER "The authority model." A reader who is still unsure what the tool does concretely will have sat through the authority model table without a practical anchor. Consider swapping these: show the before/after first (concrete), then explain the authority model (abstract). Concrete-then-abstract is typically stronger for developer audiences.

---

## 3. Section Ordering — Recommended Resequencing

Current order and suggested reorder:

| # | Current | Suggested | Rationale |
|---|---------|-----------|-----------|
| 1 | Hook | Hook | Keep |
| 2 | The problem is structural | The problem is structural | Keep |
| 3 | What I built | What I built | Keep |
| 4 | The authority model | **How it works in practice** | Concrete example first |
| 5 | How it works in practice | **The authority model** | Abstract model after concrete grounding |
| 6 | Context Fabric | Context Fabric | Keep |
| 7 | Component Fabric | Component Fabric | Keep |
| 8 | The healing loop | The healing loop | Keep |
| 9 | Continuous audit | Continuous audit | Keep |
| 10 | Evidence | Evidence | Keep |
| 11 | Where it stands | Where it stands | Keep |
| 12 | Try it | Try it | Keep |
| 13 | The principle holds | The principle holds | Keep |

Only sections 4 and 5 benefit from swapping. Everything else flows well.

---

## 4. Pacing

**Overall: Well-paced. Two sections slightly out of balance.**

- **"The problem is structural"** — Excellent pacing. Four bold-lead pain points, each with a concrete consequence. This is the strongest section for reader identification. Length is right.

- **"What I built"** — Good. The ASCII flow diagram is effective. The five-requirements table is the article's structural backbone — it ties the opening thesis to the product. However, the table is dense. Consider whether the reader needs all five rows explained in full, or whether a shorter version with a "see the README for details" link would keep momentum.

- **"The authority model"** — Slightly long for its position. The three-line authority diagram is excellent and memorable. The tier table beneath it is informative but feels like documentation rather than narrative. A dev.to reader may skim it. Consider trimming the tier table to just Tier 0 and Tier 1 (the interesting ones) with a note that additional tiers exist.

- **"How it works in practice"** — Excellent pacing. The before/after code blocks are the article's most scannable and persuasive element. This section should appear earlier (see section ordering above).

- **"Context Fabric" and "Component Fabric"** — These are back-to-back deep dives into subsystems. Each is individually well-written, but together they form a wall of technical detail. A reader who is interested but not yet committed may fatigue here. Consider whether one could be shortened to a teaser with a link, or whether a transition sentence between them could frame the shift ("Context Fabric handles memory across time. Component Fabric handles awareness across space — the codebase topology.").

- **"The healing loop"** — Good length. The escalation ladder (A/B/C/D) is a strong conceptual element but is presented quickly. It might land better with one concrete example: "An agent hit an API timeout (A). The pattern was recorded. Next session, it used retry logic automatically (B). We then added retry to the HTTP wrapper (C)."

- **"Continuous audit"** — Very short. Almost vestigial. It introduces a concept (90+ checks, continuous) without enough context for a reader to understand why it matters. Either expand slightly (one sentence on what kinds of checks, one on what a failure triggers) or fold it into another section.

- **"Evidence"** — Strong and well-placed. The commit log is persuasive. "The framework is its own proof of concept" is an excellent line.

- **"Where it stands"** — This honesty section is very effective for dev.to. The tone is right: confident but not overselling. Keep as-is.

---

## 5. Call to Action

**Rating: Functional but could be warmer.**

The "Try it" section gives two install paths and a quick-start sequence. This is mechanically correct. What it lacks is motivation bridging — the section jumps from "Where it stands" (honest caveats) directly into install commands. A one-sentence bridge would help: "If you want to see what governed agent development feels like, the quickest path is:" or similar.

The Apache 2.0 line and GitHub link are good. Having them immediately after the install commands is the right placement.

---

## 6. Opening-Closing Symmetry

**Rating: Excellent.**

The closing section ("The principle holds") directly restates the opening thesis with the same five-requirements framing. "The domain changed. The principle did not." is a strong closing line that mirrors the title's "same governance principle, new domain." This creates a satisfying frame.

The italicized discussion invitation is a good coda — low-pressure, community-oriented.

---

## 7. Reader Fatigue — Where Readers Might Drop Off

Three risk points, in order of likelihood:

1. **After the opening paragraphs (before "The problem is structural").** The career context is dense. Readers who came for "AI coding agent tool" may not get past the Shell background. Mitigation: tighten paragraph 2 or move it later.

2. **Between "Component Fabric" and "The healing loop" (lines 151-176).** By this point the reader has consumed two consecutive technical deep dives (Context Fabric, Component Fabric) with code blocks and screenshots. The healing loop is a third consecutive feature section. This is the article's weakest stretch for retention. Mitigation: add a transition, shorten one of the Fabric sections, or move the Evidence section up to break the pattern.

3. **"Continuous audit" section.** It is too short to be satisfying and too long to be a throwaway. A reader in scanning mode may perceive it as filler. Mitigation: either expand with one concrete example or merge into "Evidence" as a supporting data point.

---

## 8. Missing Transitions

- **Between "What I built" and "The authority model"**: The table in "What I built" covers all five requirements including the authority model. Then the next section dives into the authority model specifically. A transition sentence is needed: "The authority model deserves its own explanation because it addresses the most dangerous failure mode."

- **Between "Context Fabric" and "Component Fabric"**: No transition. These are two different subsystems solving different problems (temporal memory vs. spatial awareness). A bridging sentence would help: "Context Fabric gives the agent memory across time. Component Fabric gives it awareness across the codebase structure."

- **Between "Evidence" and "Where it stands"**: The Evidence section ends on a high note ("the framework is its own proof of concept"). The next section immediately introduces caveats. A transition like "That said..." or "Despite this track record..." would smooth the shift in tone.

---

## 9. Additional Observations

**Screenshots:** Four screenshots are well-distributed. They break up text walls and give visual proof. Good placement — they appear after the feature they illustrate, not before.

**Code blocks:** The bash code examples are the article's most effective persuasion tool. The before/after in "How it works in practice" and the `fw fabric` commands in "Component Fabric" are particularly strong. Consider whether the `fw recall` command in "Context Fabric" needs the comment line — it adds length without much clarity.

**Title:** "I built guardrails for AI coding agents — same governance principle, new domain" is good for dev.to. It is specific, first-person, and contains both the tool category and the differentiator. Length is at the upper bound for scanning — consider whether "same governance principle, new domain" could be shortened to "same principles from enterprise IT" or similar.

**Word count estimate:** ~1,800 words. This is within the sweet spot for dev.to (1,500-2,500). No need to add or cut significantly.

---

## Summary of Recommendations (Priority Order)

1. **Swap sections 4 and 5** — show "How it works in practice" before "The authority model"
2. **Tighten the opening** — get to AI agents faster, move Shell detail down or compress
3. **Add transition sentences** between the three identified gaps
4. **Add a one-sentence bridge** before the "Try it" install commands
5. **Expand or merge "Continuous audit"** — it is too thin to stand alone
6. **Add a bridging sentence** between the two Fabric sections to prevent fatigue
7. **Consider trimming the tier table** to Tier 0 and Tier 1 only
