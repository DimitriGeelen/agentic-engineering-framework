# AEF cloud-run reports — readable excerpts (relayed by ring20, T-2466)

All three runs SUCCEEDED. The run log condenses each message to ~1000 chars, so only the head of each final report is
readable; the rest (marked `[+N chars]` in the log) cannot be retrieved: these were non-persistent sessions, the
sandboxes are gone. Text below is verbatim from the log unless marked [ring20 note].

## 1. trig_0183Vgh5m1gBFNHSPm6xPSsK — clean-room FULL suite at bleeding-edge tip (fired 2026-10-20 23:55Z, session cse_01JfPN5toChs3iWrJXTUHNiX, done 04:32Z)

Commit: 6f60b69b5697fd31153608bf94c0a37dfe6f34f3 2026-10-20T22:57:12+02:00 (branch bleeding-edge).
"The full suite ran, and roughly 180 of about 15,600 tests still fail in the best environment I could set up. About
half of those are real defects; most of the rest come from host software this machine doesn't have. Two bats files
hang every time, and the suite changed or deleted tracked files in the clone. Nothing was committed or pushed."
Environment: Ubuntu 24.04.5, kernel 6.18.44, 4 vCPU, 15 GB, root container; bash 5.2.21, Python 3.11.17, pytest 9.1.1,
jq 1.7, shellcheck, node 22. bats 1.10.0 first pass, then 1.14.0 (bats-core HEAD, as .github/workflows/test.yml installs).
Extra Python pkgs: web/requirements.txt, jsonschema, cryptography+cffi, beautifulsoup4, pytest-timeout, playwright
1.56.0 (matches preinstalled Chromium). Not available: `mcp` module, termlink, ollama server, cron, installed git hooks.
How run: each suite separately; bats one file at a time, 4 parallel, 900 s cap per file.
- On bats 1.10 `bats tests/unit/` aborts before any test (`fw test unit` too): heredoc fixtures in
  t4058_unit_suite_keeps_failures.bats are read as real tests -> duplicate test names.
- Runner leaked CLAUDECODE=1 and other Claude vars into tests; failures re-run with them removed: very little changed.
- Container restarted once and killed playwright; playwright re-run from start.
Results seen in the log (final env): bats unit files=927 pass=7900 fail=74 skip=18; integration files=94 pass=526
fail=31 skip=5; governance files=8 pass=38 fail=11 skip=9; lint files=27 pass=142 fail=1 skip=1; playwright: 41 failed,
889 passed, 4 skipped in 4394.88s. Hanging (rc=124 at 900 s): tests/integration/fw_docs.bats, tests/unit/handover.bats.
Examples seen: approvals_close_ready_arcs (policy/value-drivers.yaml not found in temp project); budget_gate test 28
(T-2403 .next-directive.yaml fold); test_framework_mcp_server (No module named 'mcp'); fw build -v (npx esbuild);
web: _approvals_content.html:5 UndefinedError (decided_unclosed_count) in test_inception_verdict_render; playwright:
`/` scrollHeight 55135px > 8000px cap, approvals verdict badge 'BLOCKED' not canonical, arc-detail .badge-ok contrast,
review page with editable text input, inception detail missing 'Acceptance Criteria' section.
The report body (per-failure table, "Side effects on the clone") is lost after the results table header.
[ring20 note: trig_011RxgKrY39GrNQgcBoqnfLW (09:09Z) was the follow-up for exactly this per-failure list, see below.]

## 2. trig_014UF5eUDTigWyNQVGqHFuFv — job 1/2 (AEF T-4508): clean-room unit suite fast+slow, pinned cc094b509 (fired 08:50Z, session cse_01W6Keh9KC7iepi2LBfS4TyH, done 11:07Z)

"I tested cc094b509c42eafd36814049014e045bcfd865f6 and both tiers ran to completion, with many failures. The large
majority come from this machine's setup rather than the code. Only the 12 fast-tier files that timed out turned out to
be load-related; every other failing file still failed when run alone."
Machine: 4 CPU, 15 GB. Fast tier 683 s; slow tier 4,747 s (tree marked dirty: fast tier's audit output still there).
bash 5.2.21, bats 1.10.0, Python 3.11.17, git 2.43.0.
Setup problems: `pip install playwright` went to a different Python than python3 on PATH (reinstalled with
`python3 -m pip`); `playwright install --with-deps chromium` failed (Download failure, code=1) -> pinned playwright
1.56.0 matching preinstalled Chromium 141. MOST IMPORTANT: the job's setup list leaves out modules web/requirements.txt
lists: markdown2, ollama, ruamel.yaml, tantivy, bleach; also _cffi_backend. 77 of 89 failing pytest files fail with
"No module named ..." (markdown2 alone 272 times). Not installed, because they were not in the job's steps.
| Tier | Leg | Files | Tests | Passed | Failed | Skipped | Files timed out |
| Fast | bats | 606 | 4,838 | 4,767 | 62 | 9 | 8 |
| Fast | pytest | 280 | 3,784 | 3,661 | 111 | 12 | 4 |
| Slow | bats | 336 | 3,210 | 3,091 | 91 | 28 | 0 |
| Slow | pytest | 105 | 1,538 | 1,426 | 95 | 17 | 0 |
Passed alone (load-only): the 12 fast-tier files that timed out under parallel load, incl. bats lib_upstream,
note_capture_guard, note_exit_status, revisit_undated_signal, t2459_mcp_server_root_split, t2924_update_task_owner_g...
[rest of the list lost]. Re-run-alone still failing (seen): approvals_close_ready_arcs (5), atomic_yaml_write_lint (1),
audit_ctl_arc_tag_only_pattern (rc=1, 0 not-ok), bvp_auto_promote (5), lib_config_file (1), lib_costs (1),
t3062_prepush_runtime (1), t3118_horizon_migration_scope (1), t3379_review_placeholder_foreign_port (3),
t3388_ewcr_worked_procedure_fixture (4), t3644_literal_assignment_segment (2); slow: audit_inception_recommendation
test 10 (FW_ALLOW_EMPTY_RECOMMENDATION=1 bypass), bvp_auto_promote_enable test 7 (cron registry in sync). pytest
without missing-module: test_extract_recommendation (expects an <a href> link for a review URL), test_govd_sandbox,
test_importer_fidelity, test_no_relative_fw_argv_t3952, test_render_artefact_paths, test_t3649_render_extras_viewable.
Side note from the job: its background waiter matched its own command line ("rerun.sh" in pgrep -f) and ran to its limit.

## 3. trig_019xdJE171YU9QSCFVDJtRxe — job 2/2 (AEF T-4508): fresh-machine upgrade v1.8.14 -> cc094b509 + hook survival (fired 08:50Z, session cse_018LGzRtZK6MhNUn11ZfMvjV, done 09:01Z)

"fw upgrade exits 0, but it does not update the commit-msg and pre-push hooks, and it adds a stray message to every
commit. The fresh-machine suite has 5 failures, all caused by how the test sets up the clone, not by the upgrade code."
1. Setup: exit 0. 2. Clones full, pins available; both left detached HEAD (matters for step 6).
3. fw init on release: exit 0, no prompts; "44/45 checks OK (1 skipped)"; creates .agentic-framework/, .claude/,
.context/, .framework.yaml, .mcp.json, .tasks/, CLAUDE.md, policy/, vendor/ — all untracked (init commits nothing).
Hooks: commit-msg, post-commit, pre-commit, pre-merge-commit, pre-push. doctor OK 33 / WARN 8 / FAIL 0. False OK in
the release: "OK cron: index-reindex-hourly scheduled" with no cron entry (candidate correctly WARNs).
4. Appended `echo PROJECT-GATE-RAN` to pre-commit: in stock v1.8.14 it lands after an `exit 0`, so never ran before.
5. fw upgrade: exit 0, "6 change(s) applied, 1 item(s) skipped"; .framework.yaml version 1.8.14+509.gcc094b509,
version_sha, project_id. Step [4/10] "WARN Git hook installation failed" (lib/upgrade.sh:2226). Direct
`git.sh install-hooks`: "REFUSED: the lines of commit-msg outside the framework template do not parse after the
framework block — installing would disable them. commit-msg left unchanged" (marker 1.17 vs template 1.20; pre-push
1.9). After upgrade pre-commit is wrapped in the managed block; T-4515 keeps the project line ACTIVE -> PROJECT-GATE-RAN
now prints on every commit (it was dead code before). Commit without task ref correctly blocked.
Fresh-machine bats suite: 11 ok / 5 not ok (T-3835 crontab, T-3836 .mcp.json env keys, T-3831 x2 ~/.local/bin/fw
symlink, T-3833 settings.json hooks) — all fail in overlay_upstream (test setup on a detached-HEAD clone); on a local
branch all 5 pass. No fw on PATH; no ~/.local/bin/fw shim installed. [rest of the report lost]

## 4. trig_011RxgKrY39GrNQgcBoqnfLW — AEF follow-up: per-failure list, full suite at bleeding-edge tip (fired 09:09Z, session cse_01AkqPbLFZzJRTrEfvcqhRYz, done 15:05Z)

Commit cc094b509c42eafd36814049014e045bcfd865f6 (2026-10-21T01:54:09+02:00). The 35 report parts were written into the
model's hidden thinking (the known failure), so the per-failure list itself is NOT readable. What the tool results show:
- pytest: unit 20 failed / 5407 passed / 28 skipped / 1 xfailed (34:16); web 16 failed / 303 passed / 2 skipped;
  integration 3 passed / 14 skipped; webdir 2 failed / 212 passed; playwright 50 failed / 880 passed / 4 skipped (1:08:48).
- pytest re-run alone: of 88 failures 79 still fail, 9 pass alone (e.g. test_cockpit_activity polling card,
  test_sidecar_cli_peer_frame test_alerts, test_t4458_search_degrade x2, tests.web.test_t4043_...).
- Classification of 325 failing items (job's own rules): defect 117, env(git-hooks) 24, env(cryptography) 18,
  env(termlink) 10, env(ollama) 10, flaky 10, env(ss) 7, env(npm-deps) 5, env(claude-cli) 4, env(py-mcp) 3, hang 2,
  env(cron) 2, env(systemd) 1.
- Named in passing: /settings/ PanicException (no _cffi_backend -> cryptography, env); /api/v1/search 503 (no vector
  index, env); /file/docs/style-guide.md returns 404 although the file exists (job: "looks like a real defect");
  fw build fails: esbuild cannot resolve "js-yaml" in lib/ts/src/fw-util.ts; t2436 vendor --check vs --dry-run
  disagree; t3661 watchtower status uses `ss` (absent); t3644 literal-assignment SAFE cases fail (defect);
  governance test_pretooluse_gates 6/12, test_register_requirements_gate 1/4/5, test_t3077 approvals surface isolation
  (defect); playwright /inception/T-2715 scrollHeight 10404px > 8000px cap.
- The suite left 134 changed paths in the clone (94 untracked, 4 deleted, 36 modified).
