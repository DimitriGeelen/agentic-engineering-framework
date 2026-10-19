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
