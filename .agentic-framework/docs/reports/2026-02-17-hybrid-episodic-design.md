---
title: "Design: Hybrid Task-File + Git-Mined Episodic System"
date: 2026-02-17
task: T-117
type: design
status: ready-for-experiment
---

# Design: Hybrid Task-File + Git-Mined Episodic System

## Problem Statement

58% of completed task files have <=2 Updates entries (just "created" + "completed").
97% of git commits have task references with descriptive messages. The episodic generator
currently parses the Updates section as its primary narrative source, producing skeletons
with [TODO] placeholders that require manual enrichment. This is backwards — the rich
data is in git, the empty shell is in the task file.

## Design Principles

1. **Git owns what happened** — timeline, metrics, file changes, commit messages
2. **Task file owns why** — acceptance criteria, decisions with rationale, rejected alternatives
3. **Episodic merges both** — automatically, no manual enrichment for the mechanical parts
4. **Context budget respect** — minimize Write calls during execution

## Changes

### 1. New Task Template (default.md)

**Before:**
```markdown
## Context
[Link to design docs...]

## Updates
[Chronological log — every action, every output, every decision]
```

**After:**
```markdown
## Context
<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria
- [ ] [First criterion]
- [ ] [Second criterion]

## Decisions
<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices. -->

## Updates
<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
```

Key changes:
- **Acceptance Criteria** section is now in the template (supports T-113 gate)
- **Decisions** section replaces the implicit "log everything" expectation
- **Updates** section demoted — marked as auto-populated, manual entries optional
- Context section simplified

### 2. Decision Entry Format

When an agent makes a decision worth recording, one Write call:

```markdown
### [date] — [topic]
- **Chose:** [what was decided]
- **Why:** [rationale]
- **Rejected:** [alternatives and why not]
```

Estimated cost: ~100 tokens per decision. Most tasks have 0-2 real decisions.
Total context cost: 0-200 tokens (vs aspiration of logging every action at 500+ tokens).

### 3. Enhanced Episodic Generator (episodic.sh)

Current flow:
```
Task file → parse Updates → extract challenges/outcomes → skeleton + [TODO]
Git → commit count, lines, files (metrics only)
```

New flow:
```
Git → commits, messages, diffs, timestamps → timeline + metrics + narrative
Task file → AC checkboxes, Decisions section → outcomes + decisions
Merge → complete episodic (no [TODO] for mechanical sections)
```

#### Git mining additions:

```bash
# Extract commit messages as timeline
git log --grep="^${task_id}:" --format="%ai %s" --reverse

# Extract files changed per commit (for artifacts section)
git log --grep="^${task_id}:" --name-only --format="" | sort -u

# First and last commit timestamps (more accurate than frontmatter)
git log --grep="^${task_id}:" --format="%ai" --reverse | head -1  # first
git log --grep="^${task_id}:" --format="%ai" | head -1            # last

# Detect challenges: commits with "fix", "revert", "bug" in message
git log --grep="^${task_id}:" --format="%s" | grep -iE "fix|revert|bug|issue"
```

#### Auto-generated sections (no [TODO]):

| Section | Source | Manual? |
|---------|--------|---------|
| summary | Git commit messages (concatenated, deduplicated) | No — auto |
| outcomes | AC checkboxes [x] from task file | No — auto |
| timeline | Git commit timestamps + messages | No — auto |
| challenges | Git messages with fix/revert/bug keywords | No — auto |
| decisions | Decisions section from task file | Semi — agent writes if meaningful |
| artifacts | Git --name-only across task commits | No — auto |
| metrics | Git numstat (already implemented) | No — auto |

#### Sections that still need enrichment:

| Section | Why |
|---------|-----|
| successes.why | Requires judgment ("why did this work?") |
| decisions (if empty) | Some tasks genuinely have no decisions |

### 4. Enrichment Status Logic

```
If Decisions section is non-empty AND AC section has [x] items:
    enrichment_status: complete
Elif AC section has [x] items but no Decisions:
    enrichment_status: auto-complete  (mechanical task, no decisions to record)
Else:
    enrichment_status: pending  (needs human/LLM review)
```

This means most simple build/fix tasks auto-complete. Only design/inception tasks
with real decisions need enrichment.

### 5. Template Enforcement

- T-113 (acceptance criteria gate): `update-task.sh` checks AC checkboxes before `work-completed`
- Decisions section: **not enforced** — optional by design. Some tasks have no decisions.
- Updates section: **not enforced** — auto-populated at completion by git mining

## Experiment Plan (Next Session)

### Phase 1: Template Change (15 min)
1. Update `.tasks/templates/default.md` with new structure
2. Update `.tasks/templates/inception.md` similarly
3. Update CLAUDE.md task file documentation

### Phase 2: Episodic Generator Enhancement (45 min)
1. Add git-mining functions to `agents/context/lib/episodic.sh`:
   - `mine_git_timeline()` — commit messages as timeline
   - `mine_git_challenges()` — fix/revert/bug detection
   - `mine_git_artifacts()` — files changed
   - `mine_git_summary()` — deduplicated commit message concatenation
2. Modify `do_generate_episodic()` to use git data for summary/challenges/artifacts
3. Add auto-complete logic for enrichment_status
4. Remove [TODO] placeholders for git-derivable sections

### Phase 3: Validation (30 min)
1. Regenerate episodic for T-115 (small task, 1 commit) — verify auto-complete
2. Regenerate episodic for T-112 (medium task, 2 commits, has decisions) — verify merge
3. Regenerate episodic for T-108 (problematic task, 6 commits) — verify accuracy
4. Compare old vs new episodics side-by-side
5. Run `fw audit` to verify no regressions

### Phase 4: Retrospective (15 min)
1. Did git-mined episodics capture enough context for handover?
2. Were any [TODO]s still needed?
3. Context cost comparison: old manual enrichment vs new auto-generation
4. Go/no-go: roll out to all new tasks or iterate?

### Success Criteria
- [ ] T-115 episodic auto-completes with no [TODO] (mechanical task)
- [ ] T-112 episodic auto-fills timeline/metrics, only needs decisions review
- [ ] T-108 episodic accurately shows 6 commits, 173 minutes (not 2/69)
- [ ] No regressions in `fw audit`
- [ ] Context cost of episodic generation < 500 tokens (currently requires ~2000 for manual enrichment)

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Git commit messages too terse for summary | Medium | Low | Falls back to [TODO] for summary |
| AC section empty (old tasks) | High | Low | Auto-complete for tasks without AC |
| Decisions section always empty | Medium | Medium | Track adoption rate, reassess after 20 tasks |
| Breaking existing episodic format | Low | High | Don't touch existing episodics, only new ones |

## Non-Goals (This Iteration)

- Retroactively fixing existing 109 episodics (separate task if needed)
- Enforcing Decisions section (optional by design)
- Changing commit message format (already good at 97%)
- Real-time episodic updates during task execution (overkill)

## References

- T-116 audit reports: docs/reports/audit-{post-closure-commits,thin-task-files,episodic-accuracy}.md
- Debate docs: docs/reports/debate-{enforce-task-logging,adapt-to-git,hybrid-synthesis}.md
- Current episodic generator: agents/context/lib/episodic.sh
- T-112 forensic analysis: docs/reports/2026-02-17-premature-task-closure-analysis.md
