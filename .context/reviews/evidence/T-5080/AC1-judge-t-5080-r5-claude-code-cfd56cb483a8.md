# T-5080 AC1 — "The screen is simple to use" (seat claude-code, rung-5-panel)

Revision: fc1f721975f6afbf2ecec4222c184174810a1a99 (HEAD at review time).

## Method
I ran `bin/fw config components` for real inside a tmux pane (120x40), sent keys with `tmux send-keys`
and captured the screen after each step with `tmux capture-pane` (and with `-e` to see the highlighting).

## Before
`bin/fw config get ABSENT_COMPONENTS` → empty output, rc=0.

## The screen (initial capture)
```
Optional components — what this project includes
Up/Down move   Space include/exclude   Enter save   q quit without saving

 [x] termlink    Cross-terminal sessions and workers (fw termlink, dispatch)
 [x] node        Node.js, runs the TypeScript hooks (Python fallback without it)
 [x] bats        Shell test runner (framework repo tests)
 [x] shellcheck  Shell script linter
 [x] pi          Pi coding agent (workflows with worker_kind: pi)  (not installed)
 [x] ollama      Local model server (ollama-loop workflows)
 [x] litellm     LiteLLM proxy (workflows that set ANTHROPIC_BASE_URL)

[x] included   [ ] excluded on purpose (fw doctor shows OK, not a warning)
```
- Title states purpose; the key help line is on screen at all times (Up/Down, Space, Enter, q).
- Each line has a name and a one-line plain explanation; the legend explains [x] / [ ].
- The cursor line is drawn in reverse video (`ESC[7m ... ESC[0m` seen in `capture-pane -e`), so the
  current position is clearly visible.

## Steps
- Down, Down → cursor moved to `bats` (reverse-video line moved; checkboxes unchanged).
- Space → `[x] bats` became `[ ] bats` immediately; nothing else changed. The toggle is obvious.
- q → screen cleared and printed `Left without saving; nothing changed.`; exit code 0.

## After
`bin/fw config get ABSENT_COMPONENTS` → still empty, rc=0.

## Minor observations (not blocking)
- The "(not installed)" marker on `pi` is useful context; it is shown even though the box is [x].
  That is consistent with "[x] included" meaning "the project wants it", but a first-time reader could
  wonder. Not a defect against this criterion.

## Verdict: green
Readable, the toggle is obvious and instant, q leaves without saving and says so, and the setting stays empty.
