# T-1549 — Layer B v0 Heuristic Scan Results

**Run:** 2026-08-11T03:23:02.062631+00:00
**Corpus:** 2563 completed tasks
**Bug-class identified:** 489 (19%)

## H1 — Bug-class tasks with no `## RCA` section

**Flagged:** 359 / 489 bug-class tasks (73%)

**Last 30 days sample (FP triage candidates):**

- `T-100202-task-id-allocator-inflation--split-view-` — Task-ID allocator inflation + split-view collision RCA (T-100xxx band, audit-emi
- `T-2580-testsweb-full-dir-run-has-8-order-depend` — tests/web full-dir run has 8 order-dependent failures (all inception decide/verd
- `T-2581-extractrecommendation-verdict-regex-lost` — extract_recommendation verdict regex lost NO_GO underscore tolerance (T-1575 con
- `T-2583-reviewer-skip-as-pass-detector-false-pos` — Reviewer skip-as-pass detector false-positive: it matches the RCA-template
- `T-2612-handoff-jump-regression-uuid-form-corpus` — handoff jump regression: uuid-form corpus + 0.3.1 no auto-resolve — operator-sur
- `T-2613-aef-audit-cron-warnfail-connector-unwire` — aef-audit-cron warn/fail connector unwired — corpus sweep for unlinked handoff-i
- `T-2615-re-pin-designer-032-t-240-uuid-auto-reso` — re-pin designer 0.3.2 (T-240 uuid auto-resolve hotfix) — flag flip + alias
- `T-2628-corpus-squash-burst-rca--operator-delete` — Corpus squash burst RCA — operator delete-all+resave regressed task-lifecycle
- `T-2676-fix-harvestsh-indent-assumption-greps-de` — fix harvest.sh indent-assumption greps (dead learnings/patterns sub-stages)
- `T-2677-fix-dead-audit-graduation-counter-learni` — fix dead audit graduation counter (learnings >=20 branch never fires)
- `T-2685-fix-corpus-explain-rail-arity-drift-sile` — fix corpus explain rail arity drift silently downgrading authority stage (OBS-10
- `T-2724-fw-init-reports-19-broken-hooks-on-a-cor` — fw init reports 19 broken hooks on a correct install — validator never expands C
- `T-2733-t-1550-rca-gate-invalidated-pre-existing` — T-1550 RCA gate invalidated pre-existing test fixtures, red since May
- `T-2740-greenfield-seed-tasks-fail-fw-audit-on-a` — greenfield seed tasks fail fw audit on a freshly initialised project
- `T-2792-fresh-install-onboarding-path-broken-mak` — Fresh-install onboarding path broken: make the new-project prompt work end
- `T-2830-work-on-switch-focus-fails-silently` — fw work-on --switch-focus fails silently (RC=1, zero output)
- `T-2886-vendor-sync--push-t-2885-budget-gauge-fi` — vendor sync + push T-2885 budget gauge fix

## H2 — Learning IDs referenced across ≥3 tasks within 30 days

- `P-011` — referenced by 1780 tasks: T-100143-c2-doctoraudit-branch-hygiene-warns, T-100143-c2-doctoraudit-branch-hygiene-warns, T-100144-c3-handover-surfaces-branch-aheadbehind-, T-100144-c3-handover-surfaces-branch-aheadbehind-, T-100157-fw-doctor-calls-fwconsumeryamls-defined- …
- `L-387` — referenced by 1588 tasks: T-100142-c1-fw-integrate-run-deletes-landed-sourc, T-100143-c2-doctoraudit-branch-hygiene-warns, T-100143-c2-doctoraudit-branch-hygiene-warns, T-100143-c2-doctoraudit-branch-hygiene-warns, T-100144-c3-handover-surfaces-branch-aheadbehind- …
- `L-291` — referenced by 895 tasks: T-100143-c2-doctoraudit-branch-hygiene-warns, T-100144-c3-handover-surfaces-branch-aheadbehind-, T-100157-fw-doctor-calls-fwconsumeryamls-defined-, T-100158-integrate-run-zone-3-go-live-line-refere, T-100159-reviewer-disposition-detector-truncates- …
- `L-398` — referenced by 663 tasks: T-100143-c2-doctoraudit-branch-hygiene-warns, T-100144-c3-handover-surfaces-branch-aheadbehind-, T-100157-fw-doctor-calls-fwconsumeryamls-defined-, T-100158-integrate-run-zone-3-go-live-line-refere, T-100159-reviewer-disposition-detector-truncates- …
- `P-010` — referenced by 336 tasks: T-100185-createtaskbats-inception-tests-fail-unde, T-100190-auditsh-metrics-history-writer-non-atomi, T-100191-sweep-atomic-write-pattern-for-all-conte, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f …
- `L-399` — referenced by 77 tasks: T-100202-task-id-allocator-inflation--split-view-, T-1895-template--claudemd-reviewer-example-for-, T-1908-safe-commandssh-env-var-prefix-breaks-fw, T-1908-safe-commandssh-env-var-prefix-breaks-fw, T-1983-go-scope-traceability--inception-decisio …
- `L-006` — referenced by 56 tasks: T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou …
- `L-001` — referenced by 51 tasks: T-011-define-practice-graduation-criteria, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le …
- `L-364` — referenced by 40 tasks: T-1720-reviewer-audit-cron-silent-failure-5-day, T-1720-reviewer-audit-cron-silent-failure-5-day, T-1766-render-surface-human-ac-gate--block-work, T-1766-render-surface-human-ac-gate--block-work, T-1767-fix-escalation-scan-v05-cron-deploy-gap- …
- `L-332` — referenced by 36 tasks: T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1630-b-4-t-1626-sessionstart-hook-self-test--, T-1944-extract-cron-drift-python-heredoc-to-lib …
- `L-408` — referenced by 31 tasks: T-1942-fw-doctor-cron-registrygenerated-drift-c, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib …
- `P-013` — referenced by 28 tasks: T-1125-termlink-u-003-send-file-reports-ok-on-h, T-1125-termlink-u-003-send-file-reports-ok-on-h, T-1495-pickup-watchtower-discovery-watchtowerur, T-1763-fix-ac-body-parser--html-comment-example, T-1766-render-surface-human-ac-gate--block-work …
- `P-002` — referenced by 25 tasks: T-001-define-success-metrics, T-001-define-success-metrics, T-004-install-pre-commit-hook-for-task-enforce, T-011-define-practice-graduation-criteria, T-014-improve-audit-agent-to-measure-quality-n …
- `PL-007` — referenced by 24 tasks: T-1141-pickup-pl-007-never-dump-terminal-comman, T-1141-pickup-pl-007-never-dump-terminal-comman, T-1141-pickup-pl-007-never-dump-terminal-comman, T-1146-pickup-critical-rca-agent-command-amnesi, T-1146-pickup-critical-rca-agent-command-amnesi …
- `L-293` — referenced by 23 tasks: T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1528-t-1528-defensive-h2-terminator-on-recomm …

## H3 — Bug-class with no RCA AND no learning captured

**Flagged:** 265 / 489 (54%)

This is the strongest symptom-fix signal: fix shipped, no root cause stated, no learning captured for next time.

## Self-application (Spike 3 — recursion test)

T-1548 (the inception that birthed this scan): bug_class=False has_rca=False learning_captured=True → flagged_by_H1=False

**Reading:** if T-1548 is flagged by H1, the heuristic correctly identifies even the meta-task itself as lacking an inline `## RCA` section — though its `docs/reports/T-1548-rca-escalation-structural.md` artifact carries the RCA. H1's blindness to artifact files is a known limitation, addressable in v1 by also scanning `docs/reports/T-XXX-*.md`.

## Headline numbers

| Metric | Value |
|---|---|
| Total completed tasks | 2563 |
| Bug-class tasks | 489 (19%) |
| H1 flagged | 359 |
| H2 repeat-learning patterns | 146 |
| H3 flagged (strongest signal) | 265 |
| Last-30-days bug-class | 17 |

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
