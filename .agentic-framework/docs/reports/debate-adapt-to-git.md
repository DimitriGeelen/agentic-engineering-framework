---
title: "Debate Position: Adapt Episodic Generation to Git as Source of Truth"
date: 2026-02-17
type: architectural-debate
position: FOR adaptation
trigger: "109-task audit found 58% empty task files, 97% git traceability, 16% episodic inaccuracy"
---

# The Case for Git as the Source of Truth for Episodic Memory

## Thesis

The data from 109 completed tasks proves that git commits are the naturally authoritative record of work, and the framework should adapt its episodic generator to mine git rather than fight the persistent, structural failure of task-file logging. Aligning tooling with observed agent behavior -- rather than demanding behavioral change the system has failed to produce across 109 opportunities -- is the antifragile response.

## Argument 1: The 58% is Not a Discipline Problem -- It Is an Equilibrium

Sixty-three of 109 task files contain only "created" and "completed" entries. This is not a bug that appeared recently and could be fixed with a reminder. It has persisted from T-003 through T-115, across dozens of sessions, multiple context compactions, and repeated audits. The framework itself has audited this gap (T-072), documented it, and still the rate has not moved. When a system produces the same outcome 58% of the time over 100+ iterations, that is not a failure of discipline -- it is the system telling you where information naturally flows. Information flows into git commits because commits are the atomic unit of work. The Write tool call to update a task file is a secondary, reflective act that competes with the agent's primary drive: producing the next code change before context runs out.

## Argument 2: Git Commits Are Superior Records

Consider the properties of each source:

| Property | Git Commits | Task File Updates |
|----------|-------------|-------------------|
| Immutable | Yes (SHA-addressed) | No (rewritable) |
| Timestamped | Exact, automatic | Agent-reported, often approximate |
| Linked to code | By definition | Detached narrative |
| Conflict resolution | Impossible to conflict with itself | Can conflict with commit record |
| Survives context compaction | Yes (on disk) | Only if written before compaction |

The audit-episodic-accuracy report found 17 episodics with commit count discrepancies of 2 or more -- including T-012, which claimed 38 commits when the actual count was 60. These inaccuracies arise because the episodic generator trusts the task file, which is incomplete. Git log for a task ID is a single command: `git log --oneline --grep="T-XXX"` with word-boundary matching. It cannot be wrong about which commits exist.

## Argument 3: DRY and Context Cost

Every task-file update costs a Write tool call. In a 200K-token context window where the framework already warns at 100K and forces emergency handover at 150K, each unnecessary Write is a non-trivial deduction from the session's productive capacity. The framework's own P-009 practice (Context Budget Management) explicitly identifies this tension. Requiring the same information in both a commit message and a task file Updates section is a DRY violation with a concrete cost: context tokens. When the two records conflict -- and they do, in 16% of cases -- which one do we trust? We trust git. So why maintain the lossy copy?

## Argument 4: What Git-Mined Episodics Would Look Like

A `generate-episodic` command that mines git could automatically extract:

- **Commit count and timeline**: `git log --oneline --grep="T-XXX" --format="%H %aI %s"` gives exact count, first/last dates, and duration
- **Files changed**: `git log --grep="T-XXX" --name-only` gives the complete artifact list
- **Lines added/removed**: `git log --grep="T-XXX" --stat` gives diffstat
- **Narrative arc**: Commit message subjects, ordered chronologically, tell the story of the task
- **Challenges**: Commits with "fix", "revert", "debug" in their subjects signal difficulties
- **Multi-session detection**: Date gaps between commits reveal session boundaries

What remains un-minable: decisions with rejected alternatives, dead-end explorations that were never committed, and high-level rationale. But the critical question is: are these actually captured in task files today?

## Argument 5: The Counter-Argument Has No Evidence Base

The strongest case for enforcing task logging is that it captures what git cannot: design rationale, rejected alternatives, dead ends, and decisions. This is true in principle. But the data says it is false in practice. Of the 63 thin tasks, many had substantive commit histories (T-059 had 9 commits, T-108 had 6, T-030 had 3) -- meaning real work happened but the agents chose not to log it in the task file. The T-108 premature-closure analysis is the clearest example: 6 commits over 173 minutes, 5 governance violations, and the task file had exactly 2 Updates entries. The information that *should* have been in the task file was instead recoverable from git commit messages, timestamps, and diffs. A system that works in theory but fails 58% of the time in practice is not a system worth enforcing.

## Steelman: The Case for Enforcing Task Logging

The strongest counter-argument has three parts:

1. **Git cannot capture "why not"**: Rejected alternatives, dead-end explorations, and design rationale are genuinely valuable for future agents. A commit that says "T-092: Fix Tier 0 false positives on quoted string contents" tells you what was done, but not that the team also considered "block all rm -rf" and rejected it for false-positive reasons.

2. **The 42% that DO log are richer**: Tasks like T-059 and T-092 have rich episodics with decisions, alternatives_rejected, and challenge/resolution pairs. These entries demonstrably improve future decision-making (T-097's deep reflection mined episodic memory as evidence).

3. **Automation breeds complacency**: If you remove the expectation of task logging, agents lose even the aspirational goal. The 42% might drop to 0%.

## Why Adaptation Wins Despite the Counter-Arguments

These counter-arguments are valid but do not change the calculus, for three reasons:

First, the "why not" information can be captured in commit messages. The framework already enforces `T-XXX:` prefixed commit messages. Extending the convention to include decision rationale in commit body text (multi-line commits) would capture this information in the immutable record without an extra Write call.

Second, the 42% that log well are overwhelmingly enrichment-pass tasks -- tasks where an agent was specifically dispatched to write up the episodic after the fact. This is not organic in-flight logging; it is a post-hoc documentation pass. Git mining could replace the need for that enrichment pass entirely by extracting the same information automatically.

Third, the complacency argument assumes that task-file logging is the only path to rich episodics. If the episodic generator produces high-quality summaries from git data automatically, the framework gets *better* episodics with *zero* agent effort. That is not complacency -- that is automation replacing a manual process that has a 58% failure rate.

## Recommendation

Adapt the episodic generator to mine git as its primary data source. Treat task-file Updates as supplementary enrichment (nice to have, not required). Invest the saved context budget in the work itself. This aligns the framework with its own Directive 1 (Antifragility: adapt to observed behavior) and Directive 3 (Usability: eliminate friction that produces no value).
