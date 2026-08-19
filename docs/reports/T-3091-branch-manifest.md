# T-3091 — Stranded branch triage: recovery manifest and salvage verdicts

Generated against HEAD `d879e40c5` (t2539-staging), origin/master `10663c1d4`.

## Why fifteen branches stranded

Every branch below forked from a commit that **was** on master (2026-03-01 … 2026-07-07).
Master then advanced to 2026-08-14. None was ever brought forward.

That is the whole mechanism. The sanctioned landing path — `fw integrate run master --push` —
is **fast-forward-only**, and a FF requires the branch to be a descendant of master. The moment
master passes a branch's fork point, the branch becomes unlandable by the only sanctioned route.
Nothing rebases it forward, nothing caps the widening fork, nothing escalates. It just stops
being landable and stays that way.

`lib/branch-hygiene.sh` does detect this — it reports seven of these right now as
`behind-threshold` / `diverged-fork`, at 1400–7100 commits over a threshold of 50. Detection has
never been the missing piece. Nothing consumes the finding.

**The headline correction.** The first pass of this triage classified three branches as dead
because no commit on them touched `lib/ bin/ agents/ web/ tests/ policy/`. That filter excluded
`docs/`, `CLAUDE.md` and `.fabric/`, and all three turned out to carry content that is absent
from master — including `docs/reports/T-2505-worktree-usage-policy.md`, an inception artifact
that diagnoses *this exact failure* (all-or-nothing FF landing, stranded worktree divergence)
and has been stranded since 2026-07-01. **This is not pollution. It is unlanded work.** Only the
four patch-id-identical refs are genuinely dead.

## Recovery manifest

Tip SHA recorded **before** any deletion. Any pruned ref is restorable with `git branch <name> <sha>`; the four dead refs are additionally pinned by local tags `strand-backup/*` so their objects survive gc.

| Branch | Tip SHA | Last commit | Unlanded | Fork point | Verdict |
|---|---|---|---|---|---|
| `audit-remediation-t2416` | `39979bb26` | 2026-06-26 | 1 | 2026-06-16 | **KEEP** — carries absent content |
| `learning/precompact-cleanup` | `1e8f10c9f` | 2026-03-02 | 1 | 2026-03-01 | **KEEP** — carries absent content |
| `t2353-audit-emit-tasks` | `b508ceef1` | 2026-06-27 | 22 | 2026-06-16 | **KEEP** — carries absent content |
| `t2417-fw-sessions` | `f7f4419e1` | 2026-07-02 | 58 | 2026-06-16 | **KEEP** — carries absent content |
| `t2511-warn-remediation` | `3c2c2c4d0` | 2026-07-07 | 1 | 2026-07-07 | **KEEP** — carries absent content |
| `worktree-inception-gov-payload-mediation` | `f59472365` | 2026-07-01 | 6 | 2026-07-01 | **KEEP** — carries absent content |
| `worktree-rca-worktree-push-strand` | `ec56fe61e` | 2026-07-01 | 37 | 2026-06-16 | **KEEP** — carries absent content |
| `origin/fix/T-002-governance-activation-gap` | `b2788a8a8` | 2026-03-12 | 0 | 2026-03-12 | **DEAD** — patch-id identical, safe to prune |
| `origin/fix/T-003-auto-onboarding-tasks` | `513aaed6c` | 2026-03-12 | 0 | 2026-03-12 | **DEAD** — patch-id identical, safe to prune |
| `origin/main` | `19fbda301` | 2026-05-15 | 0 | 2026-05-15 | **DEAD** — patch-id identical, safe to prune |
| `origin/t100199-close` | `cdae32061` | 2026-07-06 | 0 | 2026-07-05 | **DEAD** — patch-id identical, safe to prune |
| `origin/learning/precompact-cleanup` | `1e8f10c9f` | 2026-03-02 | 1 | 2026-03-01 | **KEEP** — carries absent content |
| `origin/t2416-fw-safe-mode-hook-timing` | `da6d383d1` | 2026-07-05 | 202 | 2026-06-16 | **KEEP** — carries absent content |
| `origin/t2417-fw-sessions` | `78727efa8` | 2026-07-02 | 48 | 2026-06-16 | **KEEP** — carries absent content |
| `origin/worktree-inception-gov-payload-mediation` | `2d108af23` | 2026-07-01 | 3 | 2026-07-01 | **KEEP** — carries absent content |

## Prune executed — 2026-08-20

The four patch-id-dead refs were deleted from `origin`:

```
origin/fix/T-002-governance-activation-gap   b2788a8a8
origin/fix/T-003-auto-onboarding-tasks       513aaed6c
origin/main                                  19fbda301
origin/t100199-close                         cdae32061
```

Each is restorable — the objects are pinned by local tags `strand-backup/<name>`, verified
resolving to the SHAs above after deletion. To restore one:

```
git branch <name> refs/tags/strand-backup/<name> && git push origin <name>
```

No branch carrying a `NEW-FILE` or `SALVAGE` verdict was touched. All eleven keep-branches
verified present after the prune.

## Salvage verdicts

Method: for every file a branch changed relative to its fork point, take the lines the branch
*added* and count how many appear verbatim in HEAD's copy of that file. `LANDED` = all present.
`SALVAGE` = none present. `PARTIAL` = some (usually HEAD edited the same region later — needs a
human read, not a mechanical verdict). `NEW-FILE` = the file does not exist on HEAD at all.

`.context/`, `.tasks/` and `.agentic-framework/` are excluded throughout: they are session
bookkeeping and vendored copies, they are the bulk of the commit volume, and landing them would
conflict on every file for no gain. On `origin/t2416-fw-safe-mode-hook-timing`, 187 of 204
commits are exactly that churn.

Totals across the eleven keep-branches: **51 NEW-FILE, 19 SALVAGE, 147 PARTIAL, 235 LANDED** (local/remote pairs double-count).

### NEW-FILE — absent from master entirely

| File | On branch |
|---|---|
| `.fabric/components/lib-audit_emit.yaml` | `t2353-audit-emit-tasks` |
| `.fabric/components/tools-escalation-rule-lifecycle.yaml` | `t2417-fw-sessions`, `origin/t2417-fw-sessions` |
| `.fabric/components/tools-escalation_narrowing_detector.yaml` | `t2417-fw-sessions` |
| `.fabric/components/tools-escalation_rule_generator.yaml` | `t2417-fw-sessions`, `origin/t2417-fw-sessions` |
| `.fabric/components/web-templates-escalation_rules.yaml` | `t2417-fw-sessions` |
| `.pickup/070-fw-update-vendored-vs-git-dispatch.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `.pickup/071-fw-help-newproject-unsolicited-mutation.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `.pickup/072-reviewer-fails-open-catalogue-missing.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `.pickup/073-reviewer-assisted-inception-decides.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `.pickup/074-reviewer-disposition-detector-two-defects.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `.pickup/resolved/060-fix-syspath-file-stdin-heredoc.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `docs/reports/DISCOVERY-autonomous-mode-2026-06-16.md` | `t2417-fw-sessions`, `origin/t2417-fw-sessions` |
| `docs/reports/DISCOVERY-governance-test-audit-2026-06-21.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `docs/reports/T-100066-ctl-029-false-positive-class.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `docs/reports/T-100139-branch-worktree-lifecycle.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `docs/reports/T-100140-watchtower-livelock-rca.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `docs/reports/T-100186-reviewer-assisted-inception-decides.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `docs/reports/T-1687-grilling-findings-telemetry-truncation.md` | `t2417-fw-sessions`, `origin/t2417-fw-sessions` |
| `docs/reports/T-1687-worker-01-heuristic-rules.md` | `t2417-fw-sessions`, `origin/t2417-fw-sessions` |
| `docs/reports/T-1687-worker-02-orchestrator-integration.md` | `t2417-fw-sessions`, `origin/t2417-fw-sessions` |
| `docs/reports/T-1687-worker-03-feedback-loop.md` | `t2417-fw-sessions`, `origin/t2417-fw-sessions` |
| `docs/reports/T-1687-worker-04-false-positives.md` | `t2417-fw-sessions`, `origin/t2417-fw-sessions` |
| `docs/reports/T-2416-llm-integration-diagnosis.md` | `t2353-audit-emit-tasks` |
| `docs/reports/T-2425-inbox-triage.md` | `origin/t2416-fw-safe-mode-hook-timing` |
| `docs/reports/T-2505-worktree-usage-policy.md` | `worktree-inception-gov-payload-mediation`, `origin/worktree-inception-gov-payload-mediation` |
| `lib/audit_emit.sh` | `t2353-audit-emit-tasks` |
| `tests/playwright/test_approvals_bvp_proposals_section.py` | `t2353-audit-emit-tasks` |
| `tests/unit/liveness_watchdog.bats` | `origin/t2416-fw-safe-mode-hook-timing` |
| `tests/unit/test_approvals_bvp_proposals.py` | `t2353-audit-emit-tasks` |
| `tests/unit/test_ask_proxy_routing.py` | `t2353-audit-emit-tasks` |
| `tests/unit/test_audit_emit_tasks.bats` | `t2353-audit-emit-tasks`, `t2417-fw-sessions`, `origin/t2416-fw-safe-mode-hook-timing`, `origin/t2417-fw-sessions` |
| `tests/unit/test_task_cache_t100140.py` | `origin/t2416-fw-safe-mode-hook-timing` |
| `tools/escalation-rule-generator.py` | `t2417-fw-sessions` |
| `tools/escalation-rule-lifecycle.py` | `t2417-fw-sessions`, `origin/t2417-fw-sessions` |
| `tools/escalation_narrowing_detector.py` | `t2417-fw-sessions` |
| `tools/escalation_rule_generator.py` | `t2417-fw-sessions`, `origin/t2417-fw-sessions` |
| `web/templates/escalation_rules.html` | `t2417-fw-sessions` |

### SALVAGE — file exists on master, none of the branch's added lines are there

| File | On branch | Added lines present on HEAD |
|---|---|---|
| `CLAUDE.md` | `audit-remediation-t2416` | 0/1 |
| `agents/context/budget-gate.sh` | `learning/precompact-cleanup` | 0/2 |
| `CLAUDE.md` | `t2353-audit-emit-tasks` | 0/1 |
| `bin/fw` | `t2353-audit-emit-tasks` | 0/2 |
| `CLAUDE.md` | `t2417-fw-sessions` | 0/4 |
| `VERSION` | `t2417-fw-sessions` | 0/1 |
| `agents/context/check-task-ac-structure.sh` | `t2417-fw-sessions` | 0/1 |
| `docs/reports/T-1549-escalation-scan-v0.md` | `t2417-fw-sessions` | 0/20 |
| `CLAUDE.md` | `origin/t2416-fw-safe-mode-hook-timing` | 0/1 |
| `VERSION` | `origin/t2416-fw-safe-mode-hook-timing` | 0/1 |
| `agents/task-create/create-task.sh` | `origin/t2416-fw-safe-mode-hook-timing` | 0/33 |
| `agents/task-create/update-task.sh` | `origin/t2416-fw-safe-mode-hook-timing` | 0/6 |
| `docs/reports/T-1549-escalation-scan-v0.md` | `origin/t2416-fw-safe-mode-hook-timing` | 0/22 |
| `metrics.sh` | `origin/t2416-fw-safe-mode-hook-timing` | 0/9 |
| `CLAUDE.md` | `origin/t2417-fw-sessions` | 0/4 |
| `VERSION` | `origin/t2417-fw-sessions` | 0/1 |
| `agents/context/check-task-ac-structure.sh` | `origin/t2417-fw-sessions` | 0/1 |
| `docs/reports/T-1549-escalation-scan-v0.md` | `origin/t2417-fw-sessions` | 0/20 |
| `agents/context/budget-gate.sh` | `origin/learning/precompact-cleanup` | 0/2 |

### PARTIAL — needs a human read

147 rows. These are files where HEAD edited the same region after the branch forked, so a
mechanical verdict is not trustworthy in either direction. They are not enumerated here; the
raw classification is reproducible with the script recorded in this task's Decisions.

