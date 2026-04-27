# T-1540 — Blind Reviewer Walkthrough (iter 2)

**Reviewer:** TermLink dispatch worker, no prior session context
**Date:** 2026-04-27T (iter2)
**Surfaces visited:** handover (`.context/handovers/LATEST.md`), `/approvals`, `fw review-queue`, `/review/T-1531`, `/inception` (cross-check)

## What worked

- **Handover Awaiting blocks are scannable.** Two `### Awaiting Human Review` groups (one per horizon) carry a `[GO]` / `[DEFER]` prefix on every line, hyperlinked to `http://192.168.10.107:3000/review/T-XXX`. Format: `- [GO] [T-1531](http://.../review/T-1531): "title"`. Triage time per row ≈1s.
- **`/approvals` cards are uniformly tagged.** All 45 pending cards expose `data-verdict="GO|DEFER|?"` on the outer `<div class="approval-card human-ac-group">` AND on the inner `<span class="verdict-badge">`. Colour scheme: green muted/border for GO, amber for DEFER, grey for `?`. Tooltip reads "Agent recommendation: GO".
- **Filter buttons exist.** `data-filter="go|defer|review|rubber-stamp|stale|unknown|all"` (7 buttons total) — covers verdict + AC-type + staleness in one strip.
- **Landing-page pills present.** `<small class="verdict-pill" data-verdict-pill="GO|DEFER|?">` rendered next to "Action Required" with hard-coded colours (`#1b5e20`, `#e65100`, `#616161`) and counts. Tooltip text matches semantics ("likely rubber-stamp", "needs strategic decision", "T-679 gap").
- **`fw review-queue` works as advertised.** Tab-aligned table, ANSI-coloured VERDICT column, summary footer (`44 task(s) awaiting human review (20 GO / 10 DEFER / 14 ?)`), Watchtower deeplink at bottom. Sort: verdict bucket → age ASC within bucket (oldest first) — sensible for triage.
- **`/review/T-1531` exposes the full Recommendation block.** `<section class="recommendation-block" data-verdict="GO">` carries per-verdict CSS (green / amber / red H3 colours), includes the full agent rationale verbatim, and is rendered above the Tier-0 / AC sections so the reviewer sees the recommendation before approving.

## What didn't work

- **Inception cards on `/approvals` are missing entirely.** The page header reads `Approvals (45 pending)` and renders only one `<h2>` ("Verifications") with one `<h3>` ("Human Acceptance Criteria"). No "Inception Decisions" section, no inception cards. T-1537's AC text quoted in the page itself says "Scroll to the 'Inception Decisions' section [...] each inception card should now show a coloured verdict badge" — but that section is not in the rendered HTML. Cross-check: the handover claims **10 inception task(s) pending decision**.
- **`/inception` page doesn't carry verdict markup either.** 540KB of HTML, **0** matches for `verdict-badge`, `data-verdict`, or `go-decision`. So if T-1537's surface moved off `/approvals`, it didn't land on `/inception`.
- **Single `go-decision` class anywhere on `/approvals`** — and that one is a leftover label string inside a *Recently Resolved* "approved" card (`<div class="approval-risk">INCEPTION DECISION: ...</div>`), not a CSS class on a pending card. Nothing on the live queue uses `go-decision`.
- **Counts disagree across surfaces.** The four surfaces never quite agree on what "awaiting human review" means — see table below. Most striking: handover excludes all 14-16 unknown-verdict tasks AND half of the DEFER tasks; landing pills overcount `?` by 1 vs the rendered cards and by 2 vs the CLI.
- **No `nogo` filter button.** Filter strip has `go`, `defer`, `unknown` but no `nogo`. Currently 0 NO-GO tasks exist so the omission is invisible — but the moment one appears, it'll be unfilterable.

## What was missing or surprising

- **Awaiting Human Review section is duplicated in the handover** (once under `horizon: now`, once under `horizon: next`) but the consolidated "Awaiting Your Action (Human)" tally below uses a *different* count (25, not 10+15=25 — those happen to match here, but the second list is built independently and risks drift).
- **Stale flag is independent of verdict.** A `[GO]` task that's been waiting 45 days renders identically to a 0-day-old `[GO]` in the handover. `/approvals` does flag staleness with an amber `45d ⚠` annotation and a `data-stale="true"` attribute, but the handover prefix doesn't surface it.
- **`fw review-queue` truncates titles at ~62 chars with `...`** — fine for terminals but the truncation is silent (no flag indicating "more text exists"). Would be friendlier with a `--full` flag or width-aware wrapping.
- **`/review/T-1531`'s Recommendation block has per-verdict colour CSS for NO-GO** (`color: #991b1b`) **but no NO-GO surface anywhere else** (no filter button, no pill on landing). The plumbing is half-wired: render-side ready, query/filter side not.
- **No `?`-state mitigation guidance** on landing pill or `/approvals`. The pill tooltip says "T-679 gap" — a reviewer landing here cold has no idea what that means or how to fix it.

## Counts (cross-checks)

| Surface              | GO | DEFER | NO-GO | ? | Total |
|----------------------|----|-------|-------|---|-------|
| Handover Awaiting    | 20 | 5     | 0     | 0 | 25    |
| `/approvals` badges  | 20 | 10    | 0     | 15| 45    |
| `fw review-queue`    | 20 | 10    | 0     | 14| 44    |
| Landing pills        | 20 | 10    | 0     | 16| 46    |

**Discrepancies flagged:**
- **GO count is the only stable column** (20 across all four).
- **Handover under-reports DEFER (5 vs 10)** and **excludes `?` entirely (0 vs 14-16)**. Reading the handover alone, a human would think only 25 tasks need review when in fact 44-46 do — a 76% under-count for the unknown bucket.
- **`?` bucket diverges by ±2 across the three surfaces that do count it** (15 / 14 / 16). Three independent inclusion paths, no single source of truth.
- **Inception decisions:** handover claims 10 pending, `/approvals` renders 0, `/inception` has no verdict markup at all. Verdict-on-inception (T-1537) is not visible to a blind reviewer.

## One-line conclusion

**CONCERN** — Verdict surfacing works well for partial-complete Human-AC cards across all four surfaces, but T-1537 (inception verdict badges on `/approvals`) appears regressed/unrendered, and the four surfaces use four different inclusion rules so triage counts disagree by up to 21 tasks; ship the verdict-arc as "GO for Human-AC, NO-GO for inception parity" until the inception surface and count alignment are fixed.
