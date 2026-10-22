# T-4575 — every red named in the 2026-10-21 cloud reports, mapped

Source: `docs/reports/T-4508-cloud-prompts/reports-2026-10-21-relayed-by-ring20.md` (reports 1–4).
T-4508 AC 2: every failure the reports name is known (baselined, filed) or filed.

**Method.** Each named red was checked against `.context/audits/unit-suite/baseline.yaml`,
the sibling tasks filed with this one (T-4568..T-4574) and open/completed tasks. Reds not
covered were re-run on 2026-10-22 in a clean clone of bleeding-edge `e785e48b9` under
`env -i HOME=<empty> PATH=/usr/local/bin:/usr/bin:/bin` (closest local match to the cloud
host: no Claude dirs, no crontab), one file at a time, in the foreground. T-4577..T-4580
were filed by the earlier worker on this task from the same kind of clean clone (`74e956894`).

Dispositions: **sibling** (T-4568..T-4574), **baseline** (entry + owner), **existing** task,
**filed** (new task from this mapping), **env** (host lacks software/state; not a defect),
**passes** (green on current bleeding-edge in the clean clone), **flaky** (passed alone).

## Report 1 — full suite at 6f60b69b5

| Red named | Disposition | Evidence / owner |
|---|---|---|
| bats 1.10 aborts `bats tests/unit/` (heredoc fixtures in t4058) | sibling T-4570 (completed) | |
| `tests/integration/fw_docs.bats`, `tests/unit/handover.bats` hang (rc=124 @900 s) | sibling T-4573 | |
| approvals_close_ready_arcs | baseline | 5 entries, owner T-3611, expires 2026-10-31 |
| budget_gate test 28 (.next-directive.yaml fold) | existing T-4577 | checkpoint.sh fold snippet IndentationError |
| test_framework_mcp_server (`No module named 'mcp'`) | env (py-mcp) | |
| `fw build -v` (npx esbuild) | sibling T-4572 | |
| test_inception_verdict_render: `_approvals_content.html:5` UndefinedError `decided_unclosed_count` | existing T-3898 | reproduced: 5 failed in clean clone |
| Playwright 41 failed (`/` scrollHeight, BLOCKED badge, .badge-ok contrast, editable review input, inception AC section) | sibling T-4574 | |
| lint fail=1 (file not named) | baseline (most likely) | `test_bin_fw_no_heredoc_cmd_sub.bats`, owner T-4221, fix task T-4581; not provable from the excerpt |
| governance fail=11, integration fail=31 (files not named in the excerpt) | see report 4 rows | only report 4 names governance files |
| Runner leaked CLAUDECODE=1 into tests | env (job's runner) | report says re-run without it changed very little |
| Container restart killed playwright | env | |
| Suite changed/deleted tracked files in the clone | filed T-4588 | |

## Report 2 — job 1, unit suite fast+slow at cc094b509

| Red named | Disposition | Evidence / owner |
|---|---|---|
| Missing modules: markdown2, ollama, ruamel.yaml, tantivy, bleach, `_cffi_backend` (77 of 89 pytest files) | env — job prompt fixed | `job1-clean-room-unit-suite.md` now runs `python3 -m pip install -r web/requirements.txt cffi …` (this task) |
| `pip install playwright` reached a different Python | env — job prompt fixed | prompt now says `python3 -m pip` |
| `playwright install --with-deps chromium` download failure | env — job prompt notes the pin | |
| 12 fast-tier files timed out under parallel load (lib_upstream, note_capture_guard, note_exit_status, revisit_undated_signal, t2459_mcp_server_root_split, t2924_update_task_owner_g…) | flaky (load) | all passed alone per the report |
| approvals_close_ready_arcs (5) | baseline | owner T-3611 |
| atomic_yaml_write_lint (1) | baseline | owner T-3612 |
| audit_ctl_arc_tag_only_pattern (rc=1, 0 not-ok) | passes | 9/9 ok in clean clone |
| bvp_auto_promote (5) | passes | 7/7 ok |
| lib_config_file (1) | passes | 22/22 ok |
| lib_costs (1) — test 3 `_costs_jsonl_dir uses pwd` | filed T-4583 | needs `~/.claude/projects/-<cwd>` on the host |
| t3062_prepush_runtime (1) — test 1 | env (fresh clone) | "structure checks did not execute"; the test deliberately measures the live repo with deployed cron (comment cites T-4401, completed); 239 s run |
| t3118_horizon_migration_scope (1) — test 8 | filed T-4584 | 9 completed tasks carry `horizon: now` (live corpus) |
| t3379_review_placeholder_foreign_port (3) | passes | 5/5 ok |
| t3388_ewcr_worked_procedure_fixture (4) | passes | 6/6 ok |
| t3644_literal_assignment_segment (2) | passes | 20/20 ok (also named in report 4; T-4536 completed) |
| slow: audit_inception_recommendation test 10 (FW_ALLOW_EMPTY_RECOMMENDATION bypass) | baseline | owner T-3609 |
| slow: bvp_auto_promote_enable test 7 (cron registry in sync) | env (cron) | asserts `fw doctor` "Cron registry in sync"; no crontab on the host |
| pytest test_extract_recommendation | passes | 32 passed |
| pytest test_govd_sandbox | existing T-4578 | 2 failed in clean clone: committed sandbox artefacts embed /opt path |
| pytest test_importer_fidelity | passes | 16 passed |
| pytest test_no_relative_fw_argv_t3952 | passes | 2 passed |
| pytest test_render_artefact_paths | passes | 19 passed |
| pytest test_t3649_render_extras_viewable | passes | 4 passed |
| Job's background waiter matched itself in `pgrep -f` | env (job script) | not repository code |

## Report 3 — job 2, fresh-machine upgrade v1.8.14 → cc094b509

| Red named | Disposition | Evidence / owner |
|---|---|---|
| `fw upgrade` leaves commit-msg / pre-push un-updated ("WARN Git hook installation failed") | sibling T-4568 | |
| T-4515 revives the dead project line (PROJECT-GATE-RAN on every commit) | sibling T-4569 | |
| Release v1.8.14 doctor false OK "index-reindex-hourly scheduled" with no cron entry | passes | report: the candidate correctly WARNs; release-only |
| Fresh-machine bats 5 not-ok (T-3835, T-3836, T-3831 x2, T-3833) on a detached-HEAD clone | filed T-4587 | `overlay_upstream` pushes `HEAD` with no branch; all 5 pass on a local branch |
| No `fw` on PATH / no `~/.local/bin/fw` shim | env (by design) | the shim comes from `install.sh`; `fw init`/`fw upgrade` only migrate an existing one (lib/upgrade.sh:2403) |

## Report 4 — follow-up, full suite at cc094b509

| Red named | Disposition | Evidence / owner |
|---|---|---|
| 325 classified items: env(git-hooks) 24, env(cryptography) 18, env(termlink) 10, env(ollama) 10, env(ss) 7, env(npm-deps) 5, env(claude-cli) 4, env(py-mcp) 3, env(cron) 2, env(systemd) 1 | env | |
| flaky 10 / 9 pytest pass alone (test_cockpit_activity, test_sidecar_cli_peer_frame test_alerts, test_t4458_search_degrade x2, tests.web.test_t4043_…) | flaky | passed alone per the report |
| hang 2 | sibling T-4573 | same two files as report 1 |
| defect 117 (per-item list lost) | covered only where named below | the list itself is unrecoverable (hidden-thinking failure) |
| `/settings/` PanicException (no `_cffi_backend`) | env (cryptography) | |
| `/api/v1/search` 503 | env (no vector index) | |
| `/file/docs/style-guide.md` 404 | sibling T-4571 | |
| `fw build`: esbuild cannot resolve js-yaml | sibling T-4572 | |
| t2436 vendor `--check` vs `--dry-run` disagree | filed T-4585 | reproduced: red whenever HEAD has unrelated vendor drift |
| t3661 watchtower status uses `ss` | env (ss) | |
| t3644 literal-assignment SAFE cases | passes | 20/20 ok |
| governance test_pretooluse_gates 6/12 | existing T-4579 | hard-coded /opt path |
| governance test_register_requirements_gate 1/4/5 | existing T-4580 | fixture Verification `true` now refused |
| governance test_t3077 approvals surface isolation | filed T-4586 | reproduced: find on absent `.context/approvals` under set -e |
| Playwright 50 failed, incl. `/inception/T-2715` scrollHeight 10404px | sibling T-4574 | |
| Suite left 134 changed paths (94 untracked, 4 deleted, 36 modified) | filed T-4588 | |

## Newly filed

filed T-4583 · filed T-4584 · filed T-4585 · filed T-4586 · filed T-4587 · filed T-4588

## Not runnable here

The integration/governance totals in report 1 and the 117 "defect" items in report 4 are
counts without names; only the named items above can be mapped. A re-run of job 1 with the
corrected prompt (and its per-failure list written to the report, not to thinking) is what
would close that gap.
