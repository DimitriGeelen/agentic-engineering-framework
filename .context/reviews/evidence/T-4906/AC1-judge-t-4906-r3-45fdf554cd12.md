# T-4906 Human AC#1 — independent review (judge-t-4906-r3-45fdf554cd12), revision 5afbbfbf3

Criterion: Verification text reads at normal size in Watchtower and on GitHub.

## Watchtower (step 1)
- Fetched the live page http://192.168.10.107:3000/tasks/T-4906 with curl (2026-11-01).
  The Task Body is served as `<pre><code class="nohighlight">`, so highlight.js (loaded on the page) skips it.
  Inside that block the only tags are code/pre/a/span (task-ID links). There are no h1-h6 tags. The `## Verification`
  section and its `# Shell commands that MUST pass…` lines are plain escaped text.
- Screenshot verification-open@1440 (cropped by me to y=4900..5900): the guidance lines in Verification
  are monospace, the same size and weight as the rest of the body, grey on light, with no bold or enlarged headings.
  The @1024 and @1920 captures come from the same steps file (sha a6ba9f9f…), and the Task Body in them looks the same.
- 01-tasks-t-4906.png (judge capture, 2026-11-01) shows the page with Task Body collapsed; nothing on the page is a
  bold heading except the normal section headers.

## GitHub (step 2)
- `git ls-remote github refs/heads/bleeding-edge` = 5afbbfbf390c… (the reviewed revision), so successor tasks are on GitHub.
- `gh api …/contents/.tasks/completed/T-4930-no-verb-or-watchtower-control-for-the-op.md?ref=bleeding-edge -H "Accept: application/vnd.github.html"`:
  between the Verification `<h2>` and the next `<h2>` (RCA) there are 0 heading elements. None of the strings
  "Shell commands that MUST pass", "Toolchain hint" or "THE DEFAULT" appear (the HTML comment is hidden). The five commands
  render as normal paragraph text. This confirms the agent's evidence block by re-running it myself.

## Pages not captured
/settings/appearance and /tasks were not captured. This criterion does not depend on either: it names /tasks/T-4906 and a
GitHub task page, and I checked both.

Verdict: green.

## Recording outcome
The ledger refused green: "required page '/settings/appearance' has no verified screenshot (not captured: capture is capped at 6 pages)".
I did not see /settings/appearance or /tasks, so this is recorded as not-evaluated, not green. On everything I could see, both
surfaces the criterion names meet it. A re-dispatch whose capture includes /settings/appearance and /tasks should be able to record green.
