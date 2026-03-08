# /write - Voice-Calibrated Content Production

Produce content drafts calibrated to the project's writing voice.
Use for articles, posts, documentation, and any public-facing prose.

## Prerequisites

1. Verify an active task exists (`cat .context/working/focus.yaml`)
2. Read the style guide: `docs/style-guide.md`
3. Read the active task file for deliverable specs and ACs

## Workflow

### Step 1: Load Voice

Read `docs/style-guide.md`. Internalize the voice characteristics and anti-patterns
as creative constraints for this session.

### Step 2: Understand the Deliverable

From the task file, extract:
- Target platform (dev.to, LinkedIn, Reddit, docs)
- Word count target (from ACs or description)
- Key messages or claims to include
- Output file path (from ACs)

If the task does not specify a platform, ask before drafting.

### Step 3: Draft

Write the content to the specified output path, applying:
- All 10 voice characteristics from the style guide
- The 5 translation rules (principle-first opening, cross-domain parallels, pulled quotes, medium paragraphs, experience-grounded authority)
- Platform-specific adjustments from the style guide table
- The task's acceptance criteria as structural requirements

### Step 4: Self-Check

Before presenting the draft, verify against these mechanical tests:

1. **First paragraph test:** Does it work if the reader has never used an AI coding agent?
2. **Pulled quote test:** Are there 1-2 standalone bold sentences in domain-neutral language?
3. **"You" test:** Is second-person scenario setup replaced with third-person cross-domain parallels?
4. **Paragraph test:** Are there any one-sentence paragraphs? (Delete or weave in.)
5. **Authority test:** Does any paragraph open with a statistic? (Move it later.)
6. **Anti-pattern scan:** No emojis, no exclamation marks, no "we," no rhetorical questions in isolation, no "Let me show you," no headers as questions.

Report to the user:
- File path and word count
- Which platform adjustments were applied
- Any ACs that could not be satisfied in draft
- Self-check results (pass/fail per test)

Ask: "Draft written to {path}. Ready for review, or adjustments needed?"

## Rules

- This skill produces ONE draft. It does not publish.
- The style guide is a constraint, not a template. Do not quote it in the output.
- Never add emojis unless the platform norms explicitly require them.
- The human always does final tone/voice review — this reduces the gap, not eliminates it.
- No skill chaining — do not invoke other skills from within this skill.
