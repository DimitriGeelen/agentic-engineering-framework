# T-1549 — Layer B v0 Heuristic Scan Results

**Run:** 2026-06-06T03:23:01.565619+00:00
**Corpus:** 1986 completed tasks
**Bug-class identified:** 437 (22%)

## H1 — Bug-class tasks with no `## RCA` section

**Flagged:** 346 / 437 bug-class tasks (79%)

**Last 30 days sample (FP triage candidates):**

- `T-1813-audit-arc-completion-check-ignores-tag-t` — audit arc-completion check ignores tag-tagged tasks — uses constituent_tasks onl
- `T-1829-version-stamping-algorithm-not-cross-tag` — VERSION-stamping algorithm not cross-tag-monotonic — Level-C fix for T-1828 clas
- `T-1830-fw-upgrade-incident-2026-05-14-meta-rca-` — fw-upgrade-incident-2026-05-14 meta-RCA umbrella — boundary-crossing invisibilit
- `T-1831-ac-checkbox-vs-content-drift--agent-does` — AC-checkbox-vs-content drift — agent does substantive work in body, gate measure
- `T-1833-t-1736-spike-harvest-read-session-jsonls` — T-1736 spike harvest read session JSONLs outside PROJECT_ROOT — path-isolation v
- `T-1887-ship-t-1886-rca-candidate-a--task-templa` — ship T-1886 RCA Candidate A — task-template hint to remind .claude/settings.json
- `T-1888-ship-t-1886-rca-candidate-b--posttooluse` — ship T-1886 RCA Candidate B — PostToolUse nudge on .claude/settings.json edits t
- `T-1898-fix-double-render-on-arcsarc-005-and-5-s` — fix double-render on arcs/arc-005 and 2 sibling pages — templates extend base.ht
- `T-1899-renderpage-runtime-guard--refuse-templat` — render_page() runtime guard — refuse template that extends base.html with action
- `T-1900-update-tasksh-checkrendersurfacehumanac-` — update-task.sh check_render_surface_human_ac error path crashes with SIGPIPE (L-
- `T-1967-l-414-root-cause-fix-ac-parser-sed-range` — L-414 root-cause fix: AC parser sed-range comment strip swallows Agent ACs when 
- `T-1996-g-069-regression-discoverprojectroot-cli` — G-069 regression: _discover_project_root climbs past FRAMEWORK_ROOT to stray
- `T-2032-arc-007-settings-gear-in-top-bar-nav-to-` — arc-007 settings gear in top-bar nav to /settings/appearance
- `T-2037-t-1934-has-malformed-yaml-frontmatter--p` — T-1934 has malformed YAML frontmatter — parse error on every get_all_task_metada
- `T-2056-fix-stale-preset-nav-unit-tests--t-2011-` — Fix stale preset-nav unit tests + T-2011 verification after T-2033 human-decided
- `T-2133-t-2131-review-checkbox-click-silently-no` — T-2131 /review checkbox click silently no-ops — htmx:targetError on inherited
- `T-2135-playwright-regression-net-for-htmx-targe` — Playwright regression net for htmx targetError class — /review/<id> interactive
- `T-2138-rca-review-handoff-homework-pattern-recu` — RCA: review-handoff homework pattern recurs despite T-2030 GO — author-time
- `T-2143-rca--agent-reflexively-routes-prose-tone` — RCA — agent reflexively routes prose-tone judgment to Human AC even when audienc
- `T-2144-rca--agent-uses-defer-to-abdicate-adviso` — RCA — agent uses DEFER to abdicate advisory duty when evidence is complete

## H2 — Learning IDs referenced across ≥3 tasks within 30 days

- `P-011` — referenced by 590 tasks: T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f …
- `L-387` — referenced by 412 tasks: T-1828-github-mirror-stalled--version-tag-reset, T-1851-deprecate-constituenttasks-field-t-new-4, T-1852-lifecycle-state-machine-add-draft--aband, T-1853-watchtower-arcs-lifecycle-filter-tabs-t-, T-1854-fw-arc-abandon-cli-verb-t-new-6 …
- `L-291` — referenced by 332 tasks: T-1518-approvals-page-surface-deferred-inceptio, T-1521-extend-fw-doctor-vendor-drift-glob-to-co, T-1522-self-lock-in-handoversh-to-prevent-concu, T-1523-update-tasksh-git-stage-both-sides-of-ac, T-1524-t-1523-throwaway-test …
- `L-398` — referenced by 162 tasks: T-1887-ship-t-1886-rca-candidate-a--task-templa, T-1887-ship-t-1886-rca-candidate-a--task-templa, T-1887-ship-t-1886-rca-candidate-a--task-templa, T-1887-ship-t-1886-rca-candidate-a--task-templa, T-1887-ship-t-1886-rca-candidate-a--task-templa …
- `P-010` — referenced by 158 tasks: T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f, T-1101-inception-fw-inception-decide-silent---f …
- `L-006` — referenced by 54 tasks: T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou, T-1110-collapse-framework-enums-into-single-sou …
- `L-001` — referenced by 38 tasks: T-011-define-practice-graduation-criteria, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le, T-1258-rca-fw-context-add-learning-truncates-le …
- `L-332` — referenced by 35 tasks: T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1629-b-3-t-1626-hook-failure-escalation--thre, T-1630-b-4-t-1626-sessionstart-hook-self-test--, T-1944-extract-cron-drift-python-heredoc-to-lib …
- `L-364` — referenced by 26 tasks: T-1720-reviewer-audit-cron-silent-failure-5-day, T-1720-reviewer-audit-cron-silent-failure-5-day, T-1766-render-surface-human-ac-gate--block-work, T-1766-render-surface-human-ac-gate--block-work, T-1767-fix-escalation-scan-v05-cron-deploy-gap- …
- `PL-007` — referenced by 24 tasks: T-1141-pickup-pl-007-never-dump-terminal-comman, T-1141-pickup-pl-007-never-dump-terminal-comman, T-1141-pickup-pl-007-never-dump-terminal-comman, T-1146-pickup-critical-rca-agent-command-amnesi, T-1146-pickup-critical-rca-agent-command-amnesi …
- `P-013` — referenced by 23 tasks: T-1125-termlink-u-003-send-file-reports-ok-on-h, T-1125-termlink-u-003-send-file-reports-ok-on-h, T-1495-pickup-watchtower-discovery-watchtowerur, T-1763-fix-ac-body-parser--html-comment-example, T-1766-render-surface-human-ac-gate--block-work …
- `L-293` — referenced by 23 tasks: T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1527-l-293-audit--scan-section-rewriter-regex, T-1528-t-1528-defensive-h2-terminator-on-recomm …
- `L-417` — referenced by 23 tasks: T-1975-audit-stale-slice-reference-scan--flag-s, T-1975-audit-stale-slice-reference-scan--flag-s, T-1975-audit-stale-slice-reference-scan--flag-s, T-1975-audit-stale-slice-reference-scan--flag-s, T-1975-audit-stale-slice-reference-scan--flag-s …
- `L-441` — referenced by 22 tasks: T-1659-fw-fabric-register-accepts-agentic-frame, T-1659-fw-fabric-register-accepts-agentic-frame, T-1912-fw-upgrade-dovendor-step-4b-runs-before-, T-1912-fw-upgrade-dovendor-step-4b-runs-before-, T-1912-fw-upgrade-dovendor-step-4b-runs-before- …
- `L-408` — referenced by 21 tasks: T-1942-fw-doctor-cron-registrygenerated-drift-c, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib, T-1944-extract-cron-drift-python-heredoc-to-lib …

## H3 — Bug-class with no RCA AND no learning captured

**Flagged:** 270 / 437 (61%)

This is the strongest symptom-fix signal: fix shipped, no root cause stated, no learning captured for next time.

## Self-application (Spike 3 — recursion test)

T-1548 (the inception that birthed this scan): bug_class=False has_rca=False learning_captured=True → flagged_by_H1=False

**Reading:** if T-1548 is flagged by H1, the heuristic correctly identifies even the meta-task itself as lacking an inline `## RCA` section — though its `docs/reports/T-1548-rca-escalation-structural.md` artifact carries the RCA. H1's blindness to artifact files is a known limitation, addressable in v1 by also scanning `docs/reports/T-XXX-*.md`.

## Headline numbers

| Metric | Value |
|---|---|
| Total completed tasks | 1986 |
| Bug-class tasks | 437 (22%) |
| H1 flagged | 346 |
| H2 repeat-learning patterns | 106 |
| H3 flagged (strongest signal) | 270 |
| Last-30-days bug-class | 20 |

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
