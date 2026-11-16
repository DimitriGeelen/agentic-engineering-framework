# T-5172 Human AC#1 — evidence report (seat claude-code, dispatch judge-t-5172-r5-claude-code-a252be6293dc)

Revision reviewed: 2793879cb5b5a72badf90b6e3fc618888a9c9e08

## Outcome: not-evaluated

The capture supplied to this seat was PARTIAL: no screenshot of `/file/.git/config` (step 2).
The criterion's Expected clause has two halves; the second (step 2 is refused) depends on a page
I did not see, so I do not vote on the criterion.

## Step 1 — /file/scripts/agent-listeners.sh (seen)

- `01-file-scripts-agent-listeners-sh-judge-t-5172-r5-claude-code-a252be6293dc.png`: page titled "scripts/agent-listeners.sh", the script
  body rendered with line numbers 1-232 and syntax colouring (comments green italic, strings red,
  keywords bold). Browser recorded no console or page errors.
- Visual checklist state `script-file` at 1024 / 1440 / 1920
  (`script-file@1024-judge-t-5172-r5-claude-code-a252be6293dc.png`, `script-file@1440-judge-t-5172-r5-claude-code-a252be6293dc.png`, `script-file@1920-judge-t-5172-r5-claude-code-a252be6293dc.png`): title, line
  numbers and highlighted code visible at every width, no overlap. At 1024 a few long lines
  (124, 198, 222, 226, 227) run past the right edge of the code box; whether the box scrolls
  horizontally cannot be told from a still image. At 1440 and 1920 nothing is cut.
- Live probe from this sandbox: GET /file/scripts/agent-listeners.sh -> HTTP 200 (128560 bytes).

Step 1 matches the Expected clause.

## Step 2 — /file/.git/config (NOT seen as a rendered page)

- No screenshot was captured.
- Live probe from this sandbox (not a rendered page, so supporting information only):
  GET /file/.git/config -> HTTP 404 (70815 bytes, the Watchtower HTML shell); the body contains no
  git-config markers (repositoryformatversion / [core] / [remote: 0 matches).
  This is consistent with "refused (not served)", but it is a curl status, not the page.

## /config (seen)

- `03-config-judge-t-5172-r5-claude-code-a252be6293dc.png`: the configuration page renders (settings table, no error page). The image is
  too tall to read individual rows at the resolution available to me, so I did not confirm the
  VIEWABLE_DIRS row from it.

## What is needed

A capture of /file/.git/config (the refusal page), then a reviewer that sees it judges the criterion.
