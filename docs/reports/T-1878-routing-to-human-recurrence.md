# T-1878 — Why agents route to human review when reviewer/agent could close

**Status:** inception, in-progress
**Created:** 2026-05-17
**Anchor:** T-1687 (arc-grooming)
**Pattern recurrence:** 3rd time

## Problem Statement (one sentence)

Agents reliably file Human ACs with `[REVIEW]` prefix when the AC's actual content is reviewer-static-scannable or behaviorally-verified-by-Agent-AC, causing the review queue to silt up with 27/33 false-positive human gates (per today's classification).

## Why We're Incepting

This is the **3rd remediation** of the same surface:

| When | What shipped | Why it failed |
|---|---|---|
| T-954 (older) | AC Classification matrix (Human vs Agent rubric in CLAUDE.md) | Vocabulary only. No structural enforcement at AC-file time. |
| T-1811 (2026-05-15) | `[REVIEWER]` third prefix + conversion rule | Vocabulary only. Existing `[REVIEW]` ACs not re-prefixed. New `[REVIEW]` ACs still default. |
| Today (2026-05-17) | Classification of 33 in-flight tasks | Manual one-shot triage. Doesn't change the rate of future filings. |

The pattern is recurring → structural fix, not another vocabulary slice. Per G-019 Post-Fix Root Cause Escalation: "If you can't explain what structural change prevents recurrence, the gap is not closed."

## Spike Plan (3 parallel investigations, max one inception)

1. **Data spike:** how often is `fw reviewer` actually run on tasks? What's the ratio of Human ACs filed to reviewer-passes-without-human?
2. **Trigger spike:** at what point in the task lifecycle does the routing decision get made? File-time vs close-time vs review-time?
3. **Enforcement spike:** what's the smallest structural change that flips the default from "Human AC unless proven Agent-verifiable" to "Agent AC unless proven Human-judgment-required"?

## Findings

### Data — reviewer agent usage (gathered 2026-05-17)

**Reviewer agent footprint:**
- `## Reviewer Verdict` block written into **412 / 1846 tasks** (22%).
- 13 daily Pass-B audit YAMLs at `.context/audits/reviewer/` (since 2026-04-25 — ~22 days of cron, with gaps).
- Cron entry `reviewer-audit-daily` (T-1447) runs `fw reviewer audit` at 04:37 nightly — automated post-hoc only.
- Reviewer dispatched via TermLink: **0 of 346 dispatches**. The reviewer is in-process, single-purpose; TermLink dispatch isn't its substrate.

**AC prefix population (all 1846 tasks):**

| Prefix | Count | Comment |
|---|---|---|
| `[REVIEW]` | **415** | Default. |
| `[RUBBER-STAMP]` | 81 | Older vocabulary, fair uptake. |
| `[REVIEWER]` | **1** | The one task using it is T-1811 — the task that *invented* the vocabulary. **Vocabulary has zero downstream adoption.** |

Ratio `[REVIEW]` to `[REVIEWER]` = **415:1**. T-1811 shipped 2 days ago — but no new tasks have used the new prefix because the template never mentions it.

**Tasks with Human AC section at all:** 966 / 1846 (52%).

### Trigger — at which point is the routing decision made?

The decision is **frozen at file-time**, never revisited until human review:

```
file-time  (task-create)              close-time  (--status work-completed)              review-time  (human, days later)
─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
agent picks prefix from template   →  AC checkbox gate (P-010, P-011) only sees   →  human eventually reviews
                                      [ ] vs [x]; doesn't reclassify              ← reviewer cron Pass-B re-scans, but
                                                                                    findings written to task body only,
                                                                                    NOT routed back to AC choice
```

Findings at each gate:

1. **Task template** (`.tasks/templates/default.md`) lists `[RUBBER-STAMP]` and `[REVIEW]` as examples. **`[REVIEWER]` is not mentioned.** Agents copy what they see.
2. **`update-task.sh`** does NOT call `fw reviewer` at any status transition. The completion gate fires on raw `[ ]` checkbox counts and `## Verification` shell commands — neither consults the reviewer.
3. **`lib/inception.sh do_inception_decide`** does NOT call `fw reviewer` either. The gate routes the decision to the human via Watchtower but never asks the reviewer if the human is actually needed.
4. **`web/blueprints/review.py:165`** DOES extract the reviewer verdict — the human sees it on `/review/T-XXX` — but only as a display field, not as a redirect. The reviewer's verdict is presented for context; it doesn't change the routing.

### Enforcement — minimum structural changes (ranked by leverage / risk)

**Tier 1 (smallest, highest leverage):**

1. **Update `.tasks/templates/default.md` Human-AC block** to include all three prefixes with examples:
   - `[RUBBER-STAMP]` example — mechanical step, deterministic shell verification → "convert to Agent AC + ## Verification"
   - `[REVIEWER]` example — pattern / wording / message conformance → "convert to Agent AC + `bin/fw reviewer T-XXX ... | grep -q "Overall:.*PASS"` in ## Verification"
   - `[REVIEW]` example — genuine human judgment (tone, UX feel, strategic)
   - Plus the **conversion test** from CLAUDE.md: "Could a deterministic static scan answer the AC's yes/no? If yes → [REVIEWER]."
   - **Why:** every future task is born with the right vocabulary surface. One-line change to template.
   - **Risk:** zero. Pure documentation.

2. **Pre-completion reviewer check in `update-task.sh`**:
   - When `--status work-completed` is invoked and the task has `[REVIEW]`-prefixed Human ACs remaining, run `fw reviewer T-XXX`. If verdict = PASS + needs_human=no, emit a hint: "Reviewer says no human needed for these ACs. Consider re-prefixing to [REVIEWER] and adding the reviewer command to ## Verification, then re-run."
   - Non-blocking — pure suggestion at the natural inflection point.
   - **Why:** the decision gets a second look before locking in.
   - **Risk:** noise if reviewer is wrong. Mitigated by non-blocking + human-readable.

**Tier 2 (larger, real enforcement):**

3. **AC-creation linter as PreToolUse hook**: when Write/Edit creates or modifies a Human AC line containing `[REVIEW]`, scan the AC text for reviewer-handleable patterns ("block message", "actionable", "wording", "WARN clarity", "error message", "refusal message") and emit a "Did you mean [REVIEWER]?" warning. Non-blocking advisory.
   - **Why:** catches the drift at file-time, the original source.
   - **Risk:** false positives. Need to keep the pattern list narrow.

4. **Auto-conversion sweep** as a separate one-shot slice: scan all 415 `[REVIEW]` ACs, run `fw reviewer T-XXX` on each, propose re-prefixes for the PASS + needs_human=no cohort. Output a single human-reviewable patch.
   - **Why:** clears the existing backlog.
   - **Risk:** lossy if the reviewer is wrong on a given AC. Human reviews the patch, not each task.

**Tier 3 (architectural — defer):**

5. **Default flip: write Agent ACs by default; require explicit `[REVIEW]` + rationale for Human ACs.** Inverse of current schema. The template would default to "Agent ACs cover this, no Human section unless one of these criteria fires:".
   - **Why:** moves the burden of proof. Today, [REVIEW] is the no-justification path. Tomorrow, [REVIEW] would require naming the matrix criterion (#1 strategic, #2 subjective, #3 irreversible, #4 cross-project, #5 render-surface).
   - **Risk:** churn. All existing tasks would need re-classification. Bigger inception (own arc).

## Two-axis classification model (proposed)

The current `[REVIEWER]`/`[REVIEW]`/`[RUBBER-STAMP]` taxonomy mixes two orthogonal axes:

| | Verifiable now? | Notes |
|---|---|---|
| **Static-scan** | YES → `[REVIEWER]` | `fw reviewer` patterns: block-message, AC-verify-mismatch, mock-only-integration, naming, anti-pattern detection |
| **Shell-command** | YES → `[RUBBER-STAMP]` | `## Verification` block, bats, curl, grep |
| **Playwright/Visual-DOM** | YES (mostly) | T-1575: DOM-content assertions for element-presence; Playwright for click-flow |
| **Visual-rhythm / aesthetics** | NO | Until visual-regression CI exists, genuinely `[REVIEW]` |
| **Tone / cohesion** | NO | Tone is judgment; reviewer can't grade it |
| **Strategic authority** | NO | Go/no-go, breaking changes, irreversible action |
| **Cross-repo / blast-radius** | NO | Multiple stakeholders, multiple repos |

Today's drift: agents file ANY of the bottom-4 reasons AND ANY of the top-3 reasons under the same `[REVIEW]` prefix. The vocabulary collapses two axes into one. Structural fix should keep them separate.

## Dialogue Log

### 2026-05-17 07:20Z — Inception trigger

- **Human:** "ok now lets incept how come we make this decsion to route to human operator stea dof revioewing by agent and how we structurally can imnkporving this mrouting decison, mind you that we have done this now for the 3rd time we evan have specialized termlink review agnets, checdk how often these are use"
- **Agent assessment:** Three signals in the prompt:
  1. "3rd time" → systemic recurrence, not isolated. Maps to error escalation Level D (change ways of working).
  2. "specialized termlink review agents" → user is pointing at existing infrastructure (the reviewer agent + termlink dispatch wrapper) and asking why it's not load-bearing.
  3. "check how often these are use" → data first, hypothesis after.

## Recommendation

(filled at end of inception with GO/NO-GO/DEFER + rationale)

## Decision

(filled via `fw inception decide T-1878` after dialogue)
