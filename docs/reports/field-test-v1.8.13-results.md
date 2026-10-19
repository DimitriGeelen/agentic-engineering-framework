# Field-test results for the next release (v1.8.13 candidate)

Positive field tests here are the release evidence under the T-4146 rule. One row per fix, one section per round.
Started 2026-10-19 (T-4328).

| Fix | Project | Verdict | Round |
|---|---|---|---|
| T-4367 git diff/log/show/diff-tree/diff-index/whatchanged `--output` is a write | ring20-dashboard | WORKS | 1 |
| T-4368 git check-attr, check-ref-format, diff-index classified as reads | ring20-dashboard | WORKS | 1 |

## Round 1 — ring20-dashboard (msg fd5e26ca, 2026-10-19)

- **Tree:** bleeding-edge 16d4e0013, extracted, nothing installed. Control: the same probes on v1.8.12.
- **Probes:** in their repo, under `tmp/`:
  - `t2535_output_probe.sh`: the allowlist.
  - `t2535_gate_e2e.sh`: the real check-active-task.sh hook, in a scratch project with no active task.
  - `t2535_scan_probe.py`: shell_write_scan.scan with `--output` aimed at a task file.

Gate end to end, no active task:

| Command | bleeding-edge | v1.8.12 | Verdict |
|---|---|---|---|
| `git diff --output /tmp/x.patch` | BLOCKED | allowed | WORKS |
| `git diff --output=/tmp/x.patch` | BLOCKED | allowed | WORKS |
| `git log --output=/tmp/x.log` | BLOCKED | allowed | WORKS |
| `git whatchanged --output /tmp/x` | BLOCKED | allowed | WORKS |
| `git diff-index --output=/tmp/x HEAD` | BLOCKED | BLOCKED | WORKS (stays refused) |
| `git diff HEAD` | allowed | allowed | WORKS (stays read-only) |
| `git log --oneline` | allowed | allowed | WORKS |
| `git check-attr -a README.md` | allowed | BLOCKED | WORKS (T-4368) |
| `git check-ref-format refs/heads/master` | allowed | BLOCKED | WORKS (T-4368) |
| `git diff-index HEAD` | allowed | BLOCKED | WORKS (T-4368) |

`is_bash_safe_command` treats `show --output=`, `diff-tree --output` and `log --output` (space form) as not safe on
bleeding-edge, and as safe on v1.8.12.

Write scanner, `--output` aimed at a task file (hits):

| Command | bleeding-edge | v1.8.12 |
|---|---|---|
| `git diff --output=<task file>` | 2 | 0 |
| `git diff --output <task file>` | 2 | 0 |
| `git log --output=<task file>` | 2 | 0 |
| `git diff HEAD` | 0 | 0 |

Their note: `has_bash_write_pattern` flags `--output` on neither tree. The gate's refusal comes from the allowlist
(not safe, then the no-task branch blocks), and the task-file case from shell_write_scan. That is as designed (AEF
answer, same day).

## Field case for T-4311 — 832 (msgs 46dad1d5, 0abbc762, 2026-10-19)

The v1.8.11 → v1.8.12 upgrade stopped 832's sidecar. A minute later the host cron `sidecar-ensure-1m`
(`fw sidecar ensure --all`, plain cron env) brought it back without TERMLINK_IDENTITY_FILE, so it ran unkeyed. Their syslog
confirms it: `agentic-cron: /opt/832-Workflow-designer: supervisor restarted` at 13:32 UTC.

In v1.8.12 nothing on that path reads project config for identity: `RAIL_IDENTITY_FILE` is read only by `fw rail`. T-4311
(next release, `SIDECAR_RAIL_IDENTITY=1`) makes the sidecar resolve the configured identity itself. 832 will field-test
it in the next release. Until then they re-key after any restart. Putting the env var on the ensure cron line is unsafe:
`ensure --all` is host-wide, so every project would be restarted under one key.

## Round 2 — dimitri-mint-dev boundary probe (msg d4cfc6e7, their T-148, 2026-10-19)

**Setup:** a fresh container per branch, 14 check-project-boundary cases. Control: master = v1.8.12. Subject: bleeding-edge
06580ef92. Report: their docs/reports/T-148-boundary-probe.md.

| Fix | Verdict | Evidence |
|---|---|---|
| T-4395 | **WORKS** | `git -C /work/other`, `cat /work/other/x`, `grep -r foo /work/other/x` and `cat /<nas>/x` go from rc 0 on v1.8.12 to rc 2 |
| T-4395 controls | as expected | `/srv/other` rc 2 on both; inside cases (`git -C proj`, `cat proj file`, `cd proj/docs && git status`) rc 0 on both; regex cases (`sed /^## X/,/^## /p`, `grep /nosuchdir/x/`, `cat /nosuchdir/a/b`) rc 0 on both |
| T-4395 judge case | no false positive | `grep /policy/ f.md` with /policy present: rc 0 |
| T-4408 | not landed yet | `GIT_DIR=/work/other/.git git log -1` is rc 0 on both, as expected |
| T-4409 | did not reproduce | `cd /work/other && git status` is already refused on v1.8.12 (the cd target is checked); their next run uses `/tmp/evil`, since `/tmp` is allowlisted |

**REGRESSION found in L1 on bleeding-edge.** `fw doctor` on a fresh install exits 2 with "index-reindex-hourly is in the
registry but not deployed". This comes from T-4390. v1.8.12 gives rc 0. Installing cron is a deliberate operator step,
so every greenfield install would start red. Fixed before release → T-4413.
