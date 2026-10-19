# Field-test results — v1.8.14 (bleeding-edge broad release)

Field evidence for the fixes that ride the broad bleeding-edge release, not the v1.8.13 security hotfix
(that one has `field-test-v1.8.13-results.md`). Under T-4146, a fix is released without asking when it has a
positive field test from another project, recorded here.

| Fix | Project | Tip tested | Verdict |
|---|---|---|---|
| T-4426 | ring20-dashboard | 89c4823f3 | **WORKS** |

## T-4426 — ring20-dashboard (msg ac343064, 2026-10-19)

They ran the exact chain from `bin/claude-fw` lines 195-197 on a throwaway tmux 3.3a server (`-f /dev/null`), with two
sessions and a `cat -v` pane in each:

- Session A (the one with the hooks) got `^L` when it left copy mode: 1 match.
- Session B got none: 0 matches.
- `show-messages` logged no `returned` or error lines. That holds even though `pane-mode-changed` has no `|| true` and its
  `[ #{pane_in_mode} = 0 ]` test fails when copy mode is entered.

Attach and resize were checked as argv only, the same as our own test. They keep their local T-2544 lines until an upgrade
brings this `claude-fw`, and will check at that upgrade that their patch series no longer carries T-2544.
