# T-1616 — Handover scanner counts unchecked ACs inside HTML comment blocks — phantom

> **Inception research artifact** (backfilled by T-2515 from the `T-1616` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1616-handover-scanner-counts-unchecked-acs-in.md`. **Decision recorded: GO.**

## Problem Statement

`agents/handover/handover.sh` builds the "Awaiting Your Action (Human)" section of every handover. Line 685 captures the `### Human` body via:

```python
human_match = re.search(r'### Human\n(.*?)(?=\n### |\n## |\Z)', content, re.DOTALL)
```

then line 689 counts pseudo-ACs:

```python
unchecked = len(re.findall(r'^\s*-\s*\[ \]', human_section, re.M))
```

**Neither step strips `` comment blocks.** The default task template (`.tasks/templates/zzz-default.md`) places an Example AC *inside* an `` comment that contains literal `- [ ] [REVIEW] Dashboard renders correctly`. For any task whose `### Human` body still has only the template comment (T-1274 is the canonical witness), the scanner counts that example and surfaces the task in every handover. Nothing the human can do clears it — there is no real AC to tick.

Result: governance noise. Real human-blocked tasks get diluted by phantoms; signal-to-noise of the review queue degrades; humans learn to ignore the queue.

## Assumptions

| # | Assumption | Spike |
|---|------------|-------|
| 1 | The same defect exists in any other place that parses `### Human` ACs (audit, Watchtower review queue, `fw verify-acs`). | 2 |
| 2 | A 3-5 line fix to the regex (or a pre-strip of ``) closes the bug without functional regression. | 3 |
| 3 | A bats test covering the comment-block phantom case can be added to existing governance harness. | 3 |
| 4 | Stripping comments before counting will not break tasks that have BOTH a real AC and the example comment (real AC continues to count). | 3 |

## Exploration Plan

Three spikes (each <15min):

- **Spike 1 — confirm the bug + count blast radius.** DONE inline (this session). Confirmed: `agents/handover/handover.sh:685-689`. T-1274's `### Human` body contains only the `` template, regex counts the example as unchecked, T-1274 surfaces in handover Awaiting Human Review with the example AC text "Dashboard renders correctly" — none of which is a real AC.
- **Spike 2 — find sibling parsers.** grep for `### Human`, `unchecked`, `\[ \]`, `human_section` across `agents/`, `lib/`, `web/blueprints/`, `bin/fw`. Capture every place that counts unchecked Human ACs. The fix needs to land in all of them or be centralized.
- **Spike 3 — fix shape.** Decide between (a) regex-strip `` before counting; (b) line-by-line stateful scan that skips lines inside an open comment; (c) centralize via a helper function `_count_unchecked_human_acs(content)`. Existing precedent: L-097 says CTL-013 parser in `audit.sh` already tracks `in_comment` state — option (b) has prior art.

## Technical Constraints

- Must remain pure-Python (handover.sh embeds Python via heredoc; no new pip deps).
- Stripped scan must not cross multiple `### Human` sections (rare, but possible on pathological tasks).
- Watchtower review-queue rendering may have its own copy of this logic — fix needs to land everywhere or risk Watchtower and CLI handovers disagreeing.
- Bats test must run from a temp dir / synthetic task fixture (no mutation of framework's real `.tasks/`).

## Scope Fence

**IN scope:**
- Strip `` comment blocks (or equivalent state-tracking) before counting unchecked Human ACs in `agents/handover/handover.sh`.
- Apply the fix to every parser found in Spike 2.
- Add governance test case under `tests/governance/` or `tests/unit/`.

**OUT of scope (deferred):**
- Removing the Example AC from the default task template (changes user-facing template behavior; separate decision).
- Adding a "no Human ACs at all" sentinel to the template (would change task creation flow).
- Watchtower-side review-queue blueprint changes if it doesn't share the logic (separate task if Spike 2 finds it).

## Go/No-Go Criteria

**GO if:**
- Spike 2 finds the parsers (one or several) and the fix landing scope is bounded (≤3 files).
- Spike 3 confirms a 5-15 line change works against synthetic fixtures.
- A bats test covering the phantom case can be added in <30 lines.
- No existing real human ACs would be silently hidden by the strip.

**NO-GO if:**
- Spike 2 reveals the count happens in many incompatible places that would each need bespoke fixes (signals "centralize as a library helper" as a separate, larger task).
- Stripping `` would risk hiding real ACs that humans have inadvertently nested inside comments (would need stronger detection).

## Recommendation

- **Recommendation:** GO
- **Rationale:** Spike 1 confirms bug source (`agents/handover/handover.sh:685-689`). Bounded fix (regex strip or line-state scan, ~10 lines). Reversible (revert one block). Real victims (T-1274) actively confused governance. Origin pattern (L-097, CTL-013 parser in audit.sh) shows the framework already has a working in-comment state tracker — borrow that.
- **Evidence:**
  - Bug source verified: `agents/handover/handover.sh:685, 689`
  - Concrete victim: T-1274's `### Human` body is exclusively the template comment block; "Dashboard renders correctly" is the example, not a real AC
  - L-097 / T-204 confirms framework already has stateful comment-block parsing pattern in `audit.sh` (CTL-013)
  - Sibling parsers may exist (Spike 2 to find) but bounded by the codebase's scale (~5 likely candidates)
  - Self-validating fix: after fix, T-1274 no longer surfaces in next handover

## Decision

**Decision**: GO

**Rationale**: - Recommendation: GO
- Rationale: Spike 1 confirms bug source (`agents/handover/handover.sh:685-689`). Bounded fix (regex strip or line-state scan, ~10 lines). Reversible (revert one block). Real victims (T-1274) actively confused governance. Origin pattern (L-097, CTL-013 parser in audit.sh) shows the framework already has a working in-comment state tracker — borrow that.
- Evidence:
  - Bug source verified: `agents/handover/handover.sh:685, 689`
  - Concrete victim: T-1274's `### Human` body is exclusively the template comment block; "Dashboard renders correctly" is the example, not a real AC
  - L-097 / T-204 confirms framework already has stateful comment-block parsing pattern in `audit.sh` (CTL-013)
  - Sibling parsers may exist (Spike 2 to find) but bounded by the codebase's scale (~5 likely candidates)
  - Self-validating fix: after fix, T-1274 no longer surfaces in next handover

**Date**: 2026-04-30T09:22:07Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-37ce2284
- **Timestamp:** 2026-06-02T14:58:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-30T09:22:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
