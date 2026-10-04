# T-3747: Unit Suite Red Triage — Round 3

**Session:** 2026-10-04 (worker w-t3747c)
**Regression baseline:** `914326e07` (origin/bleeding-edge before today's 70 commits; see "Unplanned push" below)
**Scratch clone for comparisons:** `/tmp/w3747c-origin` (a `git clone`, not a worktree)

## Phase 1 — T-3791 (closed)

| Gap left by T-3790 | Fix | Commit |
|---|---|---|
| PROJECT_ROOT guard only in `audit.sh schedule install`; ghost cron lines also run `fw docs --all`, `fw audit`, oe sections through bin/fw, which re-resolved a missing root to the cwd/FRAMEWORK_ROOT | `bin/fw` refuses a non-existent PROJECT_ROOT for every verb (exit 2, one stderr line) outside a Claude Code hook context. A valid CLAUDE_PROJECT_DIR keeps the T-2390/T-2391 re-resolution. t2391 t6 updated on purpose (its contract was the behaviour this replaces); t6b pins the hook exception. New `tests/unit/t3791_fw_refuses_missing_project_root.bats` covers `fw docs --all`, `fw version` and `fw audit` with a missing root, plus existing-temp-dir and no-root controls | 0279f5fb0 |
| `tools/bats-cron-env-lint.py` invoked by nothing | `tests/lint/bats-cron-env-lint.bats`: a corpus leg plus fixture legs that prove it fires; the lint now takes dirs and resolves tests/unit from its own location | 0279f5fb0 |
| t3070 compared `ls -la \| wc -l` | name+size+mtime listing compared in test 3 and in teardown, for every test in the file | 0279f5fb0 |
| vendored audit.sh lagged T-3790 | vendor sync | d5b8c5378 |

The close was refused by the T-3694 self-deferral gate: it read the H1 title "T-3790 follow-up: …" as a deferral to the completed T-3790. That is a gate bug, so it got its own task, **T-3793**, fixed in 58a106910 (the title line is skipped; a regression test pins both sides) and closed. T-3791 then closed, with close records in a89ddc6ca.
`/etc/cron.d` listing was identical before and after (checked by name, and by name+size+mtime in the Verification block).

## Phase 2 — T-3747

### (A) arc-membership
`bin/fw audit --section structure` now prints `[PASS] No Python arc-membership derivation outside canonical import (T-3516, OBS-546)`. The vendored copy of `lib/design_register.py` had lagged 924071db6 and was synced in 791f3c8af.

### (B) Reds

Each was run alone (with `time`). "Regression" means caused by 914326e07..HEAD.

**Original 18 reds and 7 timeouts (prompt list):**

| Test | Verdict | Cause | Fix / task |
|---|---|---|---|
| greenfield_seed_audit_prototype T-2703, T-2740 | REGRESSION (T-3783) | the vector-index check FAILed a just-initialized project whose index the hourly reindex had not built yet | 68643a1de: WARN "not built yet" while `initialized_at` is less than INDEX_MAX_AGE_HOURS old (cron still FAILs; a vanished index or an old project still FAILs); 3 new t3783 tests |
| handover_digest narrative byte-identical | test defect (pre-existing, made visible) | ran handover.sh with AUTO_COMMIT and PROJECT_ROOT set to the real repo, so the narrative reflected live repo state, and it pushed origin | 27613a681; guard T-3798; OBS-599 |
| test_doctor_litellm_ollama, test_doctor_scope_tags "exits cleanly"; fw_mode_detection T-1406; t2452 F6; t2243 t1 | environmental (live doctor state + load); same tests red on 2026-09-30 | green alone (litellm 160 s, scope_tags 553 s 14/14, fw_mode 179 s, t2452 107 s, t2243 689 s) | doctor speed-ups 4d1b4a80e; timeouts T-3801 |
| fw_doctor_vendored_drift "No vendored-source drift" | environmental (live working-tree drift; the test mutates the real vendored colors.sh) | red alone too, because of my then-unvendored bin/fw edit | T-3800 |
| audit.bats "audit runs structure section" | pre-existing (red 09-30, 10-02, 10-03) | circular: asserts the live structure audit has no FAIL, which includes the unit-suite ratchet | T-3812 (timeout: T-3801) |
| context_yaml_escape (3) | not reproducible | 5/5 alone, 8/8 in parallel; nothing on its path changed in range; green in the round-3 full suite | none needed |
| t1719_ask_routing a3, t1719_index_one_post_write | not reproducible | green alone (106 s, 49 s) and in the full run | none |
| t2436 t3, t3511 parked merge | not reproducible | green alone and in the full run | none |
| t3662 skips a foreign holder | environmental (load) | the 5 s Watchtower start health window; 10/10 green alone, cold start about 1 s | T-3797 |
| 7 timeouts (audit, doctor_designer_pin_drift, fw_doctor_vendored_drift, t2243, t2290, t3119, test_doctor_scope_tags) | pre-existing | same files in files_timed_out on 2026-10-01 and 2026-10-02; full doctor about 160 s | T-3801, T-3799 (/cron), 4d1b4a80e |

**NEW reds in the round-3 full suite (10:04–10:53Z):** 11 NEW versus the baseline; 28 baselined reds grade WARN; 8 files timed out.

| Test | Verdict | Cause | Fix / task |
|---|---|---|---|
| focus_active_scope SMOKE + CONTROL | env leak from the dispatched worker | FW_SESSION_SCOPED_FOCUS/FW_FOCUS_SESSION_KEY sent focus to focus.<key>.yaml | 5301f27e6 (7/7 green) |
| bvp_auto_promote ×2, bvp_auto_promote_enable ×1 | pre-existing race | both files snapshot and restore the LIVE policy/value-drivers.yaml; in parallel they left `enabled: true, max_concurrent: 999` in the working tree (restored by hand; both green alone) | T-3807 |
| self_vendor_version t7 | live anchor | whole-repo `vendor self --check` saw the leaked policy drift; it also writes the real VERSION | T-3808 |
| test_audit_watchdog_fd | concurrency | scans every PPID=1 sleep on the host | T-3809 |
| hook_telemetry_race 5 ms budget | load | wall-clock micro-budget | T-3810 |
| t3459 expired timestamp recompute | load (green alone) | recompute over the live corpus under load | T-3811 |
| t2243 t1 | load / live doctor | green alone, 689 s | T-3801 |
| audit.bats structure | circular | see above | T-3812 |

### Unplanned push — found and stopped at the source
`tests/unit/handover_digest.bats` ran `agents/handover/handover.sh` with only TASKS_DIR, CONTEXT_DIR and HANDOVER_DIR overridden. `AUTO_COMMIT` defaults to true and PROJECT_ROOT resolved to the real repo, so `_push_to_remotes` ran `git -C /opt/999-Agentic-Engineering-Framework push --follow-tags origin HEAD` from inside the test. While I ran that file alone it pushed bleeding-edge to origin at 10:49 local (a89ddc6ca) and then 68643a1de, both through the full pre-push gate, and it fired `fw_notify "Session Ended"`. My attempt to kill the running test was denied, so it ran out its 900 s timeout. The test is fixed (27613a681). The structural guard is T-3798, and the concern is registered as OBS-599 (bac5f743f). Every earlier unit-suite run of this file would have done the same.

### Doctor runtime (why the doctor files time out)
A full `fw doctor` takes 160 s on this host: the web smoke test 57 s (6 endpoints hit their 5 s timeout), `design_register violations` 22 s, `port3000_hygiene doctor-line` 18.5 s, and the T-3783 index canary 7.4 s.
- 4d1b4a80e: `--quick` now runs the index check without the canary; design_register uses libyaml's CSafeLoader (22 s → 3.2 s, output byte-identical for violations and stale-keystones). Watchtower restarted, and /approvals went from 10 s to 4.4 s.
- /cron 13–37 s (same pure-Python YAML pattern, in web/): T-3799.
- The timeouts themselves are pre-existing. The same files are in `files_timed_out` on 2026-10-01 and 2026-10-02, both before 914326e07: T-3801.

## Final suite and audit

- Full suite: `2026-10-04T10:04:47Z → 10:53:44Z, runner_exit=1`; bats: 723/731 files completed, 6449 tests, 37 failed (28 baselined); pytest: 263 files, 3919 tests, 2 failed (baselined).
- `/etc/cron.d` was unchanged across the full suite.
- Final `bin/fw audit --section structure` (exit 2):
  - `[PASS] No Python arc-membership derivation outside canonical import (T-3516, OBS-546) — examined 269 Python file(s) under lib/ web/ agents/ bin/ tools/`
  - `[FAIL] Unit suite (tests/unit): 11 NEW red(s), 0 EXPIRED baselined red(s) — pre-push ratchet (T-3621)`
- Fixed after the full run: focus_active_scope (5301f27e6), and the policy file was restored. The remaining NEW reds are load, concurrency or live-state bugs, filed one task each. I did not re-run the suite, because they are load-dependent and a re-run would not settle them. baseline.yaml was not touched; accepting reds into it is the operator's call.

## Push

See the commit after this one, or the worker's final output.
