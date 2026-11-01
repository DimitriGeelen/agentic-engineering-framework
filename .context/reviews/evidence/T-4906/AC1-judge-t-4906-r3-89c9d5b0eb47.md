# T-4906 Human AC#1 — independent review (judge-t-4906-r3-89c9d5b0eb47)

Criterion: Verification text reads at normal size in Watchtower and on GitHub. Reviewed revision 815d65a57.

## Watchtower half
- Read .context/visual/T-4906/verification-open@{1024,1440,1920}.png and cropped the Task Body ## Verification region at each width.
  At all three widths the template guidance lines ("# Shell commands that MUST pass", "# Toolchain hint", "# THE DEFAULT", ...)
  show as monospace text at body size inside the raw Task Body block. There are no bold or large headings, and nothing is clipped or overlapping.
  Visual Verification checklist row "verification-open | Task Body expanded, ## Verification guidance | ok ok ok" holds.
- Live check: curl http://192.168.10.107:3000/tasks/T-4906 -> 200. The task-body block is <code class="nohighlight">, so highlight.js
  does not style it. The page has one <h1> only (id="task-title").
- 01-tasks-t-4906.png shows the page with the task title, ACs and collapsed Task Body, and nothing renders wrongly.
  Screenshots 02-08 (docs/generated, inception, assumptions, settings, settings/models,
  settings/appearance, tasks) render normally and do not bear on this criterion.

## GitHub half
- gh api repos/DimitriGeelen/agentic-engineering-framework/contents/.tasks/completed/T-4930-...md?ref=bleeding-edge
  -H "Accept: application/vnd.github.html" is GitHub's own render of a successor task. Between the Verification heading and the next <h2>
  there are 0 h1-h6 elements. "Shell commands that MUST pass", "Toolchain hint" and "THE DEFAULT" are absent from the HTML.
  The five commands appear as plain paragraph text at normal size.
- Template at 815d65a57 (.tasks/templates/default.md) wraps the guidance in an HTML comment block (the T-4906 note), which
  explains why GitHub hides it.
- I did not view github.com in a browser. The HTML from GitHub's markdown renderer is the same render the browser shows.

## Note
- T-4906's own task file predates the template change and still has raw "#" lines. On GitHub those lines would still render as headings.
  The criterion asks only about tasks created after the change (step 2), so this does not count against it. The task's RECOMMENDATION already discloses it.

Verdict: green.
