# Field-test results — v1.8.14 (bleeding-edge broad release)

Field evidence for the fixes that ride the broad bleeding-edge release, not the v1.8.13 security hotfix
(that one has `field-test-v1.8.13-results.md`). Under T-4146, a fix is released without asking when it has a
positive field test from another project, recorded here.

| Fix | Project | Tip tested | Verdict |
|---|---|---|---|
| T-4426 | ring20-dashboard | 89c4823f3 | **WORKS** |
| T-4350 | dimitri-mint-dev | v1.8.14-be.1 (916df0825) | **WORKS** |

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
