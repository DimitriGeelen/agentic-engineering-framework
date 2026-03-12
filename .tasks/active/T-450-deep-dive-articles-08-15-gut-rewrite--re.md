---
id: T-450
name: "Deep-dive articles 08-15: gut rewrite — replace agent filler with real incidents"
description: >
  Gut and rewrite unpublished articles 08 (Watchtower), 09 (Context Fabric), 10 (Framework Core), 11 (Git Traceability), 12 (Learnings Pipeline), 13 (Audit), 14 (Handover), 15 (Enforcement). Problems: (1) formulaic openers — 'Governance begins with X' repeated 4 times, article 11 copies article 01 verbatim, (2) fabricated statistics — e.g. '68% of audit failures' (article 09), '47% increase in post-audit rework' (article 11), '93% reduction in handover conflicts' (article 14) — none traceable to actual data, (3) decorative code snippets that illustrate nothing, (4) 2023 timestamp in article 14 (framework didn't exist then), (5) articles 09/10 near-duplicate article 01 at lower quality. Fix: for each article, find the real incident that motivated building the subsystem. Use that as the opener. Kill every unverifiable percentage. Replace with honest language ('I stopped seeing X happen'). Match author voice from articles 01/04/07.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [content, deep-dives]
components: [docs/articles/deep-dives/08-watchtower.md, docs/articles/deep-dives/09-context-fabric.md, docs/articles/deep-dives/10-framework-core.md, docs/articles/deep-dives/11-git-traceability.md, docs/articles/deep-dives/12-learnings-pipeline.md, docs/articles/deep-dives/13-audit.md, docs/articles/deep-dives/14-handover.md, docs/articles/deep-dives/15-enforcement.md]
related_tasks: [T-449, T-338, T-446]
created: 2026-03-12T06:37:47Z
last_update: 2026-03-12T06:59:53Z
date_finished: null
---

# T-450: Deep-dive articles 08-15: gut rewrite — replace agent filler with real incidents

## Context

External review found articles 08-15 are agent-generated filler — formulaic openers, fabricated statistics, decorative code, near-duplicates. The skeletons (topic per subsystem) are fine but the substance must come from real incidents. Voice guide in `docs/reports/T-445-readme-overhaul.md`. Published articles 01/04/07 are the quality bar.

Related: T-449 (editing pass on 02-06), T-338 (content series), T-446 (README rewrite).

Additional voice/content source material:
- `docs/reports/T-450-termlink-honest-assessment.md` — real conversation showing authentic voice, honest self-doubt, skeptic steelmanning
- `docs/reports/T-445-readme-overhaul.md` — voice guide with DO/DON'T rules

### Specific problems found per article

| Article | Problem |
|---------|---------|
| 08 Watchtower | "Transparency begins with structured observation" opener; Python snippet is decorative; RAG mention in research section is noise |
| 09 Context Fabric | "Governance begins with a tapestry of context" opener; rehashes task gate (article 01) at lower quality; "68% of audit failures" is fabricated |
| 10 Framework Core | "Governance begins with structured documentation" opener; near-duplicate of 01 and 09 |
| 11 Git Traceability | Opens with VERBATIM copy of article 01 ("Accountability begins with a record of intent"); "32% lacked task linkage → 47% increase in rework" is fabricated |
| 12 Learnings Pipeline | "73% reduction in redundant task creation" is fabricated; two contradictory stats (73% and 41%) for the same metric |
| 13 Audit | 5 statistics in one article, none verifiable |
| 14 Handover | 2023 timestamp (`2023-11-05T14:30:00Z`) — framework didn't exist; "93% reduction in handover conflicts" is fabricated |
| 15 Enforcement | "73% of risky actions were blocked" and "89% of tasks would have proceeded without validation" — both fabricated |

### Real incidents from project history (use these as article openers/substance)

**Article 08 — Watchtower:**
- T-398: Dashboard health summary was built because CLI-only audit output couldn't show trends. The moment: running `fw audit` for the 50th time and realizing you could never answer "is the project getting better or worse?"
- T-404: Quality page crashed on malformed YAML — silent data loss that only became visible through the web UI

**Article 09 — Context Fabric:**
- L-062/T-232: A completed task ID left in focus.yaml silently bypassed ALL enforcement. The gate checked "is CURRENT_TASK non-empty?" — yes, but the task had moved to completed/. High-severity gap. Fix: gate now does `find .tasks/active/${CURRENT_TASK}-*.md`
- T-271: Budget-gate stale critical status trap — checkpoint.sh wrote "critical" to .budget-status but never cleared it. Next session started pre-blocked. Context state management failure.

**Article 10 — Framework Core:**
- T-360: 8-checkpoint onboarding test built because `fw init` left projects in broken states — hooks not installed, scaffolding incomplete, no way to tell what was missing
- T-348: `sed -i` broke on macOS (no backup suffix). Cross-platform portability failure in the core CLI.
- T-299: `fw doctor` hook validation parsed env var prefixes as commands, false-failing health checks

**Article 11 — Git Traceability:**
- T-024: **Enforcement Removal Test** — deliberately disabled commit-msg hook. Traceability dropped from 97% to 88% in 5 commits. Proved hooks are load-bearing, not decoration.
- Bypass log: 58 Tier 0 approvals logged (Mar 5-8) for `--no-verify` pushes. Every single one logged with human authorization, risk description, and command hash.
- D-005: Git agent absorbs bypass log — decision made because scattered enforcement was worse than no enforcement

**Article 12 — Learnings Pipeline:**
- L-020/T-064: 3-step task creation was more work than skipping. "When enforcement is being bypassed due to friction, reduce the compliant path to fewer steps than the non-compliant path." → built `fw work-on` (one command)
- L-057: `fw bus` (result ledger) built, documented, never used across 170+ tasks. Friction won. Evidence: both bus directories empty.
- 72% of bugfix tasks (31/43) produced zero learnings (G-016). T-030 portability fix and T-344 same class 23 days later — no learning connecting them.

**Article 13 — Audit:**
- D-011: Plugins act as second agent and caused task bypass. 4-agent investigation confirmed: 0/20 skills are task-aware, using-superpowers usurps framework authority, enforcement is git-commit-only.
- Cron audits: 10 jobs running every 15-30 min checking 7 sections. Real output in `.context/audits/cron/`
- T-206: Silent corruption in task files detected by audit, not by the agent doing the work

**Article 14 — Handover:**
- T-136: Auto-handover at critical threshold caused a runaway — 25 commits in 10 minutes. Added cooldown file with timestamp.
- L-050: 14 compactions in 13 minutes — budget gate cascade. Handover was the firebreak that preserved context.
- Bypass log line 1: Bootstrap exception (acb4594) — "task system did not exist prior to this commit." The handover system's first entry documents that even the framework needed a bootstrap bypass.

**Article 15 — Enforcement:**
- T-151: Agent completed a specification task in 2 minutes without consulting the human. This triggered the entire enforcement architecture.
- T-242: Agent attempted to use built-in EnterPlanMode, which bypasses ALL framework governance. PreToolUse hook now blocks it. G-014 closed.
- T-372/T-373: Agent suggested batch-closing 12 human-owned tasks without reviewing Human ACs. Led to D2 audit threshold redesign and the Human Task Completion Rule.
- L-060: Inception commit gate (2 commits then decide) collided with deep multi-session inceptions (T-191: 5-10 sessions). Forced 7 explicit `--no-verify` bypasses, all logged.

### Rewrite approach

For each article:
1. Open with the real incident from the list above — not a governance platitude
2. Kill every unverifiable percentage — replace with "I stopped seeing X" or "the failure mode disappeared"
3. Code snippets must illustrate something specific the reader can try
4. Match voice: cross-domain analogy from governance background, "the domain changed, the principle did not"
5. Reference real task IDs, real learnings, real bypass log entries

## Acceptance Criteria

### Human
- [ ] [REVIEW] No article opens with "Governance begins with X" or copies another article's opener
  **Steps:**
  1. Read first sentence of each article (08-15)
  2. Compare to articles 01, 04, 07 openers
  **Expected:** Each opener is unique and incident-driven
  **If not:** Note which articles still use formulaic openers

- [ ] [REVIEW] Zero fabricated statistics — every percentage traces to real data
  **Steps:**
  1. Search each article for percentages
  2. For each, check: does the cited task file contain this measurement?
  3. If no source, is it replaced with qualitative language?
  **Expected:** No invented precision remains
  **If not:** Flag specific stats and their claimed sources

- [ ] [REVIEW] Article 14 timestamp fixed (no 2023 dates)
  **Steps:**
  1. Search article 14 for timestamps
  **Expected:** All timestamps are 2026 or use clear placeholders
  **If not:** Fix the timestamp

- [ ] [REVIEW] Articles 09/10 no longer duplicate article 01
  **Steps:**
  1. Read articles 09 and 10
  2. Compare to article 01 — do they cover distinct ground?
  **Expected:** Each article has unique substance, not rehashed task gate
  **If not:** Identify the overlapping sections

- [ ] [REVIEW] Voice matches author across all 8 articles
  **Steps:**
  1. Read first and last paragraphs of each article
  2. Check against voice guide in `docs/reports/T-445-readme-overhaul.md`
  **Expected:** Reads like the author wrote it — no hype, specific evidence, dry self-awareness
  **If not:** Note which articles still sound agent-generated

## Verification

# All 8 article files exist and are non-empty
test -s docs/articles/deep-dives/08-watchtower.md
test -s docs/articles/deep-dives/09-context-fabric.md
test -s docs/articles/deep-dives/10-framework-core.md
test -s docs/articles/deep-dives/11-git-traceability.md
test -s docs/articles/deep-dives/12-learnings-pipeline.md
test -s docs/articles/deep-dives/13-audit.md
test -s docs/articles/deep-dives/14-handover.md
test -s docs/articles/deep-dives/15-enforcement.md
# No article opens with "Governance begins with"
! grep -l "^.*Governance begins with" docs/articles/deep-dives/{08,09,10,11,12,13,14,15}-*.md
# No 2023 timestamps remain
! grep -r "2023-" docs/articles/deep-dives/{08,09,10,11,12,13,14,15}-*.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-12T06:37:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-450-deep-dive-articles-08-15-gut-rewrite--re.md
- **Context:** Initial task creation

### 2026-03-12T06:59:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
