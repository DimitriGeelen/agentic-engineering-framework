# T-1549 — Layer B v0 Heuristic Scan Results

**Run:** 2026-05-22T03:23:01.733935+00:00
**Corpus:** 1849 completed tasks
**Bug-class identified:** 411 (22%)

## H1 — Bug-class tasks with no `## RCA` section

**Flagged:** 337 / 411 bug-class tasks (81%)

**Last 30 days sample (FP triage candidates):**

- `T-1127-pickup-u-003-send-file-reports-ok-on-hub` — Pickup: U-003: send-file reports ok on hub acceptance, not delivery — silent fil
- `T-1133-pickup-gnu-date--d-in-framework-shell-sc` — Pickup: GNU date -d in framework shell scripts fails silently on macOS — causes 
- `T-1289-fix-fabricwatch-patternsyaml-yaml-schema` — Fix .fabric/watch-patterns.yaml YAML schema — exclude key misplaced inside patte
- `T-1296-pickup-watchtower-csrf-403-after-restart` — Pickup: Watchtower CSRF 403 after restart — auto-regenerated FW_SECRET_KEY + mul
- `T-1297-pickup-watchtower-projectroot-defaults-t` — Pickup: Watchtower PROJECT_ROOT defaults to FRAMEWORK_ROOT — ambient strip silen
- `T-1348-pickup-fw-fabric-drift-and-scan-miss-rec` — Pickup: fw fabric drift and scan miss recursive glob matches — bash ** needs sho
- `T-1349-pickup-vendored-agentic-framework-tracks` — Pickup: Vendored .agentic-framework/ tracks Python __pycache__ files — Uncommitt
- `T-1350-pickup-watchtower-csrf-403-after-restart` — Pickup: Watchtower CSRF 403 after restart — auto-regenerated FW_SECRET_KEY + mul
- `T-1351-pickup-watchtower-fabric-crashes-keyerro` — Pickup: Watchtower /fabric crashes (KeyError: id) on subsystems.yaml without id 
- `T-1352-pickup-watchtower-flask-secretkey-auto-r` — Pickup: Watchtower Flask secret_key auto-regenerates on every restart — breaks C
- `T-1353-pickup-watchtower-loadlatestaudit-picks-` — Pickup: Watchtower load_latest_audit picks upgrades.yaml instead of newest audit
- `T-1357-pickup-claudemd-template-instructs-use-b` — Pickup: CLAUDE.md template instructs Use bin/fw not fw — correct in framework re
- `T-1358-pickup-pre-push-hook-stamps-project-vers` — Pickup: Pre-push hook stamps project VERSION into .agentic-framework/VERSION — o
- `T-1359-pickup-watchtower-placeholder-detector-m` — Pickup: Watchtower placeholder detector matches text inside HTML comments — fals
- `T-1381-align-docs-to-fw-watchtower-porturl--fix` — Align docs to fw watchtower port/url — fix CLAUDE.md self-contradiction + README
- `T-1385-verify-g-056-fix-propagates-to-consumer-` — Verify G-056 fix propagates to consumer via fw upgrade dry-run on /003-NTB-ATC-P
- `T-1386-bats-regression-test-for-g-056-resumemd-` — Bats regression test for G-056 resume.md drift-refresh — invariant protection fo
- `T-1394-audit-trend-analysis-never-decays--histo` — Audit trend analysis never decays — historical WARN/FAIL counted forever even wh
- `T-1396-pre-push-audit-shows-pre-t-1394-lifetime` — pre-push audit shows pre-T-1394 lifetime trend despite fix on HEAD
- `T-1402-rca-auditsh-python-traceback-at-line-108` — RCA audit.sh python traceback at line 108 — NoneType replace
- `T-1408-fix-11-stale-csrfexempt-tests-in-webtest` — Fix 11 stale csrf_exempt tests in web/test_app.py — T-1343 removed /api/* exempt
- `T-1409-g-058-fix-1n--handoverpushtimeoutbats-ex` — G-058 fix 1/N — handover_push_timeout.bats expects stale default 15s, T-1341 bum
- `T-1410-g-058-fix-2n--t-1376-verification-grep-i` — G-058 fix 2/N — T-1376 verification grep is inverted (passes when bug present, b
- `T-1411-g-058-fix-3n--t-663-verification-asserts` — G-058 fix 3/N — T-663 verification asserts 'bin/fw ' prefix but hooks use absolu
- `T-1412-g-058-fix-4n--t-1279-verification-calls-` — G-058 fix 4/N — T-1279 verification calls full audit (slow + 20s sweep timeout);
- ... +55 more in last 30 days

## H2 — Learning IDs referenced across ≥3 tasks within 30 days

- `P-011` — referenced by 342 tasks: T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f …
- `L-291` — referenced by 202 tasks: T-1518-approvals-page-surface-deferred-inceptio, T-1521-extend-fw-doctor-vendor-drift-glob-to-co, T-1522-self-lock-in-handoversh-to-prevent-concu, T-1523-update-tasksh-git-stage-both-sides-of-ac, T-1524-t-1523-throwaway-test …
- `L-387` — referenced by 156 tasks: T-1828-github-mirror-stalled--version-tag-reset, T-1851-deprecate-constituenttasks-field-t-new-4, T-1852-lifecycle-state-machine-add-draft--aband, T-1853-watchtower-arcs-lifecycle-filter-tabs-t-, T-1854-fw-arc-abandon-cli-verb-t-new-6 …
- `P-010` — referenced by 139 tasks: T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f …
- `L-398` — referenced by 59 tasks: T-1887-ship-t-1886-rca-candidate-a--task-templa, T-1887-ship-t-1886-rca-candidate-a--task-templa, T-1887-ship-t-1886-rca-candidate-a--task-templa, T-1887-ship-t-1886-rca-candidate-a--task-templa, T-1887-ship-t-1886-rca-candidate-a--task-templa …
- `L-006` — referenced by 54 tasks: T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou …
- `L-001` — referenced by 38 tasks: T-011-define-practice-graduation-criteria, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le …
- `L-332` — referenced by 35 tasks: T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1630-b-4-t-1626-sessionstart-hook-self-test--, T-1944-extract-cron-drift-python-heredoc-to-lib …
- `PL-007` — referenced by 24 tasks: T-1141-pickup-pl-007-never-dump-terminal-comman, T-1141-pickup-pl-007-never-dump-terminal-comman, T-1141-pickup-pl-007-never-dump-terminal-comman, T-1146-pickup-critical-rca-agent-command-amnesi, T-1146-pickup-critical-rca-agent-command-amnesi …
- `L-293` — referenced by 23 tasks: T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1528-t-1528-defensive-h2-terminator-on-recomm …
- `L-364` — referenced by 18 tasks: T-1720-reviewer-audit-cron-silent-failure-5-day, T-1720-reviewer-audit-cron-silent-failure-5-day, T-1766-render-surface-human-ac-gate--block-work, T-1766-render-surface-human-ac-gate--block-work, T-1767-fix-escalation-scan-v05-cron-deploy-gap- …
- `L-408` — referenced by 18 tasks: T-1942-fw-doctor-cron-registrygenerated-drift-c, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib …
- `L-390` — referenced by 16 tasks: T-1870-audit-check--completed-task-with-status-, T-1882-promote-ctl-028-status-drift-check-to-co, T-1882-promote-ctl-028-status-drift-check-to-co, T-1883-promote-ctl-012-unchecked-ac-check-to-co, T-1883-promote-ctl-012-unchecked-ac-check-to-co …
- `L-393` — referenced by 15 tasks: T-1849-task-arcid-field--tier-1-validation-bloc, T-1849-task-arcid-field--tier-1-validation-bloc, T-1850-tagsarc--arcid-one-shot-migration-t-new-, T-1850-tagsarc--arcid-one-shot-migration-t-new-, T-1851-deprecate-constituenttasks-field-t-new-4 …
- `L-392` — referenced by 14 tasks: T-1849-task-arcid-field--tier-1-validation-bloc, T-1849-task-arcid-field--tier-1-validation-bloc, T-1849-task-arcid-field--tier-1-validation-bloc, T-1849-task-arcid-field--tier-1-validation-bloc, T-1849-task-arcid-field--tier-1-validation-bloc …

## H3 — Bug-class with no RCA AND no learning captured

**Flagged:** 270 / 411 (65%)

This is the strongest symptom-fix signal: fix shipped, no root cause stated, no learning captured for next time.

## Self-application (Spike 3 — recursion test)

T-1548 (the inception that birthed this scan): bug_class=False has_rca=False learning_captured=True → flagged_by_H1=False

**Reading:** if T-1548 is flagged by H1, the heuristic correctly identifies even the meta-task itself as lacking an inline `## RCA` section — though its `docs/reports/T-1548-rca-escalation-structural.md` artifact carries the RCA. H1's blindness to artifact files is a known limitation, addressable in v1 by also scanning `docs/reports/T-XXX-*.md`.

## Headline numbers

| Metric | Value |
|---|---|
| Total completed tasks | 1849 |
| Bug-class tasks | 411 (22%) |
| H1 flagged | 337 |
| H2 repeat-learning patterns | 92 |
| H3 flagged (strongest signal) | 270 |
| Last-30-days bug-class | 80 |

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
