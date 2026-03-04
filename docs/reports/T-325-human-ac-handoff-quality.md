# T-325: Research — Actionable Human AC Handoffs

## Problem Statement

Human acceptance criteria in the framework are written as outcome statements ("verify X works") rather than executable instructions. This causes:
- 50% completion rate on vague ACs vs 95% on specific ones (46 tasks analyzed)
- Tasks pile up in work-completed for 72h+ triggering D2 audit failures
- Humans lack context to act when they discover pending ACs days later

## Research Findings (4-Agent Investigation)

### Agent 1: Pattern Analysis (46 tasks with human ACs)

| Specificity | Example | Completion Rate |
|-------------|---------|-----------------|
| Specific | "Add SSH key to X", "< 2s load time" | 95% |
| Moderate | "Dashboard loads in browser" | 70% |
| Vague | "Output is clear", "Quality acceptable" | 50% |

**Worst offenders:** Subjective judgment words ("clear", "appropriate", "acceptable") without measurable rubrics.

**Best performers:** Commands to run, URLs to visit, measurable thresholds.

### Agent 2: Cross-Domain Handoff Patterns

Five properties of actionable handoffs (from CI/CD gates, runbooks, BDD):
1. **WHO** — specific assignee/role
2. **WHAT** — exact artifact to review
3. **WHY** — what requires human judgment (distinguish rubber-stamp from genuine review)
4. **HOW** — executable verification steps
5. **WHEN** — urgency/deadline

Key insight: "Commands, not paragraphs" — every system that succeeds at handoffs replaces prose with executable actions.

**Confidence signaling** (from Spinnaker manual gates): distinguish "rubber-stamp this" from "I genuinely need your judgment" — no current agentic tool does this well.

### Agent 3: Framework Enforcement Points

7 existing enforcement points, none validate human AC quality:

| Point | Current | Could Enforce |
|-------|---------|---------------|
| Task template | Has `### Human` section placeholder | Require `Steps:` block |
| P-010 (AC gate) | Checks boxes are checked | Validate AC text has commands/URLs |
| create-task.sh | Generates AC sections | Lint human ACs at creation |
| handover.sh | Lists tasks by status | Auto-generate human action brief |
| audit D2 | Flags >72h stale reviews | Check AC quality, not just age |
| CLAUDE.md | Rules for writing ACs | Add format requirements |
| update-task.sh | Moves to partial-complete | Reject vague human ACs |

### Agent 4: Notification/Discoverability Gaps

**What exists:** Watchtower cockpit "Awaiting Your Verification" amber section (works, shows unchecked human ACs).

**What's missing:**
- No CLI query (`fw task list --needs-human-verification`)
- No resume-time alert ("N tasks awaiting your review")
- No handover section for pending human actions
- No proactive notification (email, webhook, etc.)
- No session-start injection

**Journey today:** Agent marks work-completed → [silence] → human must proactively visit UI.

## Dialogue Log

### User observation (session start)
- User noticed OneDev-to-GitHub cascade broken, also noted human ACs on T-285/T-289 are not actionable
- Quote: "all human verifiable actions need specific instructions"
- User asked for deep reflection and mitigation suggestions

### Analysis presented
- Identified the two gaps: actionability + discoverability
- User approved sending 4 research agents

## Assumptions to Test

- A-1: Enforcing a `Steps:` block in human ACs will improve completion rates
- A-2: Surfacing pending human ACs at session start will reduce D2 staleness
- A-3: Confidence signaling (rubber-stamp vs genuine review) will help humans prioritize
- A-4: The existing Watchtower "Awaiting Verification" section is sufficient UI — CLI/handover gaps are the real problem
