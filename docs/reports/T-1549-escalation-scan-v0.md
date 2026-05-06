# T-1549 — Layer B v0 Heuristic Scan Results

**Run:** 2026-05-06T03:23:01.559132+00:00
**Corpus:** 1680 completed tasks
**Bug-class identified:** 358 (21%)

## H1 — Bug-class tasks with no `## RCA` section

**Flagged:** 326 / 358 bug-class tasks (91%)

**Last 30 days sample (FP triage candidates):**

- `T-1014-fix-playwright-navigation-test-timeout--` — Fix Playwright navigation test timeout — batch contention
- `T-1026-playwright-tests--docs-detail-review-acs` — Playwright tests — docs detail, review ACs, POST error handling
- `T-1027-fix-graduation-page-playwright-test-time` — Fix graduation page Playwright test timeout
- `T-1040-playwright-networkidle-migration--replac` — Playwright networkidle migration — replace networkidle with domcontentloaded acr
- `T-1045-fix-playwright-test-server--enable-flask` — Fix Playwright test server — enable Flask threaded mode to prevent sequential re
- `T-1051-playwright-response-time-regression-test` — Playwright response time regression test — verify no route takes >5s
- `T-1053-version-bump-to-1586--332-playwright-tes` — Version bump to 1.5.86 — 332 Playwright tests, timing report, performance regres
- `T-1069-one-time-horizon-status-data-cleanup--fi` — One-time horizon-status data cleanup — fix 52 inconsistent tasks
- `T-1073-fix-playwright-test-suite--mass-failures` — Fix Playwright test suite — mass failures across API and UI tests
- `T-1075-fix-project-boundary-false-positive--ter` — Fix project boundary false positive — TermLink commands inside loops/pipes
- `T-1076-fix-shellcheck-sc2034-false-positive-in-` — Fix shellcheck SC2034 false positive in healing diagnose.sh
- `T-1078-fix-pre-push-hook--missing-agentic-frame` — Fix pre-push hook — missing .agentic-framework audit path for consumer projects
- `T-1079-fix-hook-version-drift--gitsh-shows-14-b` — Fix hook VERSION drift — git.sh shows 1.4 but templates write 1.5 causing instal
- `T-1081-fix-fw-gaps--missed-t-397-rename-from-ga` — Fix fw gaps — missed T-397 rename from gaps.yaml to concerns.yaml
- `T-1083-fix-post-compact-resume-fabric-lookup--u` — Fix post-compact-resume fabric lookup — uses PROJECT_ROOT path, fails silently o
- `T-1086-fix-hookssh-bypass-messages--commit-msg-` — Fix hooks.sh bypass messages — commit-msg task-ref, inception gate, pre-push (T-
- `T-1087-budget-gate-post-compact-stale-read--saf` — Budget gate post-compact stale read — safety net fix
- `T-1088-budget-gate-timestamp-filter-post-compac` — Budget gate timestamp-filter post-compact JSONL read (real T-1087 fix)
- `T-1119-pickup-approvals-page-never-displays-age` — Pickup: Approvals page never displays agent recommendation or argumentation — ra
- `T-1120-pickup-review-marker-gate-blocks-watchto` — Pickup: Review marker gate blocks Watchtower GO/NO-GO decisions — human clicking
- `T-1123-pickup-approvals-page-shows-inception-ta` — Pickup: Approvals page shows inception tasks without recommendations — creates n
- `T-1127-pickup-u-003-send-file-reports-ok-on-hub` — Pickup: U-003: send-file reports ok on hub acceptance, not delivery — silent fil
- `T-1133-pickup-gnu-date--d-in-framework-shell-sc` — Pickup: GNU date -d in framework shell scripts fails silently on macOS — causes 
- `T-1143-t-1102-build-context-aware-fw-path-helpe` — T-1102 build: context-aware fw path helper (_fw_cmd) and fix 3 hardcoded bin/fw 
- `T-1150-rca-recommendation-text-truncation-in-mu` — RCA: recommendation text truncation in multiple surfaces — fix + inception for r
- ... +145 more in last 30 days

## H2 — Learning IDs referenced across ≥3 tasks within 30 days

- `P-011` — referenced by 171 tasks: T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f …
- `P-010` — referenced by 120 tasks: T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f …
- `L-291` — referenced by 96 tasks: T-1518-approvals-page-surface-deferred-inceptio, T-1521-extend-fw-doctor-vendor-drift-glob-to-co, T-1522-self-lock-in-handoversh-to-prevent-concu, T-1523-update-tasksh-git-stage-both-sides-of-ac, T-1524-t-1523-throwaway-test …
- `L-006` — referenced by 54 tasks: T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou …
- `L-001` — referenced by 38 tasks: T-011-define-practice-graduation-criteria, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le …
- `PL-007` — referenced by 24 tasks: T-1141-pickup-pl-007-never-dump-terminal-comman, T-1141-pickup-pl-007-never-dump-terminal-comman, T-1141-pickup-pl-007-never-dump-terminal-comman, T-1146-pickup-critical-rca-agent-command-amnesi, T-1146-pickup-critical-rca-agent-command-amnesi …
- `L-293` — referenced by 23 tasks: T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1528-t-1528-defensive-h2-terminator-on-recomm …
- `L-002` — referenced by 13 tasks: T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session …
- `L-298` — referenced by 13 tasks: T-1540-three-sequential-blind-reviewer-validati, T-1540-three-sequential-blind-reviewer-validati, T-1540-three-sequential-blind-reviewer-validati, T-1577-f10--extend-no-rec-distinction-to-landin, T-1577-f10--extend-no-rec-distinction-to-landin …
- `L-316` — referenced by 13 tasks: T-1584-surface-recommendation--reviewer-verdict, T-1584-surface-recommendation--reviewer-verdict, T-1584-surface-recommendation--reviewer-verdict, T-1585-surface-reviewer-verdict-on-inceptiont-x, T-1585-surface-reviewer-verdict-on-inceptiont-x …
- `P-002` — referenced by 12 tasks: T-001-define-success-metrics, T-001-define-success-metrics, T-004-install-pre-commit-hook-for-task-enforce, T-011-define-practice-graduation-criteria, T-014-improve-audit-agent-to-measure-quality-n …
- `P-001` — referenced by 12 tasks: T-001-define-success-metrics, T-014-improve-audit-agent-to-measure-quality-n, T-018-enrich-low-quality-episodic-summaries, T-044-backfill-episodic-tags-with-controlled-v, T-1258-rca-fw-context-add-learning-truncates-le …
- `PL-003` — referenced by 12 tasks: T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session …
- `PL-005` — referenced by 12 tasks: T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session …
- `PL-006` — referenced by 12 tasks: T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session, T-1129-pickup-4-learnings-from-termlink-session …

## H3 — Bug-class with no RCA AND no learning captured

**Flagged:** 268 / 358 (74%)

This is the strongest symptom-fix signal: fix shipped, no root cause stated, no learning captured for next time.

## Self-application (Spike 3 — recursion test)

T-1548 (the inception that birthed this scan): bug_class=False has_rca=False learning_captured=True → flagged_by_H1=False

**Reading:** if T-1548 is flagged by H1, the heuristic correctly identifies even the meta-task itself as lacking an inline `## RCA` section — though its `docs/reports/T-1548-rca-escalation-structural.md` artifact carries the RCA. H1's blindness to artifact files is a known limitation, addressable in v1 by also scanning `docs/reports/T-XXX-*.md`.

## Headline numbers

| Metric | Value |
|---|---|
| Total completed tasks | 1680 |
| Bug-class tasks | 358 (21%) |
| H1 flagged | 326 |
| H2 repeat-learning patterns | 69 |
| H3 flagged (strongest signal) | 268 |
| Last-30-days bug-class | 170 |

## Read-out — GO/NO-GO for Layer B v1 (cron + register + Watchtower)

**GO Layer B v1** if (manual triage on a 20-task sample of H1):
- Recall ≥ 70%: the scanner finds the symptom-fix instances we *know* exist
- FP rate < 30%: most flagged tasks really are bug-fixes-without-RCA, not docs/refactors miscategorised
- H2 produces actionable repeat-class signal (not just generic L-IDs everyone cites)

**NO-GO / iterate** if:
- FP > 30% on the sample → tighten `is_bug_class` filter (use commit-history + tags more strictly) before promotion
- H1 misses obvious past instances → add commit-message scanning to recall
- H2 noise dominates → require co-occurrence with H1 to count

**DEFER** if the data shows the dominant pattern is something v0 doesn't model (e.g. corrections within a session, not across tasks) → re-scope before building v1.
