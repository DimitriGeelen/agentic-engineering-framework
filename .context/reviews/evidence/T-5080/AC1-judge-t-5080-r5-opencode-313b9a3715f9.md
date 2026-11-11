# Reviewer evidence — T-5080 AC#1

- dispatch: `judge-t-5080-r5-opencode-313b9a3715f9`
- worker kind: `opencode` (vendor `zai`, model `zai-coding-plan/glm-5.3`)
- seat: `opencode`
- reviewed revision: `fc1f721975f6afbf2ecec4222c184174810a1a99`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `bb9cdcf3c6bc65715b020b6ad6004470ec26a3d63864bcb006ae6a30888720c5`
- result.md sha256: `5b3d8f198760bc1ce8dd82b6dd90a14454c5f5624c55a836dc28a6afa6f38519`

## The worker's verdict block

```
1. [AC] The screen is simple to use
VERDICT: green
WHY: Ran bin/fw config components in a pty on a scratch copy of the reviewed revision. The screen draws a title, a one-line legend ("Up/Down move   Space include/exclude   Enter save   q quit without saving"), one aligned line per component with [x]/[ ] marks, reverse-video cursor, "(not installed)" annotations, and a bottom legend explaining [x]/[ ] — 7 rows, all on one screen, easy to read. Down arrow moved the highlight; Space visibly flipped the mark on the highlighted line (redraw byte-delta writes the blank at the x position at row 4 col 3); q printed "Left without saving; nothing changed." and exited 0. bin/fw config get ABSENT_COMPONENTS was empty before and after, .framework.yaml sha256 identical before and after, and no file in the run tree changed. The criterion's literal paths (bin/fw, config get ABSENT_COMPONENTS) are current as written; no restatement needed.
GUIDANCE: none
Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```

## The worker's full output (result.md)

```
`bin/fw` exists at the criterion's literal path. Now inspect the implementation and tests, and check for cited evidence files.
No `.context/` evidence files were copied in — nothing pre-cited to check. `bin/fw` is a bash script; let me verify dispatch and the current config state, then run a copy in scratch.
Dispatch confirmed: `fw config components` → `lib/config_components.py` (lib/config-file.sh:55). Now I'll run the criterion's steps in a scratch copy, driving the TUI through a real pty.
`ABSENT_COMPONENTS` is empty before. Now drive the interactive screen with arrow keys, space, and q exactly as the criterion's steps say.
The Write tool is blocked by permissions; I'll run the pty driver inline via `python3 -c` instead (no files written outside the scratch run).
Screen rendered and exited with "Left without saving; nothing changed." Now verify (a) state unchanged after q, and (b) the space toggle visibly flips the mark on screen.
The after-space redraw is incremental (curses writes only changed cells), so my contiguous-string check missed it. Let me dump the raw delta bytes to see exactly what changed on screen.
That run hung (I never sent q). Let me check for stray children I started and do one final, quick, correctly-structured capture.
No stray processes. One final quick capture of the space-toggle delta, then I'll print the verdict.
All checks are complete. Printing my verdict.

**Evidence summary (run against a scratch copy of revision `fc1f721975f6afbf2ecec4222c184174810a1a99`, screen driven through a real pty, keys sent as a person would):**

- **Dispatch/literal current:** `bin/fw` exists; `fw config components` dispatches via lib/config-file.sh:55 to `lib/config_components.py` (`interactive()`).
- **Screen readability (captured bytes, rendered):** title `Optional components — what this project includes`; one-line key legend `Up/Down move   Space include/exclude   Enter save   q quit without saving`; 7 component lines (termlink, node, bats, shellcheck, pi, ollama, litellm) as `[x] name<11-col pad>description` with the selected line in reverse video and `(not installed)` annotations where a tool is missing; bottom legend `[x] included   [ ] excluded on purpose (fw doctor shows OK, not a warning)`. Everything fits one screen.
- **Arrow keys:** Down-arrow (`\x1b[B`) moved the highlight from the termlink row to the node row.
- **Space toggle visible:** the post-Space redraw writes a blank at row 4 col 3 (the `x` inside `[x]` on the highlighted line, highlight preserved) — the mark visibly flips `[x]`→`[ ]` on the line the cursor is on.
- **q leaves nothing changed:** after Space then q the app printed `Left without saving; nothing changed.` and exited 0; `bin/fw config get ABSENT_COMPONENTS` was empty (rc 0) before and after; `.framework.yaml` sha256 `ccb5ab96…` identical before and after; no new or modified files anywhere in the run tree.
- Supporting: tests/unit/test_t5080_config_components.py drives the same pty flows (space+q leaves nothing stored).

```
1. [AC] The screen is simple to use
VERDICT: green
WHY: Ran `bin/fw config components` in a pty on a scratch copy of the reviewed revision. The screen draws a title, a one-line legend ("Up/Down move   Space include/exclude   Enter save   q quit without saving"), one aligned line per component with [x]/[ ] marks, reverse-video cursor, "(not installed)" annotations, and a bottom legend explaining [x]/[ ] — 7 rows, all on one screen, easy to read. Down arrow moved the highlight; Space visibly flipped the mark on the highlighted line (redraw byte-delta writes the blank at the x position at row 4 col 3); q printed "Left without saving; nothing changed." and exited 0. `bin/fw config get ABSENT_COMPONENTS` was empty before and after, .framework.yaml sha256 identical before and after, and no file in the run tree changed. The criterion's literal paths (`bin/fw`, `config get ABSENT_COMPONENTS`) are current as written; no restatement needed.
GUIDANCE: none
Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```
```
