# T-1507 — Inception decide CLI/Watchtower output truncates long rationale comments mid-sentence

> **Inception research artifact** (backfilled by T-2515 from the `T-1507` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1507-inception-decide-cliwatchtower-output-tr.md`. **Decision recorded: GO.**

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

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Recommendation

**Recommendation:** GO (small bounded fix)

**Rationale:** Localized the truncation site by code-read (no spike needed): `web/blueprints/inception.py:527` clips the side-effect warning to `[:150]` chars in the htmx response fragment, and `web/blueprints/inception.py:545` clips to `[:300]` chars in the non-htmx redirect path. That is where T-1506's `…/root/.claude/sett` cutoff came from. The fix is mechanical and tightly scoped: bump the caps to a readable size (≈800 chars), append a `… (truncated, see server log)` suffix when the cap fires so the operator knows there's more content. Server logs already capture full stdout/stderr at `[:500]` (line 514), so the recovery path exists. No CLI-side truncation needed (CLI streams subprocess output unmodified).

T-1509 (closed in this session) addressed the happy-path trigger that made the `[:150]` cap fire on every successful decision. The cap now only matters on real side-effect failures (rare). But "rare and unreadable when it fires" is exactly the failure mode this should prevent, and the fix is a 5-line edit with one regression test. Build cost is hours, blast radius is one display surface.

**Evidence:**
- **A1 confirmed:** truncation site is `web/blueprints/inception.py:527` (htmx, `[:150]`) and `:545` (non-htmx redirect, `[:300]`). Verified by grep.
- **A2 partially falsified:** it is a byte cap (150/300), not terminal-width — the cap lives in the Flask response, not in any terminal-width measurement. The CLI itself does not truncate; subprocess output is streamed unmodified.
- **A3 falsified:** `/inception/T-XXX` rationale rendering is NOT capped. `_extract_rationale_from_recommendation` (lines 28-60) does a semantic slice between markers, no character limit. So the audit-trail surface (the page where rationale is read post-decision) is fine.
- **A4 N/A here:** `agents/docgen/generate_article.py:219` does cap rationale at `[:80]` but that is article generation, not the live `/decisions` index. Separate concern; flag as follow-up if articles are ever the audit-trail surface.
- **A5 confirmed:** no structured logging of CLI-side emit, BUT line 514 already logs stdout/stderr to Python logger at `[:500]`. Recovery path exists for operators with log access.

**Proposed bounded fix (one task, one PR):**
1. Bump line 527 cap `150 → 800`, append `…(truncated)` if `len(stderr or stdout) > 800`.
2. Bump line 545 cap `300 → 800` (URL query-string can absorb 800; redirects rarely hit URL length limits at this size).
3. Bump line 514 log-side cap `500 → 2000` so log-side recovery captures the full bug context.
4. Regression test: `tests/web/test_inception_decide_*.py` — simulate fw subprocess returning stderr `'X' * 1000`, assert response contains either full text or `(truncated)` marker.
5. NO CLI-side change.

**Alternatives considered:**
- *Remove caps entirely*: rejected — htmx fragment is injected into a small card; uncapped HTML risks layout breakage on long traces. Bounded with hint is the right ergonomics.
- *Smart wrap-aware truncation*: rejected — over-engineered for a side-effect warning. A clear suffix marker is enough.
- *DEFER*: rejected — fix is small, T-1509 already removed the trigger but the next side-effect failure (different cause) will hit the same readability wall. Worth landing now.
- *Fix CLI separately*: rejected — CLI doesn't truncate; nothing to fix there. The task title's framing is misleading; the bug lives entirely in the Watchtower htmx/redirect display.

**Build estimate:** 1 hour (one file edit + one test case + one commit). 1 build task to spawn after GO.

## Decision

**Decision**: GO

**Rationale**: Localized the truncation site by code-read (no spike needed): `web/blueprints/inception.py:527` clips the side-effect warning to `[:150]` chars in the htmx response fragment, and `web/blueprints/inception.py:545` clips to `[:300]` chars in the non-htmx redirect path. That is where T-1506's `…/root/.claude/sett` cutoff came from. The fix is mechanical and tightly scoped: bump the caps to a readable size (≈800 chars), append a `… (truncated, see server log)` suffix when the cap fires so the operator knows there's more content. Server logs already capture full stdout/stderr at `[:500]` (line 514), so the recovery path exists. No CLI-side truncation needed (CLI streams subprocess output unmodified).

T-1509 (closed in this session) addressed the happy-path trigger that made the `[:150]` cap fire on every successful decision. The cap now only matters on real side-effect failures (rare). But "rare and unreadable when it fires" is exactly the failure mode this should prevent, and the fix is a 5-line edit with one regression test. Build cost is hours, blast radius is one display surface.

**Date**: 2026-04-26T14:46:56Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-77d525e6
- **Timestamp:** 2026-06-02T14:57:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T14:46:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
