# T-4906 Human AC#1 — reviewer judge-t-4906-r3-2bbcd624da21 (rung-3, revision 05ad4030d)

Verdict: not-evaluated

## Watchtower half (seen)
- verification-open@1024/1440/1920 (fw ux shots, Task Body expanded on /tasks/T-4906): cropped the
  1440 shot at y=5000-6400. The ## Verification guidance lines ("# ...") render as monospace
  plain text at body size inside the Task Body block. No large bold headings. Same at 1024 and 1920.
- 01-tasks-t-4906.png: page loads; Task Body collapsed; no oversized Verification text visible.
- This half meets the criterion.

## GitHub half (not seen)
- Step 2 needs the GitHub rendering of a task created after the change. No screenshot of any
  GitHub page was supplied, and this sandbox cannot render GitHub. The brief also says capture was
  PARTIAL: /tasks and /api/task/create (the task-creation path) were not seen.
- Structural input only (not a render): the successor task .tasks/active/T-4930-*.md has its
  ## Verification guidance inside one <!-- ... --> block, which GitHub normally hides. This
  supports the claim but is not the rendered page the criterion asks for.
- Note: the repo's git remote is OneDev (onedev.docker.ring20...), not GitHub. The reviewer of
  step 2 should confirm which forge "on GitHub" means; if GitHub is no longer used, the operator
  may want to restate step 2.

## Needed
A reviewer that can open a post-change task (e.g. T-4930) on GitHub, or on the forge that replaced it,
and check its Verification section.

## Other screenshots read
02-docs-generated, 03-inception, 04-assumptions, 05-settings: render normally. None shows a task's
Verification section, so they do not bear on this criterion.
