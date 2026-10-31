# T-4904 Human AC#1 — reviewer judge-t-4904-r3-2d8e1b26d6ee (revision 491ce18f2)

Criterion: task ids on a task page are links and the page otherwise reads as before.

## Live page (http://192.168.10.107:3000/tasks/T-4884, fetched 2026-10-31)
- The Task Body has `<a href="/tasks/T-4890">T-4890</a>` at all three body mentions: the ### Agent AC line
  ("receiver-side safeguard is post-freeze T-4890"), the "0506 told the result ... T-4890 for the receiver guard"
  line, and the ## Context "receiver-side guard ... is post-freeze T-4890." line. The page also links other ids (T-077, T-1550, T-1811 ...).
- `ls .tasks/active/T-4890-*` in Verification stays plain text. This is intended: the regex
  `(?<![\w/.#-])` leaves paths whole (commit c84c33bd0).
- GET /tasks/T-4890 returns 200 with the title "Task T-4890 — ...", so the link opens the right task.
- The Episodic Summary and Outcomes sections outside the Task Body are unlinked text, as they were before. The criterion is about the body.

## Code (c84c33bd0, web/blueprints/tasks.py, task_detail.html)
- `_link_task_ids` only wraps ids in an <a> and leaves text inside existing anchors alone. Lines outside Context/Agent
  are still `_html_escape(line)`, now with id links, so the body text is the same character for character.
- The template adds `class="nohighlight"` to the body's <code>. This is T-4906's intentional fix (guidance # lines no longer render
  as bold headings), so it is not a T-4904 regression.

## Screenshots
- body-links-open@1024/1440/1920: the Task Body is expanded as a monospace pre block. T-4884 and T-4890 are underlined links.
  The rest is unchanged raw markdown. Long lines are cut off at the pre edge as before (pre overflow), with no overlap.
  The header, metadata, BVP, AC list and outcomes look normal at every width. This matches the checklist row (ok/ok/ok).
- 01-tasks-t-4884: the current page with the body collapsed. The AC list shows T-4890 links, and the layout is intact.
- 02-inception, 03-assumptions, 04-tasks: other pages in the judge plan. They are cited as required, and none relates to this criterion.

Verdict: green.
