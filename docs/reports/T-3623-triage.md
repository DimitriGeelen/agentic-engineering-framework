# T-3623 — OBS-587 triage C: 17 untriaged baselined red bats files

Scope: the 17 files named in the T-3623 description (baseline `.context/audits/unit-suite/baseline.yaml`,
T-3621, expiry 2026-10-15). The source report is the nightly run of 2026-10-01 (01:03Z–01:43Z, 12 parallel jobs).
Every file was re-run alone on HEAD (`bats tests/unit/<file>.bats`), main checkout, branch `bleeding-edge`.

`t3182_loop_exit_recorder.bats` appears in the task *title* range but not in the description list.
It is not triaged here.

## Summary

| Verdict | Files |
|---|---|
| STALE TEST, fixed | 13 files, 9 commits |
| CODE REGRESSION, filed | 2 files: T-3625 and T-3626 |
| ENVIRONMENT (green on HEAD in isolation) | 2 files |
| UNCLEAR | 0 |

## Per-file verdicts

| File | Failing tests (nightly baseline) | Breaking commit | Verdict | Action |
|---|---|---|---|---|
| context_safe_commands | 42 "no unclassified git verb is used by our own tooling" | e765d09ef (T-3594: `git send-pack` named in agents/git/lib/hooks.sh) | STALE TEST. The test asks for a decision on each new verb. `send-pack` pushes refs, so it mutates and belongs in the denylist. | 1370578fa |
| create_task | "T-100160: non-tty with ALL required flags…", "T-2543: promote-origin create…" | none found | ENVIRONMENT. 30/30 green on two isolated HEAD runs. Nothing touched the test or create-task.sh since the nightly. Nightly took 122s for this file under 12-way load. | none |
| cron_flock_parity | 1, 3, 5 (parity WARN / "Cron generated but not installed" missing) | 176445c64 (T-2812) | CODE REGRESSION. `fw doctor` (set -euo pipefail) dies with rc 128 at `hooks_dir=$(git … rev-parse --git-path hooks)` in a non-git project, before the cron checks. Bisect: 176445c64^ rc 0 (57 lines), 176445c64 rc 128 (7 lines). This was masked until the T-3610 fence (af7744b5b) stopped fixtures resolving to a repo above /tmp. | **T-3625** (test left red as the witness) |
| designer_sync_from_tag | 1, 2, 3, 4, 6 | 28c7a1bd3 (T-2649: pin read FRAMEWORK_ROOT-first) | STALE TEST (non-hermetic). The inherited `FRAMEWORK_ROOT` pointed designer.sh at the live pin. With `env -u FRAMEWORK_ROOT` everything is green. | 7a5534033 |
| designer_sync_sha256 | 1, 4 | 28c7a1bd3 | STALE TEST. Same cause, fixed with the sanctioned T-2547 hook `FW_DESIGNER_PIN_FILE`. | same commit |
| doctor_hook_exercise | 2, 3, 6 | test non-hermetic since written; exposed by the inherited `PROJECT_ROOT` and the af7744b5b fence | STALE TEST. bin/fw lets an inherited `PROJECT_ROOT` win over cwd, so doctor audited the live repo's settings.json (about 2 min per test, file timed out). With it unset, the non-git fixture hits T-3625. Fix: pin `PROJECT_ROOT` and `git init` the fixture, as a real consumer is a repo. Now 6/6 in 52s. | f9a735243 |
| fabric_coverage_single_source | "live coverage number equals the canonical expander's", "fully-carded project PASSes" | 92deaef0c (T-3105 `pass_over` wording); live leg anchored on mutable audit history | STALE TEST. (a) The PASS line now reads "all watched files registered — examined 1 watched file(s)". (b) The T-014 trend block echoes repeated "Fabric drift: N source file(s)" WARNs once history holds 3 or more, so the extraction got two numbers. Now it reads only the check line. One residual race: the 5-minute live audit can race concurrent card edits by other workers (observed once). | a52414df8 |
| hook_telemetry | 14 "missing-hook degrade-to-allow path records as failure" | b65d34d31 (T-3372 control leg) | STALE TEST (defective). `grep -c … \|\| echo 0` produces "0\n0" when the live counter has no bogus entry, so `[ -eq ]` errors. It went red once the live counter was cleaned. | 87d02ff7a |
| t1719_ask_routing | a3 "live ask writes a dispatch row…" / "…outcome row naming the route" | none found | ENVIRONMENT. 11/11 green on two isolated HEAD runs. These are live-ask legs that depend on backend availability and load at nightly time. No fixing commit in their paths. | none |
| t3066_driver_drop_identity | 3, 4, 5 | 491733d90 (T-3427: `--add` refuses unscored drivers) | STALE TEST. The scratch drivers have no scorer, so `--add` was refused before the drop-identity guard. `drv` now adds `--allow-unscored` to `--add`. | 08a8474fd |
| t3070_audit_schedule_install_delegates_to_registry | 1 "with a registry present … writes registry content" | d015460cb (T-3285 nested-fw re-anchor) | CODE REGRESSION. audit.sh sources lib/paths.sh, which sets `_FW_PATHS_DERIVED_BY`, then `exec fw cron install` without cd'ing to PROJECT_ROOT. bin/fw then re-anchors to the cwd project, so an explicit `PROJECT_ROOT=/x audit.sh schedule install` installs the cwd project's crontab and writes its `.context/cron/agentic-audit.crontab`. Bisect: d015460cb^ ok, d015460cb not ok. agents/audit/ is another worker's write-set, so it is not fixed here. | **T-3626** |
| t3073_c001_recommendation_bearing_inceptions | 10 "clean corpus passes with both population sizes named" | de5a1662e (T-3138 made the negated assertion bite) | STALE TEST. The T-194 WARN "has artifact but task doesn't reference it" has always fired on this fixture. The `! …` assertion could not fail until T-3138. Bisect: de5a1662e^ ok, de5a1662e not ok. The fixture now references its artefact. | a347c5e9d |
| t3095_audit_branch_hygiene | 8 "not a git repository: block is silent" | af7744b5b (T-3610 fence exists, not applied here) | STALE TEST (non-hermetic). A stray `/.git` (created 2026-09-30 22:30, still present) made `/tmp` fixtures resolve to `/`. Fix: `load ../git_fence`. | 7ff5d2925 |
| t3099_go_scope_structural | 1–6, 8–12 | 92deaef0c (T-3105), 60ea7f91f (T-3469), 5aa2d20e6 (T-3562) | STALE TEST. The runner lacked the T-3105 helpers `pass_over` / `warn_unenumerable`, which are now extracted from audit.sh. The headline wording, the overflow marker ("+N more candidate") and the mitigation text changed. An empty GO set is now WARN NOT EVALUATED, not PASS. The `python3 -c` count now also matches a comment inside the script. | 8a8c43560 |
| t3104_task_corpus_views | 3 "non-git directory falls back to TASKS_DIR alone" | af7744b5b | STALE TEST (non-hermetic, stray `/.git`) | 7ff5d2925 |
| t3112_worktree_hook_parity | 10 "non-git directory is unenumerable" | af7744b5b | STALE TEST (non-hermetic, stray `/.git`) | 7ff5d2925 |
| t3113_upgrade_worktree_advisory | 6 "non-git target reports unenumerable" | af7744b5b | STALE TEST (non-hermetic, stray `/.git`) | 7ff5d2925 |

## Commits (T-3623)

- 7ff5d2925: t3095 / t3104 / t3112 / t3113 (git fence)
- 8a8c43560: t3099_go_scope_structural
- 08a8474fd: t3066_driver_drop_identity
- 7a5534033 — designer_sync_sha256 + designer_sync_from_tag (FW_DESIGNER_PIN_FILE, unset FRAMEWORK_ROOT)
- 1370578fa: context_safe_commands
- a347c5e9d: t3073_c001_recommendation_bearing_inceptions
- 87d02ff7a: hook_telemetry
- f9a735243: doctor_hook_exercise
- a52414df8: fabric_coverage_single_source

## Isolation evidence for the fixed files (HEAD, alone, foreground)

All 0 `not ok`, 0 `# skip`: t3095 13/13, t3104, t3112 14/14, t3113 14/14, t3099 12/12, t3066 9/9,
designer_sync_sha256 4/4, designer_sync_from_tag 6/6, context_safe_commands 48/48, t3073, hook_telemetry 15/15,
doctor_hook_exercise 6/6.

fabric_coverage_single_source takes more than 10 minutes as a whole (three live `audit.sh --sections structure`
runs at about 5 minutes each), so it was run in slices:
- 12 non-live tests: ok in 11s.
- "live coverage number equals": ok, DRIFT=10 EXPECTED=10.
- "live audit reports exactly one coverage number": ok in the full-file run.

The live legs skip when another audit holds the lock. One skip was observed under concurrent workers.

## Cross-cutting findings for the parent

1. **Stray `/.git` is still on the host** (`drwxr-xr-x /.git`, 2026-09-30 22:30). T-3610 named it. Any bats file
   that doesn't load `git_fence` and expects "not a git repo" under /tmp stays red until the file is fenced or `/.git` is removed.
   Removing it is an operator action and was not done here.
2. **Inherited `FRAMEWORK_ROOT` / `PROJECT_ROOT`** leak into tests run from fw-launched shells (agent sessions,
   the nightly runner) and make fixtures read live state: designer pin, doctor settings. Other untriaged files may share this.
   `env -u FRAMEWORK_ROOT -u PROJECT_ROOT bats …` is a cheap discriminator.
3. T-3625 (doctor crash in non-git project) also makes doctor-driven fixtures pass `status -ne 0` checks for the wrong reason (rc 128).
