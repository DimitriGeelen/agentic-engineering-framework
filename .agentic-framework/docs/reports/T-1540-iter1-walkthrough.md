# T-1540 — Blind Reviewer Walkthrough (iter 1)

**Reviewer:** Sub-agent dispatch worker, no prior session context
**Date:** 2026-04-27T12:35Z
**Surfaces visited:** handover (`LATEST.md` → `S-2026-0427-1419.md`), `/approvals`, `fw review-queue`, `/review/T-1531`
**Watchtower URL resolved:** `http://192.168.10.107:3000` (via `bin/fw watchtower url`)

## What worked

- **Handover prefixes are scannable.** The `Awaiting Human Review (10 tasks)` and `(15 tasks)` blocks render `[GO]`/`[DEFER]` prefixes inline with markdown links to `/review/T-XXX`. Every task ID I sampled (T-1531, T-1539, T-446, T-470) carried a verdict prefix; no `[?]` or `[NO-GO]` appeared in either block. Links are well-formed `http://192.168.10.107:3000/review/T-XXX` URLs — clickable in any markdown viewer.
- **`/approvals` cards carry both `data-verdict` and a visible `verdict-badge`.** 44 partial-complete cards (`approval-card human-ac-group`) — `data-verdict` raw counts: 40 `GO` + 20 `DEFER` + 28 `?` (each card emits the attribute twice — once on the wrapper, once on the badge → 20 GO / 10 DEFER / 14 `?` cards). Filter buttons wired correctly: `data-filter="go"` (20), `data-filter="defer"` (10), `data-filter="review"` (36), `data-filter="rubber-stamp"` (1), `data-filter="stale"` (26), `data-filter="all"` (44).
- **`fw review-queue` is clean.** 46 tasks listed in three colour-grouped blocks (GO/DEFER/`?`), sorted by age within group, footer summary line `46 task(s) awaiting human review (20 GO / 10 DEFER / 16 ?)` and a pasteable `Open in Watchtower:` URL. ANSI colour mapping reads green/amber/dim — distinguishable.
- **`/review/T-1531` exposes the agent's `## Recommendation` verbatim.** Section is `<section class="recommendation-block" data-verdict="GO">` with green styling, full rationale + evidence rendered in a `<pre>` block, then per-AC checkbox UI with `hx-post` toggling. Per-verdict CSS exists for GO/DEFER/NO-GO. Decision UI (checkbox + Steps + Expected + If-not) all present.
- **Landing page Action Required widget has working verdict pills.** Two `<small class="verdict-pill" data-verdict-pill="GO|DEFER">` tiles next to the 54-Human-AC counter showing `20 GO` and `10 DEFER` with hover titles explaining the rubber-stamp vs strategic semantics.
- **Inception verdict-badge code is present in `_approvals_content.html`** (lines 75/81 and 271/281 — `approval-card go-decision` AND `approval-card human-ac-group` both render `data-verdict` + `verdict-badge`). T-1537 implementation is wired.

## What didn't work

- **Inception parity (T-1537) is not visually verifiable right now.** `/approvals` summary reads `0 Tier 0 · 0 GO/NO-GO`. Section B (GO/NO-GO Decisions) is empty in the rendered HTML — only the comment marker `<!-- Section B: GO/NO-GO Decisions -->` with no children. Code path is implemented but the queue is empty (9 of 10 active inceptions are already DEFER'd, the remaining one is T-1538 a pickup with `pending` decision but it doesn't surface as an `approval-card go-decision` here). A reviewer cannot confirm the badge actually paints on a real inception card without seeded test data.
- **Counts disagree across surfaces by 19–21 tasks.** Handover Awaiting blocks total 25 (20 GO + 5 DEFER) while `fw review-queue` and the landing-page widget agree on 46 tasks. The 21 tasks missing from the handover are the 16 `?`-verdict items + 5 DEFER inceptions visible on the CLI but not in the handover Awaiting Review sections (they appear under `horizon: next` Work-in-Progress instead, without verdict prefixes).
- **`/approvals` shows 44 cards, `fw review-queue` shows 46.** A 2-task drift between the page and the CLI. Likely T-1538 + T-1540 (both 0d age, no recommendation block yet) — but it's a real inconsistency for a human eyeballing both at the same time.
- **No `[NO-GO]` or `[?]` filter / pill / prefix paths are exercised.** No `[NO-GO]` appears anywhere because the dataset has zero NO-GO tasks. But the `?` verdict (16 tasks per CLI) has no filter button on `/approvals`, no verdict-pill on the landing page, and no `[?]` prefix in the handover — those 16 tasks are silently invisible on every visual surface even though they are agent-acknowledged review-queue items.

## What was missing or surprising

- **Handover doesn't say "and 21 more not shown".** A reviewer trusting the handover thinks 25 tasks need attention. The CLI says 46. There's no breadcrumb in the handover pointing at the gap.
- **`?` verdict is a first-class queue state without a first-class surface treatment.** Cards exist on `/approvals` with `data-verdict="?"`, the CLI counts them, but no filter / no pill / no handover prefix means they functionally hide from any human triaging via UI alone.
- **T-1540 (this task!) appears in `fw review-queue` with `?` verdict** even though it's `started-work`, not partial-complete. Suggests the queue includes any task with unchecked Human ACs regardless of lifecycle state — possibly noisy.
- **Landing page text says "46 tasks" but pill total is 30** (20+10). The remaining 16 are unaccounted for in the visible breakdown.
- **No `verdict-pill` for NO-GO on the landing page** — defensible (zero count) but means the surface is untested for that value. Same risk as inception cards: code exists, dataset doesn't exercise it.

## Counts (cross-checks)

| Surface | GO | DEFER | NO-GO | ? | Total |
|---|---|---|---|---|---|
| Handover Awaiting (now + next blocks) | 20 | 5 | 0 | 0 | 25 |
| /approvals `verdict-badge` cards | 20 | 10 | 0 | 14 | 44 |
| fw review-queue (footer summary) | 20 | 10 | 0 | 16 | 46 |
| Landing page Action Required pills | 20 | 10 | — | — | 46 by counter / 30 by pills |

**Discrepancies flagged:**
1. Handover under-reports by 21 tasks (no `?` verdicts shown, 5 DEFER inceptions filed under Work-in-Progress instead).
2. `/approvals` rendering trails CLI by 2 tasks (likely most-recent additions without a recommendation block yet).
3. Landing page text count (46) does not match pill sum (30) — the 16 `?` tasks have no pill.
4. `?` verdict has no filter button on `/approvals`, no pill on landing, no prefix in handover — invisible to UI-only triage.

## One-line conclusion

**CONCERN** — verdict surfaces work correctly for the GO/DEFER paths visible in production data, but `?` verdict tasks (16/46 — 35% of the queue) have no surface representation, the handover under-reports by 21 tasks, and inception verdict-badge code (T-1537) cannot be visually verified without seeded data.
