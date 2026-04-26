---
id: T-1507
name: "Inception decide CLI/Watchtower output truncates long rationale comments mid-sentence (T-1506 close: '...sett' cut from '/root/.claude/settings.json'). Affects readability of post-decision side-effect warning. Likely a fixed-width terminal/template buffer; check do_inception_decide post-print + Watchtower /inception/T-XXX rendering of rationale."
description: >
  Promoted from observation OBS-027

status: captured
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-04-26T11:35:02Z
last_update: 2026-04-26T11:35:10Z
date_finished: null
---

# T-1507: Inception decide CLI/Watchtower output truncates long rationale comments mid-sentence (T-1506 close: '...sett' cut from '/root/.claude/settings.json'). Affects readability of post-decision side-effect warning. Likely a fixed-width terminal/template buffer; check do_inception_decide post-print + Watchtower /inception/T-XXX rendering of rationale.

## Problem Statement

**Decision rationale gets truncated mid-sentence at the inception-decide boundary, destroying audit-trail value.**

Live evidence (T-1506 GO close, 2026-04-26T11:32:42Z): the user-visible "side-effect warning" emitted after `fw inception decide T-1506 go` cut off mid-token at `…/root/.claude/sett`, severing the second half of the file path that named the literal location of the duplicate hook bug being remediated. The full rationale (≈1.5KB across 4 numbered points + 3 alternatives) IS persisted to the task file (`.tasks/completed/T-1506-*.md` `## Decision` block — verified intact), but the operator-facing display layer truncates.

**Why this matters (governance):**
- The post-decision warning IS the moment the human verifies the decision was recorded correctly. If they only see the first ~200 chars, they miss the rationale they're attesting to.
- Decisions feed episodic memory + future review queries (`fw decisions`). If the truncation propagates into Watchtower `/inception/T-XXX` or `/decisions`, the audit trail in the readable surface diverges silently from the canonical task file.
- Same family as L-282 (silent data degradation) — output is technically "successful" but observably corrupted. No exception thrown, no warning surfaced.

## Assumptions

- **A1:** Truncation point is the CLI emit at `do_inception_decide` post-print (`lib/inception.sh`), not the underlying file write. Falsifiable by `wc -c` on the persisted `## Decision` block vs. visible CLI output.
- **A2:** Truncation is buffer-bounded, not terminal-width-bounded. (If width-bounded, the cut would land at a column boundary; if buffer-bounded, at a byte cap independent of terminal width.) Falsifiable by reproducing on `tput cols=200` and `tput cols=80` and checking whether the cutoff column moves.
- **A3:** Watchtower `/inception/T-XXX` and `/review/T-XXX` rendering of rationale ALSO truncates (same template bug, separate display surface). Falsifiable by loading T-1506 in browser and counting visible characters vs. file source.
- **A4:** Same bug affects `/decisions` index page rendering (where the "rationale_hint" column lives — see L-046 from T-1150 which already fixed an unrelated truncation in that field).
- **A5:** No structured logging path exists for emitted CLI output — only the on-screen render is the artifact, so a truncated render cannot be recovered from elsewhere except by re-reading the task file.

## Exploration Plan

1. **Confirm A1 + A2** (15 min) — close a synthetic inception with a deliberately long rationale (>4KB) at two terminal widths (80, 200) and capture: (a) byte length visible on stdout, (b) byte length in `## Decision` block on disk. Compare to find the cap.
2. **Confirm A3** (10 min) — `curl -s http://localhost:3000/inception/T-1506 | wc -c`, then grep for cutoff token; same for `/review/T-1506`.
3. **Localize the cap** (15 min) — grep `lib/inception.sh`, `lib/review.sh`, `web/templates/inception*.html`, `web/blueprints/*.py`, `agents/task-create/update-task.sh` for: hard-coded character limits, `:0:N` slicing, `cut -c`, `head -c`, `truncate`, CSS `text-overflow`, Jinja `truncate(`, sed `1,Np`. Tabulate sites.
4. **Spike fix variants** (no implementation):
   - **(a) Remove the cap entirely** — if it's a single offending `${var:0:N}` slice with no real reason, just delete it.
   - **(b) Smart truncate** — wrap-aware truncation that ends on a word/line boundary + appends `…(N more bytes — see <path>)` so the operator knows there IS more content and where to find it.
   - **(c) Emit summary + path** — short summary line for CLI ("Decision: GO — 4 rationale points, 3 alternatives — see <path> for full text"), full content reserved for the task file + Watchtower.
   - **(d) Fix display layer per surface** — CLI gets variant (b); Watchtower template gets `{{ rationale | safe }}` with no truncation + scrollable container.
5. **Cost/benefit table** + recommendation.

## Technical Constraints

- **Backwards compatibility:** existing decisions are stored verbatim in `## Decision` blocks. Any fix must preserve the full text on disk; only the display layer changes.
- **CLI width portability:** terminals range from 80 to 300+ cols (tmux, wide monitors, mobile SSH). Solution should not assume a fixed width.
- **Watchtower template language:** Jinja2 (per `web/templates/`), so any string-side truncation is a Jinja filter — make sure it's `safe`-aware to avoid breaking embedded markdown or code blocks.
- **Terminal escape sequences:** if rationale contains backticks or markdown, raw output may render oddly; preserve as plain text in CLI, render in Watchtower.

## Scope Fence

**IN scope:**
- Localize the truncation site(s) — CLI emit + Watchtower template + (if vulnerable) `/decisions` index.
- Recommend ONE fix variant with bounded build estimate.
- Cite all surfaces affected (audit trail completeness).

**OUT of scope:**
- Re-architecting how decisions are stored (they're already correct on disk).
- Adding structured logging of CLI output (separate concern: L-282 family).
- Generalizing to ALL fw CLI output truncation (e.g. `fw task list`, `fw decisions`) — mention as follow-up if A4 confirms wider blast radius.
- Fixing concurrent UI bugs unrelated to truncation.

## Related Context

- **OBS-027** (origin observation, this session)
- **T-1506** (the decision whose rationale got truncated; inception bug RCA — GO recorded, in `completed/`)
- **L-046** (T-1150 fix for `rationale_hint` truncation in `approvals.py` — likely related code path; check if regression OR a separate field with separate cap)
- **L-282** (T-1491 silent gate-failure pattern — same family: output is "successful" but observably corrupted)
- **G-019** (Antifragility — fix needs to surface failure visibly, not let silent corruption recur)

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-26T11:35:10Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Reason:** remediation inception per user directive
