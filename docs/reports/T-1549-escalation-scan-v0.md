# T-1549 — Layer B v0 Heuristic Scan Results

**Run:** 2026-10-29T04:23:03.246112+00:00
**Corpus:** 4008 completed tasks
**Bug-class identified:** 737 (18%)

## H1 — Bug-class tasks with no `## RCA` section

**Flagged:** 487 / 737 bug-class tasks (66%)

**Last 30 days sample (FP triage candidates):**

- `T-3571-arc-closure-cards-fix-the-reviewers-ambe` — arc closure cards: fix the reviewer's amber findings on T-3552/T-3553 (invisible
- `T-3598-budget-gate-cache-shared-across-sessions` — Budget gate cache shared across sessions
- `T-3606-fw-sessions-broken-agentssessionsclaude-` — fw sessions broken: agents/sessions/claude-code/list.sh committed without exec
- `T-3607-fw-resume-status-crashes-when-an-active-` — fw resume status crashes when an active task name contains a pipe
- `T-3617-sidecar-inbox-hook-not-mirrored-into-con` — sidecar-inbox hook not mirrored into consumer init template nor allowlisted
- `T-3626-auditsh-schedule-install-delegates-fw-cr` — audit.sh schedule install delegates fw cron install into the cwd project, not
- `T-3628-fw-pickup-send-without---remote-delivers` — fw pickup send without --remote delivers nothing and does not say so; ID counter
- `T-3629-claude-fw-fresh-restart-with-empty-claud` — claude-fw fresh restart with empty CLAUDE_ARGS lands Claude Code 2.1.28x in
- `T-3633-claude-fw-two-loop-exit-paths-record-the` — claude-fw: two loop exit paths record the same reason max-restarts
- `T-3640-priority-tier-0-check-tier0sh-blocks-onl` — PRIORITY Tier 0: check-tier0.sh blocks only 'pkill -9' — every other SIGKILL
- `T-3642-reviewer-destructive-action-escalation-f` — Reviewer destructive-action escalation fires on negated safety guarantees ('can
- `T-3647-claude-fw-leaks-its-claude-master-termli` — claude-fw leaks its claude-master TermLink registration on every exit (055
- `T-3648-claude-fw-ends-a-live-agent-on-one-faile` — claude-fw ends a live agent on ONE failed termlink ping (055 P-011/P-012, 10
- `T-3650-unit-suite-audit-line-hard-codes-testsun` — Unit-suite audit line hard-codes '(tests/unit)' instead of the report's own
- `T-3660-fw-serve--watchtowersh-does-not-detach-w` — fw serve / watchtower.sh does not detach: Watchtower dies with its launching
- `T-3661-fw-watchtower-status-exits-0-when-watcht` — fw watchtower status exits 0 when Watchtower is stopped (P-01 WSL F-25)
- `T-3665-native-windows-a-crlf-checkout-silently-` — Native Windows: a CRLF checkout silently disables the secret scan (P-01 Win
- `T-3673-consumer-projects-never-get-the-sidecar-` — Consumer projects never get the sidecar-sweep cron: init's cron-registry seed
- `T-3709-dispatch-route-cache-silently-picks-haik` — Dispatch route cache silently picks haiku for build work: _route_cache_query_bes
- `T-3712-fw-upgrade-step-5-reports-partial-missin` — fw upgrade step 5 reports PARTIAL missing hooks (check-paid-backend, check-workt
- `T-3714-upgrading-a-consumer-from-a-bleeding-edg` — Upgrading a consumer from a bleeding-edge clone: shallow clone refused as foreig
- `T-3715-after-fw-upgrade-a-restarted-claude-code` — After fw upgrade, a restarted Claude Code fleet agent stalls on the New MCP
- `T-3718-testt3657acknowledgedrefusalspy-4-reds-a` — test_t3657_acknowledged_refusals.py 4 reds (acknowledged refused verdict rows:
- `T-3719-four-single-unit-reds-onboardingcurricul` — Four single unit reds: onboarding_curriculum_ungated (1), t3113_upgrade_worktree
- `T-3740-post-commit-fabric-advisory-loops-every-` — post-commit fabric advisory loops every changed file over every fabric card
- ... +94 more in last 30 days

## H2 — Learning IDs referenced across ≥3 tasks within 30 days

- `P-011` — referenced by 5826 tasks: T-100143-c2-doctoraudit-branch-hygiene-warns, T-100143-c2-doctoraudit-branch-hygiene-warns, T-100144-c3-handover-surfaces-branch-aheadbehind-, T-100144-c3-handover-surfaces-branch-aheadbehind-, T-100157-fw-doctor-calls-fwconsumeryamls-defined- …
- `L-387` — referenced by 5459 tasks: T-100142-c1-fw-integrate-run-deletes-landed-sourc, T-100143-c2-doctoraudit-branch-hygiene-warns, T-100143-c2-doctoraudit-branch-hygiene-warns, T-100143-c2-doctoraudit-branch-hygiene-warns, T-100144-c3-handover-surfaces-branch-aheadbehind- …
- `L-291` — referenced by 2284 tasks: T-100143-c2-doctoraudit-branch-hygiene-warns, T-100144-c3-handover-surfaces-branch-aheadbehind-, T-100157-fw-doctor-calls-fwconsumeryamls-defined-, T-100158-integrate-run-zone-3-go-live-line-refere, T-100159-reviewer-disposition-detector-truncates- …
- `L-398` — referenced by 1950 tasks: T-100143-c2-doctoraudit-branch-hygiene-warns, T-100144-c3-handover-surfaces-branch-aheadbehind-, T-100157-fw-doctor-calls-fwconsumeryamls-defined-, T-100158-integrate-run-zone-3-go-live-line-refere, T-100159-reviewer-disposition-detector-truncates- …
- `P-010` — referenced by 1351 tasks: T-100185-createtaskbats-inception-tests-fail-unde, T-100190-auditsh-metrics-history-writer-non-atomi, T-100191-sweep-atomic-write-pattern-for-all-conte, T-100196-safe-go-live-path-reconciling-fw-go-live, T-1101-inception-fw-inception-decide-silent---f …
- `L-399` — referenced by 116 tasks: T-100202-task-id-allocator-inflation--split-view-, T-1895-template--claudemd-reviewer-example-for-, T-1908-safe-commandssh-env-var-prefix-breaks-fw, T-1908-safe-commandssh-env-var-prefix-breaks-fw, T-1983-go-scope-traceability--inception-decisio …
- `P-013` — referenced by 64 tasks: T-1125-termlink-u-003-send-file-reports-ok-on-h, T-1125-termlink-u-003-send-file-reports-ok-on-h, T-1495-pickup-watchtower-discovery-watchtowerur, T-1763-fix-ac-body-parser--html-comment-example, T-1766-render-surface-human-ac-gate--block-work …
- `L-006` — referenced by 56 tasks: T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou …
- `L-001` — referenced by 55 tasks: T-011-define-practice-graduation-criteria, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le …
- `L-364` — referenced by 50 tasks: T-1720-reviewer-audit-cron-silent-failure-5-day, T-1720-reviewer-audit-cron-silent-failure-5-day, T-1766-render-surface-human-ac-gate--block-work, T-1766-render-surface-human-ac-gate--block-work, T-1767-fix-escalation-scan-v05-cron-deploy-gap- …
- `L-408` — referenced by 46 tasks: T-1942-fw-doctor-cron-registrygenerated-drift-c, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib …
- `P-002` — referenced by 40 tasks: T-001-define-success-metrics, T-001-define-success-metrics, T-004-install-pre-commit-hook-for-task-enforce, T-011-define-practice-graduation-criteria, T-014-improve-audit-agent-to-measure-quality-n …
- `L-332` — referenced by 38 tasks: T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1630-b-4-t-1626-sessionstart-hook-self-test--, T-1944-extract-cron-drift-python-heredoc-to-lib …
- `L-390` — referenced by 36 tasks: T-1870-audit-check--completed-task-with-status-, T-1882-promote-ctl-028-status-drift-check-to-co, T-1882-promote-ctl-028-status-drift-check-to-co, T-1883-promote-ctl-012-unchecked-ac-check-to-co, T-1883-promote-ctl-012-unchecked-ac-check-to-co …
- `L-533` — referenced by 34 tasks: T-2730-reviewer-crashes-with-reerror-bad-escape, T-2730-reviewer-crashes-with-reerror-bad-escape, T-2731-episodic-generator-breaks-yaml-when-task, T-2731-episodic-generator-breaks-yaml-when-task, T-2735-fabric-coverage-audit-check-is-cwd-depen …

## H3 — Bug-class with no RCA AND no learning captured

**Flagged:** 265 / 737 (35%)

This is the strongest symptom-fix signal: fix shipped, no root cause stated, no learning captured for next time.

## Self-application (Spike 3 — recursion test)

T-1548 (the inception that birthed this scan): bug_class=False has_rca=False learning_captured=True → flagged_by_H1=False

**Reading:** if T-1548 is flagged by H1, the heuristic correctly identifies even the meta-task itself as lacking an inline `## RCA` section — though its `docs/reports/T-1548-rca-escalation-structural.md` artifact carries the RCA. H1's blindness to artifact files is a known limitation, addressable in v1 by also scanning `docs/reports/T-XXX-*.md`.

## Headline numbers

| Metric | Value |
|---|---|
| Total completed tasks | 4008 |
| Bug-class tasks | 737 (18%) |
| H1 flagged | 487 |
| H2 repeat-learning patterns | 179 |
| H3 flagged (strongest signal) | 265 |
| Last-30-days bug-class | 119 |

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
