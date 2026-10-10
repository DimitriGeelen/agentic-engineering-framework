# T-4032 fix review round 4 — codex (2026-10-10)

Read-only confirmation of 15ac86646..3b8cee97b. Final answer only.

**Verdict: SHIP** for the emergency hotfix. References are to `3b8cee97b`.

**Round-3 must-fix: FIXED.** Accepted signals are refreshed during polling in `bin/claude-fw:528` (plain watcher) and `:1037` (TermLink). A long wrap-up no longer ages the signal out before natural exit reaches the parent’s freshness check at `:1125`. TermLink refreshes before inspecting the exit marker (`:1084`).

The four failure cases:

- **Deleted signal recreated:** Neither new `touch -c` creates a missing file. Observed absence resets acceptance at `:510` / `:1070`.
- **Restart forced after cancellation:** The new refresh does not recreate a deleted request. **An existing cancellation race remains:** deletion during handover can still be undone by the unchanged plain `touch` at `:573` / `:1061`, followed by termination. This patch does not introduce that race or fully guarantee cancellation.
- **Stop-driver yielding forever after Claude exits:** No new indefinite refresh loop in the normal lifecycle. The plain parent kills and joins its watcher after Claude returns (`:1101–1107`); TermLink breaks on the exit marker (`:1084–1086`). Refreshing therefore ends.
- **Fresh signal kills the new run:** The watcher is stopped before restart processing, and the signal is removed before relaunch (`:1221`). TermLink’s previous polling loop has also ended. The new refresh cannot carry that signal into the next run.

One minor consequence: refreshing mtime can make the handover banner report “NO handover since the restart signal” despite a handover newer than the original request (`:1215–1216`). This is diagnostic, not a restart blocker.

Validation: `bash -n` passed. The added tests check freshness and deletion, but **do not exercise natural exit through the parent restart branch or TermLink**. Bats was not run because it writes files. No files were edited.
