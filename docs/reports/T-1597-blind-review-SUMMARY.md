# T-1597 Blind TermLink Reviewer Sweep — Consolidated Packet

**Date:** 2026-04-29
**Workers:** 5 parallel TermLink blind reviewers (W1-W5), 22 GO `now` awaiting-review tasks
**Precedent:** T-1539/T-1540 blind-reviewer convergence test
**Watchtower:** http://192.168.10.107:3000

---

## Tally

| Verdict | Count | Tasks |
|---|---|---|
| **confirm-GO** | 21/22 | T-1214, T-1277, T-1448, T-1449, T-1483, T-1484, T-1485, T-1531, T-1537, T-1539, T-1540, T-1574, T-1575, T-1576, T-1577, T-1578, T-1582, T-1583, T-1584, T-1585, T-1593 |
| **flag-concern** | 1/22 | T-1586 (negative-case fixture decay) |
| **inconclusive** | 0/22 | — |

**Bottom line:** 21 ready to stamp. 1 needs a small fixture fix before stamping.

---

## Group reports

- [W1 — `/review` surface (6)](T-1597-blind-review-W1.md): T-1574, T-1575, T-1577, T-1578, T-1582, T-1583
- [W2 — `/approvals` surface (4)](T-1597-blind-review-W2.md): T-1214, T-1531, T-1537, T-1576
- [W3 — `/tasks` + `/inception` parity (3)](T-1597-blind-review-W3.md): T-1584, T-1585, T-1586
- [W4 — Reviewer CLI (5)](T-1597-blind-review-W4.md): T-1448, T-1449, T-1483, T-1484, T-1485
- [W5 — CLI / non-UI (4)](T-1597-blind-review-W5.md): T-1277, T-1593, T-1539, T-1540

---

## Stamp-ready (21) — strongest evidence per task

Sorted by surface group. Each row: task + Watchtower link + the single piece of evidence the blind reviewer leaned on.

### `/review` surface (W1) — 6/6 stamp-ready

| Task | Strongest evidence |
|---|---|
| [T-1574](http://192.168.10.107:3000/review/T-1574) Fix Complete button for inception tasks | Both `/review/<id>` and htmx fragment `/review/<id>/acs` render `inception-decide-form` — polling can't regress to a generic Complete button |
| [T-1575](http://192.168.10.107:3000/review/T-1575) Structural Recommendation rendering | `class="rec-rationale"` and `class="rec-evidence"` both present in served HTML — wall-of-markdown gone |
| [T-1577](http://192.168.10.107:3000/review/T-1577) NO-REC pill on landing page | Cockpit and approvals NO-REC counts agree exactly on live load (both = 1) |
| [T-1578](http://192.168.10.107:3000/review/T-1578) NO-REC banner on /review | `data-verdict="NO-REC"` element renders on `/review/T-801` with cyan theme (Steps point at T-1062 which is no longer NO-REC — stale Steps, not stale fix) |
| [T-1582](http://192.168.10.107:3000/review/T-1582) htmx error handler | `function showToast`, `htmx:responseError`, `htmx:sendError` all present in served HTML |
| [T-1583](http://192.168.10.107:3000/review/T-1583) Reviewer Verdict on /review | Live `<section class="reviewer-verdict-block" data-reviewer-overall="PASS">` renders on `/review/T-1582` |

### `/approvals` surface (W2) — 4/4 stamp-ready

| Task | Strongest evidence |
|---|---|
| [T-1214](http://192.168.10.107:3000/review/T-1214) Inception card fallback context | Template fallback at `_approvals_content.html:138-158` covers no-recommendation, no-problem, no-criteria with `{% if %}` guards + escape link to full task page |
| [T-1531](http://192.168.10.107:3000/review/T-1531) Verdict badges in /approvals | 55 live cards visibly carry color-coded badges — 43 GO + 11 DEFER + 1 NO-REC, no two colors collide |
| [T-1537](http://192.168.10.107:3000/review/T-1537) Verdict on inception cards | Template uses canonical `extract_recommendation_verdict()` (single source of truth, no drift with T-1531) + 5 synthetic tests pass |
| [T-1576](http://192.168.10.107:3000/review/T-1576) NO-REC distinct from DEFER | Live cyan NO-REC card on T-449 alongside cyan filter button "NO-REC (1)" — visually + copy-wise distinct from amber DEFER |

### `/tasks` + `/inception` parity (W3) — 2/3 stamp-ready

| Task | Strongest evidence |
|---|---|
| [T-1584](http://192.168.10.107:3000/review/T-1584) Recommendation + Reviewer cards on /tasks | Cards render at correct slot on `/tasks/T-1582` (line 913 + 936) with right palette and order |
| [T-1585](http://192.168.10.107:3000/review/T-1585) Reviewer Verdict on /inception | Card placement matches `/tasks` and `/review`; heading-prefix filter handles future v1.5/v1.6 without code changes |

### Reviewer CLI (W4) — 5/5 stamp-ready

| Task | Strongest evidence |
|---|---|
| [T-1448](http://192.168.10.107:3000/review/T-1448) Per-AC granular verdicts | Live `bin/fw reviewer T-1020 --no-write` shows findings nested under their AC text — exactly the grouping promised |
| [T-1449](http://192.168.10.107:3000/review/T-1449) TTL'd override mechanism | `bin/fw reviewer override list` shows 4 entries with documented reasons + future expiry; T-1583 scan shows `Suppressed: 2 (by override)` with audit trail |
| [T-1483](http://192.168.10.107:3000/review/T-1483) Pass A drift + Pass B reverify | `bin/fw reviewer drift T-1445` surfaces 3 real changed files from active v1.5 chain — comparator works on live data |
| [T-1484](http://192.168.10.107:3000/review/T-1484) Corpus Pass B | Clean YAML with full per-task SHA/exit-code records; zero leaked worktrees after run |
| [T-1485](http://192.168.10.107:3000/review/T-1485) Corpus Pass A drift | Existing `2026-04-26-pass-a-baseline.yaml` + today's `2026-04-29-pass-a.yaml` schemas match — artifact contract stable in the wild |

### CLI / non-UI (W5) — 4/4 stamp-ready

| Task | Strongest evidence |
|---|---|
| [T-1277](http://192.168.10.107:3000/review/T-1277) Bounded git push in handover | bats #6 (real `timeout` cmd vs unreachable remote 192.0.2.1 returns within bound) — exactly what the 4h stall would have failed |
| [T-1593](http://192.168.10.107:3000/review/T-1593) Annotated tag enforcement | Synthetic exit code 1 (lightweight) vs 0 (annotated); error message includes verbatim `git tag -d X && git tag -a X -m "..."` recreate command |
| [T-1539](http://192.168.10.107:3000/review/T-1539) Blind reviewer arc validation | T-1539's findings caught the framework violating its own T-1376 localhost rule — the kind of leverage blind dispatch promises |
| [T-1540](http://192.168.10.107:3000/review/T-1540) Convergence test (3 loops) | FP-rate-by-prompt-quality dropped 67% (iter2) → 0% (iter3 with L-296 prefix) — convergence not noise |

---

## Stamp-blocker (1) — needs a small fix first

### T-1586 — Cross-surface parity invariant test (W3)

**Watchtower:** http://192.168.10.107:3000/review/T-1586

**Issue:** The Playwright invariant test `tests/playwright/test_cross_surface_parity.py` ships a fragile negative-case fixture. `TASK_WITHOUT_REVIEWER = "T-967"` (line 33) was a valid no-reviewer-block task at completion-time, but the daily reviewer scan systematically writes `## Reviewer Verdict (v1.4)` blocks back into completed tasks. T-967 acquired its own block at 2026-04-28T20:18:03Z — **16 minutes after T-1586 was marked work-completed at 16:16Z**.

**Live state:** `python3 -m pytest tests/playwright/test_cross_surface_parity.py -q --no-header` → **1 failed, 7 passed**. The 7 positive-case assertions are solid; the 1 failure is `test_reviewer_block_absent_when_body_has_no_block`.

**Why it matters:** The Recommendation block claims "6 passed in 16.76s" at completion-time — that claim cannot be reproduced today. As more tasks acquire reviewer blocks via routine cron, the chosen "negative" fixture will not recover.

**Suggested fix (5-line change):**
- Either generate a synthetic no-reviewer task body in-test (preferred — fully decoupled from corpus drift), or
- Re-pick a task that genuinely has no reviewer block today (kicks the can — same decay will bite again).

**Reviewer's stance:** The contract design and docstring quality are excellent — this IS the cross-surface invariant L-316 needed. The negative case is a fixture problem, not a code problem. The human can stamp this *after* the fixture fix lands, or stamp now with a follow-up task to fix the fixture (verifying-via-passing-positive-cases is still valuable signal).

---

## Cross-cutting findings (all surfaces)

### Classification gripes — `[REVIEW]` ACs that should be Agent ACs (T-954)

| Task | Why deterministic |
|---|---|
| T-1582 | Toast container DOM + handler script presence is mechanical — already in `## Verification` |
| T-1484 | "Suitable for cron" → timing + worktree-leak check are deterministic |
| T-1485 | "STABLE for unchanged work" is binary — should have a verification command (baseline → no mutate → re-scan → assert STABLE > 0 && DRIFTED == 0) |
| T-1593 | Synthetic test already in `## Verification`; `[REVIEW]` is redundant |

These don't block stamps — they're suggestions for future task authoring per the T-954 risk matrix.

### Steps decay (UX paper-cut, not blockers)

| Task | Issue |
|---|---|
| T-1578 | Steps target T-1062 which is no longer NO-REC. Retarget at T-801. |
| T-1583 | Negative-case verification command targets T-967 which now has a reviewer block. Retarget. |
| T-1214 | Steps URL says `:3001` (stale port; current Watchtower is `:3000` — bin/fw watchtower url resolves correctly). |

### Agent AC literal mismatch (T-1277)

`grep -c FW_HANDOVER CLAUDE.md` returns 0. Agent AC #6 says CLAUDE.md Configuration table should mention `FW_HANDOVER_PUSH_TIMEOUT` and `FW_HANDOVER_TOTAL_TIMEOUT` explicitly. Currently the table only says "handover timeouts" generically with a pointer to `fw config list`. Not blocking the Human AC stamp, but flag for housekeeping.

### Self-corroborating note

T-1539/T-1540 are the precedent for what we just did at scale. W5 noted: *"I am W5 of 6 workers running an N=22 scaled-up version of this same experiment. The fact that the dispatch primitive works, returns structured artifacts, and produces actionable findings is itself the strongest meta-evidence for T-1539/T-1540's claims."* Convergence test claim survives blind scrutiny at 5x scale.

---

## What you do now

1. **Open Watchtower** at http://192.168.10.107:3000
2. **Stamp the 21 confirm-GO tasks** — for each one above, click the Human AC checkbox(es) and Complete. The strongest-evidence column above tells you what to look for if you want to spot-check before stamping.
3. **Decide T-1586** — either (a) stamp now with a follow-up task to fix the fixture, or (b) hold the stamp until the 5-line fixture change lands.
4. **Optional:** consider three small cleanup tasks surfaced by this sweep:
   - Reclassify the 4 `[REVIEW]` ACs in the gripes table as Agent ACs (T-954 alignment).
   - Refresh stale Steps in T-1578, T-1583, T-1214.
   - Add `FW_HANDOVER_*` to CLAUDE.md Configuration table (closes T-1277 Agent AC#6 literal).

These cleanups don't need to happen before you stamp — they're follow-up hygiene.
