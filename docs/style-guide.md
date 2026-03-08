# Writing Style Guide — Dimitri Geelen

> **Purpose:** Reference for any agent producing content (articles, posts, documentation).
> Load this file before writing. Apply as creative constraint, not template.

## Voice Summary

Philosophical-pragmatic. Opens with universal principle, grounds in 25 years of enterprise governance experience, then applies to the specific domain. Quiet authority through specificity, not assertion. Writes for peer leaders, not beginners.

## Voice Characteristics

### 1. Principle-first opening
Open with a universal observation that works regardless of domain. The AI/software angle arrives as one instance of a general pattern, not the hook.

**Yes:** "Effective intelligent action — whether by a person, a team, or an AI agent — requires five things."
**No:** "I've been using Claude Code for months and kept running into problems."

### 2. Cross-domain bridge
Map enterprise governance concepts to software without translating into dev jargon. Use "assurance areas," "quality gates," "transitions" — not their dev equivalents. The reader learns the author's vocabulary.

**Yes:** "In transition management, the single most common failure mode is unclear accountability."
**No:** "In CI/CD pipelines, the biggest issue is lack of access control."

### 3. Quiet authority
No self-promotion, no superlatives, no "revolutionary" or "game-changing." Credibility comes from specificity: "1,000 transitions worldwide," "312 tasks completed," "96% commit traceability." Numbers do the work that adjectives would do in lesser writing.

**Yes:** "The governance model holds."
**No:** "This amazing framework completely transforms how you work."

### 4. Declarative tone
Short sentences. Subject-verb-object. Avoids hedging ("I think," "arguably," "it could be said"). States positions as facts, qualified only by evidence.

**Yes:** "The agent may choose which task to work on. It may not bypass a structural gate."
**No:** "I think the agent should probably be able to choose tasks, but arguably shouldn't bypass gates."

### 5. Structural parallelism
Repeat syntactic patterns across related ideas. The reader absorbs structure before content.

**Yes:** "No traceability. No memory. No risk awareness. No learning loop."
**No:** "There's a lack of traceability, memory is missing, risk awareness doesn't exist, and learning loops are absent."

### 6. Pulled quotes as anchors
Standalone bold phrases that crystallize the insight. Could be pinned to a wall. Domain-neutral.

**Examples:**
- **"Initiative is not authority."**
- **"The domain changed. The principle did not."**
- **"Structural enforcement doesn't degrade."**

### 7. Bookending
Open and close with the same thesis, evolved. The conclusion is the opening thesis proven by everything between.

**Yes:** Open: "The five requirements for effective intelligent action." Close: "The domain changed. The principle did not."
**No:** Close: "I hope you found this useful. Let me know in the comments!"

### 8. First-person singular, limited
Use "I" sparingly, only for claims of direct experience. "I built," "I derived," "I recognised." Never "I believe" or "I feel." The "I" is an actor, not an opiner.

### 9. Implied reader: peer leader
Write for someone who manages complexity professionally. Do not explain what a commit is. Do not explain what governance means. Assume the reader has run a programme, led a team, or supervised agents.

### 10. Anti-hype register
Use "interesting" where others would use "exciting." Use "holds" where others would use "works amazingly." Understatement signals confidence.

## Anti-Patterns

- No "Let me show you..." or "In this article, we'll explore..."
- No bullet-point walls without framing paragraphs
- No "X is a powerful tool that Y" template sentences
- No "Whether you're a beginner or expert" audience hedging
- No calls-to-action disguised as enthusiasm ("You'll love this!")
- No markdown headers that are questions ("What is governance?")
- No emojis, no exclamation marks (except deliberate rare contrast)
- No "we" (royal or inclusive) — use "I" (personal) or "the framework" (institutional)
- No one-sentence dramatic paragraphs ("...Did you?")

## Translation Rules (developer-marketing to this voice)

### Rule 1: Open with principle, not incident
If the first paragraph is about you-the-developer and your agent, rewrite. The first paragraph should work if the reader has never used an AI coding agent.

### Rule 2: Replace second-person scenarios with third-person cross-domain parallels
**Before:** "You're busy. The agent asks a question. You reply..."
**After:** "A programme manager tells a workstream lead... A hospital administrator tells a department head..." Then the AI scenario arrives as the latest instance.

### Rule 3: Use pulled bold quotes as structural anchors
Each post needs 1-2 standalone bold sentences in domain-neutral language. If the bold text only makes sense in an AI context, generalize it.

### Rule 4: Write medium paragraphs with internal cadence
Delete one-sentence paragraphs. Weave important sentences into surrounding paragraphs. Rhetorical questions fold into longer sentences.

### Rule 5: Ground authority in experience, not assertion
If a paragraph opens with a statistic, move it later. Open with the observation or experience that led to the insight. "I arrived at," "I derived this from," "the teams that operated well were..."

## Platform Adjustments

| Platform | Length | Tone shift | Code blocks | CTA |
|----------|--------|-----------|------------|-----|
| Dev.to / Hashnode | 1200-1800 words | Full voice, all characteristics | Yes, moderate | Link to repo at end |
| LinkedIn | 200-400 words | Compressed, principle-first, no code | No | Link in comment, not body |
| Reddit (r/ClaudeAI) | 400-800 words | Slightly more casual close, include screenshots | Yes, brief | "Would love to hear how others handle this" |
| Documentation | Variable | Technical but framed, same authority register | Yes, extensive | N/A |

## Calibration Example

### Correct voice:
"In every domain I have worked in — IT programme governance, transition management, engineering leadership — the same failure mode appears when intelligent actors are given broad direction without clear constraints. A programme manager tells a workstream lead 'handle this however you think is best.' A hospital administrator tells a department head to 'sort it out.' In each case the intent is trust. The effect is the removal of structural accountability."

### Wrong voice (developer-marketing):
"You're busy. The agent is mid-task. It asks a question. You reply: 'Proceed as you see fit.' 45 minutes later you discover it force-pushed to main. ...Did you really give it permission?"
