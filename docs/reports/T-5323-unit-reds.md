# T-5323 — the 12 unit reds of 2026-11-20: classification and why the push passed

Nightly unit suite: green at 6c97f8ad8 (2026-11-20 02:03Z), 12 red at ff5d9412a
(2026-11-21 02:03Z). Causes: two commits from the 2026-11-20 session.

- **T-5298** (`01268d912`): added the RESTART_BY/RESTART_CAUSE blocks to
  `agents/context/post-compact-resume.sh`.
- **T-5304** (`04ae2aae4`, `5d3a07c78`, `a39059272`): commands are now printed through the
  builder (`lib/fw-command.sh` `_emit_user_command`, `lib/fw_command.py` `user_command`)
  as `cd <abs root> && <fw path> <args>`.

## Classification

Key: **pin** = the test pinned the old spelling or shape that an intended change replaced.
The test now asserts the new form at least as strictly. **fixture** = the test harness
leaves out something every real install has. **REGRESSION** = the code was broken and is
now fixed.

| # | Test | Class | Evidence and fix |
|---|------|-------|------------------|
| 1–4 | `restart_sentinel_ttl.bats` 2,3,4,5 | pin (extractor shape) | `extract_gate` lifted from `RESTART_SENTINEL_TTL=` up to the first balancing `fi`. After `01268d912` that `fi` closes the new `if [ -f "$RESTART_SENTINEL" ]` RESTART_BY block, so the lifted "gate" was the TTL line plus the cause read, with no startup gate at all. The gate always printed REACHED and never consumed the sentinel. **The hook itself is correct.** Lines 74–85 still consume a fresh sentinel and exit on a stale or missing one, unchanged by T-5298. Fix: match depth from `if [ "$SOURCE_TAG" = "startup" ]` and keep everything from the TTL line onward. |
| 5–6 | `t4075_inception_decide_tick_provenance.bats` 3,4 | fixture | `5d3a07c78` made the FAIL line of `human_ac_ticks.py audit` call `_fwc()`, which imports `lib/fw_command.py`. The fixture copied only `human_ac_ticks.py` and `comment_strip.py`, so the audit crashed with `ModuleNotFoundError: lib.fw_command` (exit 1) on exactly the path that has findings, instead of returning exit 2. Framework and vendored installs both ship `fw_command.py` alongside it (`.agentic-framework/lib/fw_command.py` exists). Fix: the fixture copies it. |
| 7 | `focus_drift_remedy_scope.bats` ANTI-VACUITY | fixture, latent since the test was written | The mutant was copied to `$BATS_TEST_TMPDIR` alone, so `FRAMEWORK_ROOT` resolved to the tmpdir and every `source lib/…` failed (`paths.sh: No such file`, `fw_focus_file: command not found`). The test passed only because the remedy used to be a literal `echo`. Since `04ae2aae4` the remedy is `$(_emit_user_command …)`, which is undefined in a degraded run, so no command was printed. Fix: the mutant now runs inside a framework-shaped tree (`lib/`, `.fabric/` and the `agents/context` siblings are symlinks, and the mutant is never a symlink). New negative legs: no `command not found` and no `No such file`. |
| 8 | `t2461_doctor_mcp_consumer_path.bats` t6 | pin | `a39059272`: `lib/doctor-drift.sh:155` now prints `run: $(_emit_user_command "upgrade")`. The source grep now looks for that line. The behavioural leg asserts the exact `run: cd $proj && .agentic-framework/bin/fw upgrade` (stricter: it names the vendored path). Added a negative leg `!= *"run: fw upgrade"*` (no bare fw); the `emit-manifest` negative is kept. |
| 9 | `t2987_bootstrap_shape_hint.bats` "no block site advertises…" | pin | `04ae2aae4` rewrote 18 sites from `$(_fw_cmd) work-on…` to `$(_emit_user_command "work-on…")`. The count is 18 before and 18 after; all 7 `_bootstrap_shape_hint` calls are intact. The test now counts the builder spelling and also refuses any remaining old-spelling site. |
| 10 | `t3050_b005_block_message.bats` A4 positive control | fixture (same as #7) | The `$TMP/mutant.sh` copy ran degraded, and since T-5304 it printed no remedy. The positive control caught this correctly: the sibling A4 "mutation" leg was passing **vacuously**, because a degraded mutant prints no `hook-enable` either. Fix: both A4 legs use `make_mutant` (a framework-shaped tree), and the positive control also refuses a degraded run. |
| 11 | `t3878_runme_pending.bats` WATCH LOST | **REGRESSION** + pin | `lib/runme.sh:251,261` call `_emit_user_command` (from `5d3a07c78`) but never load the builder. Under `bin/fw` it worked by luck, because bin/fw had already loaded it. The session-start hook (`post-compact-resume.sh:455`) runs `bash -c '. lib/runme.sh && runme_pending'` in a fresh shell with stderr dropped. Reproduced: that banner read `WATCH LOST  upgrade — …; re-arm:` with **no command**. Fix in code: `lib/runme.sh` loads `fw-command.sh` when `_emit_user_command` is absent (the same guard as `lib/doctor-drift.sh:31`). The test pins `re-arm: cd $PROJECT_ROOT && .agentic-framework/bin/fw runme watch upgrade` and a `command not found` negative. A new test drives the hook's exact `bash -c` invocation: it is red without the fix and green with it. RUN IN FLIGHT now also pins its `watch it:` command. |
| 12 | `t4265_onboarding_remedy_passes_gate.bats` "every remedy…" | pin | `04ae2aae4`: the remedies are now `  cd <root> && .agentic-framework/bin/fw work-on T-001` and `… onboarding skip`. The extraction regex now requires the `cd <root> && <fw path>` prefix. The test asserts the exact skip line (`grep -qxF`) and at least 2 remedies. Each **full printed line** is still fed back through the gate and must exit 0, so the L-597 property ("every remedy passes the gate") is now checked on the line an agent would actually paste. |

Extra (not among the 12): `t4768_cli_decide_commits_tick_provenance.bats` "control: without
the commit…" fails today for the same reason as #5–6 (its fixture copies
`human_ac_ticks.py` without `fw_command.py`). The 11-21 nightly showed this file green, and
I could not find out why. The same fixture fix is applied.

No baseline additions, no skips. Source changed: `lib/runme.sh` only (vendored with
`bin/fw vendor self`).

Observations, not fixed here:
- The onboarding block tells you to `work-on T-001` while the open onboarding task is
  T-9402. That behaviour predates this task.
- `_fwc()` in `human_ac_ticks.py` makes the audit's FAIL path depend on an import. If
  that import fails, the audit exits 1 (traceback) instead of 2 on exactly the run that
  has findings. That only happens in a stripped layout, so here it is a fixture issue.
  Still, a FAIL report that can crash into a lower exit code is fragile. Candidate
  hardening: fall back to the plain string when the import fails.

## Why the 2026-11-20 pushes passed with these reds

The pre-push ratchet (`audit.sh --section structure` → `check_unit_suite_report`, T-3621)
**does not run any tests. It only grades the last nightly report**
(`.context/audits/unit-suite/LATEST.yaml`). All 48 audit runs on 2026-11-20
(`.context/audits/2026-11-20-*.yaml`) graded the same report: the 02:03Z run at 6c97f8ad8,
which came before every one of that day's 262 commits. They all recorded
`Unit suite (tests/unit) COULD NOT DETERMINE — 876 of 886 file(s) ran, no failures
recorded` (WARN, because 10 files hit their per-file timeout), never a FAIL. So nothing
was flaky, no run was cut short, and the scope was not wrong. The ratchet is **blind to
anything committed after the last nightly**: up to ~24 h of commits can push with the
unit tests they break never having run. The reds appeared at the next nightly
(ff5d9412a) and blocked the following day's push instead. A second, independent weakness
is that a partial run (10 files undetermined) grades WARN, so even a stale report never
blocks.

**Gap to register (recommended):** "pre-push unit ratchet grades the previous nightly,
so a day's commits push without their unit tests ever having run." The detection lag is
one day, not more than 7 days, so this is a G-019-class finding, not sustained
blindness. Prevention candidates for the operator:
(a) at pre-push, run the test files that the pushed range touches or that reference the
changed sources;
(b) refuse or WARN when `LATEST.yaml` `revision.commit` is behind the pushed range by
more than N source commits;
(c) a mid-day suite run.
