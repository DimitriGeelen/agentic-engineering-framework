# T-835: Stale Task Backlog Analysis

**Date:** 2026-04-04  
**Scope:** All `.tasks/active/` files with unchecked Human ACs

## Summary

| Metric | Count |
|--------|-------|
| Active task files | 116 |
| Work-completed, human-owned, unchecked Human ACs | **77** |
| Started-work, human-owned, unchecked Human ACs | 20 |
| Total unchecked Human ACs (work-completed only) | 79 |
| Tasks with `## Recommendation` section | 18 / 77 (23%) |

## Category Breakdown (work-completed only)

| Category | Tasks | % | Implication |
|----------|-------|---|-------------|
| **RUBBER-STAMP only** | 28 | 36% | Mechanical verification — auto-close candidates |
| **REVIEW only** | 48 | 62% | Requires human judgment — needs real review |
| **Both** | 1 | 1% | Mixed (T-832) |
| Uncategorized | 0 | 0% | All ACs are properly tagged |

## Workflow Type Distribution

| Type | Tasks |
|------|-------|
| Build | 43 |
| Inception | 34 |

## Age Distribution

| Age bucket | Tasks | % |
|------------|-------|---|
| 0–7 days | 46 | 60% |
| 8–14 days | 17 | 22% |
| 15–21 days | 9 | 12% |
| 22+ days | 5 | 6% |

**Oldest:** T-436 (2026-03-10, 25 days). **Median age:** 6 days. **Mean:** 8 days.

## Top 10 Oldest Tasks Awaiting Review

| Task | Age | Type | Cat | ACs | Name |
|------|-----|------|-----|-----|------|
| T-436 | 25d | inception | RV | 1 | Auto-compact YOLO mode |
| T-446 | 23d | build | RV | 1 | Rewrite README |
| T-448 | 23d | build | RV | 2 | Cron registry v2: web UI + YAML |
| T-460 | 23d | build | RV | 1 | Onboarding task templates |
| T-470 | 23d | build | RV | 1 | Deep-dive article 17: Bash/YAML/Files |
| T-479 | 21d | inception | RV | 1 | GitHub vs OneDev platform decision |
| T-481 | 21d | build | RS | 1 | Fix install.sh macOS update path |
| T-483 | 21d | build | RS | 1 | Fix Python 3.9 union type hints |
| T-493 | 21d | build | RS | 1 | fw update CLI command |
| T-505 | 19d | build | RV | 1 | Deep-dive article: Blast Radius |

**RS** = RUBBER-STAMP only, **RV** = REVIEW only.

## RUBBER-STAMP Tasks: 28 Auto-Close Candidates

Sub-classified by verification environment:

### Requires macOS (5 tasks)

Cannot be verified on Linux dev machine.

| Task | AC summary |
|------|-----------|
| T-481 | Run installer twice on macOS |
| T-483 | `fw serve` starts on Python 3.9 |
| T-518 | Verify on macOS bash 3.2 |
| T-613 | `brew upgrade` works on macOS |
| T-664 | `fw version` from consumer project dir |

### Requires browser/phone (14 tasks)

Watchtower UI, QR codes, push notifications.

| Task | AC summary |
|------|-----------|
| T-612 | E2E approval flow via Watchtower |
| T-621 | `fw serve --port` reachable from Mac via SSH |
| T-631 | URL opens correct task page |
| T-632 | File links render in viewer |
| T-633 | Auto-linked references clickable |
| T-671 | QR scans to /approvals |
| T-676 | Dark mode persists across pages |
| T-708 | Receive test notification on phone |
| T-710 | Receive test notification on phone |
| T-822 | /config page shows new settings |
| T-826 | Token badges on timeline cards |
| T-827 | Per-session token deltas display |
| T-829 | Token breakdown on timeline cards |
| T-831 | Session metrics in handover frontmatter |

### Verifiable via CLI (9 tasks)

Could potentially be auto-verified by `fw verify-acs` or scripted checks.

| Task | AC summary |
|------|-----------|
| T-493 | Run `fw update --check` |
| T-516 | Run `tests/e2e/runner.sh --tier b` |
| T-594 | Loop detection fires on repeated failure |
| T-646 | Consumer project gets .mcp.json after `fw init` |
| T-648 | `fw version` shows correct version |
| T-650 | Bash gate works in fresh session |
| T-651 | Agent\|TaskCreate matcher in settings.json |
| T-663 | Hooks fire in fresh Claude Code session |
| T-824 | `fw verify-acs` output makes sense |

## REVIEW Tasks: 48 Requiring Human Judgment

These are primarily:
- **Inception decisions** (34): GO/NO-GO calls on proposed features/architecture
- **Content review** (articles, README): Tone, accuracy, positioning judgment
- **UI/UX review**: Layout, interaction quality, visual design

## Key Findings

1. **77 tasks are stuck**, blocking `.tasks/active/` cleanup and inflating project metrics.
2. **36% (28) are RUBBER-STAMP** — mechanical verifications that don't require judgment. These are the lowest-hanging fruit.
3. **Of the 28 RUBBER-STAMP tasks, only 9 are CLI-verifiable** on the dev machine. The other 19 require macOS or browser access.
4. **62% (48) are REVIEW** — genuine decisions. These cannot be automated but could be batched into review sessions by category (inception decisions, article reviews, UI reviews).
5. **Only 23% have a `## Recommendation` section** — the human must dig through task details for the other 59 tasks to understand what's being asked.
6. **20 additional started-work tasks** also have unchecked Human ACs (different problem — these aren't complete yet).
7. **The backlog is accelerating** — 60% of tasks are <7 days old, meaning ~7 tasks/day enter this queue vs ~0 reviewed/day.

## Recommendations for T-835

| Action | Impact | Effort |
|--------|--------|--------|
| Auto-close 9 CLI-verifiable RUBBER-STAMP tasks | -9 tasks | Low — script can verify |
| Batch Watchtower UI review session (14 tasks) | -14 tasks | Medium — 30 min browser session |
| Batch macOS verification session (5 tasks) | -5 tasks | Medium — needs macOS access |
| Add `## Recommendation` to 59 tasks missing it | Enables faster reviews | Medium — agent can backfill |
| Batch inception GO/NO-GO review (34 tasks) | -34 tasks | High — genuine decisions |
| Gate: require `## Recommendation` before work-completed | Prevents future blank reviews | Low — add to P-010/P-011 |
| Rate alert: flag when backlog > 20 tasks | Early warning | Low — cron job |

## Full RUBBER-STAMP Task List (28 tasks)

T-481, T-483, T-493, T-516, T-518, T-594, T-612, T-613, T-621, T-631, T-632, T-633, T-646, T-648, T-650, T-651, T-663, T-664, T-671, T-676, T-708, T-710, T-822, T-824, T-826, T-827, T-829, T-831
