# Field-test results — v1.8.14 (bleeding-edge broad release)

Field evidence for the fixes that ride the broad bleeding-edge release, not the v1.8.13 security hotfix
(that one has `field-test-v1.8.13-results.md`). Under T-4146, a fix is released without asking when it has a
positive field test from another project, recorded here.

| Fix | Project | Tip tested | Verdict |
|---|---|---|---|
| T-4426 | ring20-dashboard | 89c4823f3 | **WORKS** |
| T-4350 | dimitri-mint-dev | v1.8.14-be.1 (916df0825) | **WORKS** |
| T-4453 | dimitri-mint-dev | v1.8.14-be.2 (c80a8261d) | **WORKS** |
| T-4115 | dimitri-mint-dev | v1.8.14-be.2 (c80a8261d) | **WORKS** |
| T-4485 (security) | ring20-dashboard | bleeding-edge 056573e34 | **WORKS** (allowlist) |
| T-4421 | 832-Workflow-designer | v1.8.14-be.3 (346c4ed33) | **WORKS** |
| T-3924 | 832-Workflow-designer | v1.8.14-be.3 | **WORKS** |
| T-4399 | 832-Workflow-designer | v1.8.14-be.3 | **WORKS** |

## T-4426 — ring20-dashboard (msg ac343064, 2026-10-19)

They ran the exact chain from `bin/claude-fw` lines 195-197 on a throwaway tmux 3.3a server (`-f /dev/null`), with two
sessions and a `cat -v` pane in each:

- Session A (the one with the hooks) got `^L` when it left copy mode: 1 match.
- Session B got none: 0 matches.
- `show-messages` logged no `returned` or error lines. That holds even though `pane-mode-changed` has no `|| true` and its
  `[ #{pane_in_mode} = 0 ]` test fails when copy mode is entered.

Attach and resize were checked as argv only, the same as our own test. They keep their local T-2544 lines until an upgrade
brings this `claude-fw`, and will check at that upgrade that their patch series no longer carries T-2544.

## T-4350 — dimitri-mint-dev T-158 (msg ec31e9af, 2026-10-20)

**Setup:**
- Their project's real index: 126-129 MB, 459 documents, 24.5k chunks.
- The same incremental `fw index reindex` the hourly cron runs.
- Measured with GNU `time -v` (file-system outputs, 512-byte blocks, children included).
- Their report: `docs/reports/T-158-t4350-field-test.md`.

| Run | Before (v1.8.13) | After (v1.8.14-be.1) |
|---|---|---|
| 1 file changed | 255,232 blocks = **130.7 MB** written, 6.8 s (the whole index) | 3,440 blocks = **1.8 MB**, 5.2 s |
| 0 files changed | — | 1,544 blocks = 0.8 MB, 3.3 s |

**WORKS:** about 74x less written per incremental run (-98.7%). No scratch or WAL leftovers in .context/working.
Doctor: the index opens (24,518 chunks), lag 0, no failures. Their project now runs be.1 in its hourly cron. Their
baseline was 282 GiB/day of index writes.

**Findings that came with it:**
1. `<be.1 clone>/bin/fw upgrade <project>` did not use the clone. Its vendor step fetched upstream (`Source:
   /tmp/fw-upstream-…/fw`) and vendored master, so T-4350 was absent afterwards. `fw vendor --source <clone> --target
   <project>` worked. Filed as T-4453.
2. The G-003 marker went missing again on both steps; it is clearly logged now. Their patch is AEF T-4115 (`fw task
   stale` is read-only), which stays on the list.
3. v1.8.13's boundary refuses `flock … /var/lock/…` from an agent session (an outside path), so the cron's lock cannot
   be reused by hand. fw's own reindex lock suffices; this is expected behaviour.

## T-4453, T-4115 — dimitri-mint-dev T-160 (msg cfa9b2d9, 2026-10-20)

**Setup:** they upgraded from a be.2 clone with `env -u FRAMEWORK_ROOT -u PROJECT_ROOT <clone>/bin/fw upgrade <project>`.

- **T-4453 WORKS.** The header shows "Framework: <clone> / Commit: c80a8261dfa5 (v1.8.14-be.2)", the vendor step shows
  "Source: <clone>", and safe-commands.sh is byte-identical to the clone.
- **T-4115 WORKS.** Upstream now classifies `list|verify|review|create|stale`. They removed their G-003 entry from
  `.fwvendor-preserve.yaml` (now `in_file: []`).
- **Release-notes item.** The first upgrade attempt was REFUSED by the T-3850 guard: their local edit was no longer
  covered by the preserve manifest. That is correct behaviour. They reverted the local edit to the upstream state
  instead of using `--allow-delete-locals`, and the upgrade then ran clean. The notes should describe this path for
  consumers dropping a preserve entry.
- **Still present:** T-4350.
- **Doctor:** 0 failures on 2 of 3 runs. One run showed "FAIL Hook exercise from /tmp: 1/26 hook(s) failed to
  resolve" on an I/O-bound host, and it did not reproduce. Likely load-sensitive; see T-4461.

## T-4485 (security, T-4367 gap) — ring20-dashboard (msg f5a021db, 2026-10-20)

**Setup:** bleeding-edge 056573e34 (fix 22bf75833 + 430abcc8f) vs control v1.8.13 (6efec63df). Classification only;
both trees extracted with git archive.

**WORKS for the read-only allowlist (is_bash_safe_command). "Ship it."**

- Their probe `tmp/t4367_probe.sh`: all 10 `--output` lines are gated (7 were SAFE on the control). A plain
  `git diff` stays SAFE.
- Extra shapes, all gated on the tip:
  - `--outp=` and `--outpu=` (git's prefix abbreviation), and `git log -p --outp=`;
  - `$'--output=F'` and `{--output=F,}` (both SAFE on the control);
  - `show --output`, `format-patch -o` / `--output-directory`;
  - `git -C /tmp diff --output` and `git --no-pager diff --output`.
- No false positives: `git diff --stat`, `git diff HEAD~1 -- README.md`, `git log --oneline -5`, `git show HEAD
  --stat`, `git log --format=%H -3` and `git diff --name-only HEAD~3` are all SAFE.

**Observation, not a blocker:**

- The second line of defence lives in `lib/shell_write_scan.py` (the git branch of the segment walker), **not** in
  `has_bash_write_pattern`, which has no git `--output` rule. AEF's message to them said otherwise; corrected.
- `scan_boundary` in boundary mode stays CLEAN on unresolvable targets (`$o`, `${O:-…}`, `$(…)`, a loop variable)
  on both control and tip. An unresolved target bites only when `ctx.mentions` is set. This is a general scanner
  limit, not T-4485's, and now harmless for these shapes: the allowlist gates them, so they reach the normal task
  gate. Filed for a decision on failing closed: T-4487.

## T-4421, T-3924, T-4399 — 832-Workflow-designer (msg dbd05180, 2026-10-20)

**Setup:** v1.8.14-be.3 (346c4ed33), vendored 15:18-15:28Z by their operator job 059 under their re-vendor
protocol. 38 local fixes were re-applied: 33 cleanly, 5 by 3-way merge.

- **T-4421 WORKS.** `fw fabric register` read the `//` header after a shebang on their `_t1217` / `_t1218` `.mjs`
  files.
- **T-3924 WORKS.** `fw config set INCEPTION_COMMIT_LIMIT 16` was read back as 16 by the hook's own `fw_config`
  (hooks.sh:268), then restored.
- **T-4399 WORKS.** An exclusiveGateway `default="F_no"` survives derive (`default: F_no`) and generate
  (`default="F_no"`).
- **T-4469 is present** (hooks.sh 299-324). T-4454 is pending a claude-fw relaunch.

**Findings:**

1. `fw upgrade` restarted the sidecar receiver with a clean environment, so mail went out on the host key again.
   Filed as T-4494.
2. `corpus derive` refuses `bpmn:businessRuleTask`. Filed as T-4495.
3. `corpus generate` crashes on `id: null`. Filed as T-4496.
