# T-4866 — shared-state sweep of the unit suite

Date: 2026-10-29. Read-only sweep, worker `t4866-sweep`. Nothing was edited except this report.

## Scope and method

- Corpus: `tests/unit/*.bats` and `tests/unit/*.py`. The sweep was limited to the **fast tier** (886 files in
  `tests/unit/tiers.yaml`), because that tier is what `FW_UNIT_SUITE_TIER=fast` runs in parallel and what the
  pre-push ratchet grades.
- I grepped for each class, then read the matched lines before listing anything. Candidates I did not confirm by
  reading are not in the table.
- Context that shapes the classes: `agents/audit/unit_tree_guard.py` already FAILs a run that changes **tracked or
  untracked, non-ignored** paths in the checkout (T-4523). It excludes ignored files. So writes into the live
  repo's gitignored state (`.context/working/`, `.context/locks/`, `.context/bus/`, …) are the remaining blind spot
  of class 1. I found no fast-tier test that writes there.
- pytest files run one process per file (`agents/audit/unit-suite.sh:288`), so `os.environ` changes in a `.py`
  test leak only to later tests in the same file.

## Summary

| Class | fix-now | note |
|---|---:|---|
| 1 live-repo state | 0 | 3 |
| 2 fixed ports / live Watchtower | 1 (shared with class 4) | 2 |
| 3 shared locks / fixed `/tmp` names | 0 | 1 |
| 4 timing under load | 2 | 2 |
| 5 global env mutation | 0 | 1 |
| **Total** | **3** | **9** |

Fixed `/tmp/...` names: every hit in the fast tier is a string literal passed to a classifier
(`is_bash_safe_command`, `_gate`, hook payloads, `yield-point.sh check`). None creates the file. I found no
`git config --global|--system`, no real `crontab` call, and no `HOME=` that points outside a temp dir.

## Findings

| file:line | class | what is shared | verdict | fix direction |
|---|---|---|---|---|
| tests/unit/t4041_watchtower_fw_host.bats:94 | 4 (+2) | Launches the real `web.app` (`bin/watchtower.sh:420`). The 60 s `WATCHTOWER_START_TIMEOUT` health deadline (`bin/watchtower.sh:446`) races host load. The port comes from bind-then-close at setup (line 21), so the port can be taken between setup and start. | fix-now | Pass `FW_WATCHTOWER_START_TIMEOUT` (for example 180) in the `run env` at line 94, or move the file to the slow tier. Retry once on a port collision. See the section below. |
| tests/unit/t3443_audit_structure_framework_scope.bats:52 | 4 | `timeout 60` around a full `audit.sh --sections structure` against a fixture. If it is killed, the output is partial and the greps on lines 55–56 fail. It took 3.2 s at load 9, and the whole file took 21–47 s in the 10-26..28 reports. The test also has a lock skip (line 43), but a timeout is not treated the same way. | fix-now | Treat exit 124 as NOT DETERMINED (skip with a reason), as `_t3443_require_audit_ran` already does for the lock. Or raise the timeout so it fits the 120 s fast-file cap. |
| tests/unit/t3202_audit_kill_source.bats:253 | 4 | `timeout 4` must kill `audit.sh` after it has installed its TERM trap (`agents/audit/audit.sh:723`, which runs after the top-level init). Otherwise `full-audit-timing.yaml` is never written and line 255 fails. The short kill is deliberate, because the test is about an external kill. | fix-now (timing only; I could not measure where the trap lands, because the shell gate refused my probe) | Wait until the audit reports it is running (poll for the in-flight marker at `audit.sh:733/749`), then send TERM, instead of a fixed 4 s wall clock. |
| tests/unit/onboarding_gate_arc_tag_fp.bats:102 | 1 | Writes the untracked, **not ignored** `agents/context/.t2881-mutant.py` into the live tree on purpose, and removes it in teardown (line 193). While it exists, `rglob` scanners over `agents/` in other files see it: `atomic_yaml_write_lint.bats:43`, `test_no_relative_fw_argv_t3952.py:20`. It is a byte-for-byte copy of a gate that passes those lints (no `yaml.dump`), so no red today. | note | Keep it, or add a scanner skip for `.t2881-mutant.py`. It turns into fix-now if the gate ever gains a path-keyed lint exemption. |
| tests/unit/t3443_audit_structure_framework_scope.bats:73 | 1 | The control leg runs `--check invariant-suite,dead-negation-lint` against the **live** repo (lockless, `timeout 600`). Its verdict depends on live tree state, and 600 s is longer than the 120 s fast-file cap. | note | Accept (live by design). The fast cap, not the inner timeout, is the real bound. |
| tests/unit/test_peer_subscribe.py:242 | 1 / 5 | Sets `os.environ["PROJECT_ROOT"]` to the real repo and does not restore it. It reads the tracked `.context/peer-consult-prompts.yaml`. `resolve_addressee` does not call `log_miss` (`lib/peer.py:112,129`), so nothing is written. Later tests reset it through `_load_peer_module`. | note | Use `monkeypatch.setenv`. |
| tests/unit/escalation_scan_v05.bats:69,73 | 1 | Greps the live, tracked `.context/cron/agentic-audit.crontab`. No fast-tier test regenerates it (no `cron generate/install` against the real root was found). | note | none |
| tests/unit/t4304_watchtower_preflight_modules.bats:31 | 2 | Fixed `--port 39041`, but the module pre-flight (`bin/watchtower.sh:336`) exits before the port check and launch, so nothing binds unless the stubbed import stops failing. | note | Use an allocated port so a regression cannot bind a fixed one. |
| tests/unit/watchtower_url_refresh.bats:149,173 | 2 | `localhost:3000` is only the expected fallback string. Nothing is probed. | note | none |
| tests/unit/fw_shim_selfloop_guard.bats:26 | 4 | `timeout 1` on `bin/fw version` through the shim. The whole file took 0.12 s at load 9, so the margin is about 8×. | note | Raise to 5 s. The assertion that matters is "not 124 and guard message", not the 1 s. |
| tests/unit/t3443…:52 / t3127_audit_timing_headroom.bats:151 | 3 | The audit lock is `$CONTEXT_DIR/locks/audit.lock` (`audit.sh:409`) and both use a temp `PROJECT_ROOT`. So the lock is per-fixture and not shared with the live repo's cron audit. | note | none |

## tests/unit/fw_pending_remind.bats test 5 (failed once, 2026-10-28T07:59:00Z)

What I checked:
- The file is fully isolated. `setup` makes a `mktemp -d` git repo (lines 8–17). Every `bin/fw` call gets
  `PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR=`. `PENDING_FILE` derives from that root (`lib/pending.sh:6`).
  The verb counter in `bin/fw:6735` writes to `$PROJECT_ROOT/.context/working`, which is also the temp repo. I
  found no fixed path, port, lock or live-repo read.
- `do_pending_remind` (`lib/pending.sh:270–352`) runs under `bin/fw`'s `set -euo pipefail` (`bin/fw:12`). The only
  non-zero exits in it are a failing `python3` heredoc (`summary=$(…)`) or a failure in `bin/fw` before dispatch.
  The notify branch only runs when `NTFY_ENABLED=true` and is `|| true`.
- Test 3 takes the same stale-entry path (it also reports a stale entry at threshold 0) and passed in the same run.
  So the code path is not what differs.
- The captured output (`.context/audits/unit-suite/failures/2026-10-28T07:59:00Z/bats/fw_pending_remind.bats.out`)
  has only the status assertion. No output was kept, because the diagnostic in line 87 came later (T-4861,
  5b9d03b49).
- The same run (commit 9cb4c461b, `tree=dirty`) had four other red files: `approvals_close_ready_arcs`,
  `atomic_yaml_write_lint`, `audit_split_root_asset_lint`, `review_pipefail`. Their failure text is deterministic
  code state, not timing (missing `policy/value-drivers.yaml` in a fixture, lint ratchets).

Verdict: **no shared state found.** The cause cannot be determined from what was kept. The remaining candidates are
a transient `python3` failure under load, or a transient dirty-tree state of `bin/fw`/`lib/` at that run. The T-4861
diagnostic will show which one if it happens again. No fix-now.

## tests/unit/t4041_watchtower_fw_host.bats test 6 (failed once, 2026-10-28T09:21:59Z)

What I checked:
- The test runs the real `bin/watchtower.sh start --port $PORT` with `FW_HOST=127.0.0.2` and `PROJECT_ROOT=$PROJ`
  (temp). All pid/port/url/log/firewall files are under `$PROJ/.context/working` (`bin/watchtower.sh:26–32`), so
  there is no live-repo file sharing.
- Start launches the full Flask app (`python3 -m web.app`, `bin/watchtower.sh:420`, cwd `FRAMEWORK_ROOT`). The app
  registers all blueprints at import and starts a background cache warm-up (`web/app.py:592`). It waits up to
  `WATCHTOWER_START_TIMEOUT` (default 60) iterations of `sleep 1` plus an identity probe. On expiry it exits 1
  (`bin/watchtower.sh:449–519`). The T-4460 comment in that file records the home page taking 68 s under load.
- Today, at load 9, the test alone passes in 4.4 s. A roughly 10× slowdown at load around 90 on 24 cores would bring
  it near the deadline. The file's recorded durations in the daily reports (7–20 s) put it in the fast tier, and
  that duration excludes the worst case.
- The port is chosen in `setup` by bind-and-close on 127.0.0.2 (line 21) and used later. In between, another
  process can take it. `port_in_use` then makes start exit 1 ("FOREIGN service"), or `web.app` fails to bind
  ("exited immediately"). This window is small but real.
- `run env …` (not `env -i`) inherits the runner's `FW_*` environment, so a caller's
  `FW_WATCHTOWER_START_TIMEOUT` or `FW_WATCHTOWER_WARM_BEFORE_SERVE` would change the behaviour.
- The failure capture has only the status line, so I cannot tell which of the three exits fired.

Verdict: **fix-now.** It is a load-sensitive server start in the fast tier. Directions, in order of preference:
1. Set `FW_WATCHTOWER_START_TIMEOUT=180` on line 94 and print `$output` on failure, so the next red names its exit.
2. Retry once with a fresh port when the output says FOREIGN or "exited immediately".
3. Or move the file to the slow tier, where a 60 s-plus server start belongs.

## Out of scope but seen

`tests/unit/review_pipefail.bats` test 5 is **deterministically red**: it failed alone, with and without
`CLAUDECODE`, today and in 8 captured runs on 2026-10-28. It is not a flake and belongs to its own bug task.
`atomic_yaml_write_lint.bats` test 1 is also deterministic (14 captures). It names `lib/cron_commit.py`,
`lib/govd_sandbox.py` and `agents/audit/unit_tier.py`.
