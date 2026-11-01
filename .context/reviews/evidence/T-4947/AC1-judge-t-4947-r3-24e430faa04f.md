# T-4947 Human AC#1 — Arc Closure section of /approvals renders as before
Reviewer: reviewer-judge-t-4947-r3-24e430faa04f (rung-3-termlink-single-reviewer), revision 4a75665321c07e02dcbace2c35b1bf25154d6408

Outcome: not-evaluated

## What I checked
- 03-approvals-continuous-state.png (1280px): continuous-state fragment only ("No continuous run armed", "Engage the brake"). No Arc Closure section in it.
- 02-approvals-content.png: 1280x46336 px full-page capture of the /approvals/content fragment. At the scale it reaches me (55x2000) the text is illegible, so I cannot read any arc's demo-state line or check it for raw fw gate text, --skip or FW_ flags.
- The dispatch reports the capture was PARTIAL: /approvals itself (the page the criterion names) was not captured.
- The dispatch reports the task file has no "## Visual Verification" section, so the render evidence gate does not pass.

## Why not-evaluated
The criterion depends on /approvals, which I did not see, and the only fragment that could hold Arc Closure is unreadable at the resolution I got. Under the T-3986 ruling, I record no amber/red/green on a page I did not see.

## Needed
1. Capture /approvals (and an Arc Closure-scoped crop or element screenshot at a readable size).
2. Add a "## Visual Verification" table to T-4947 with shots at every UX_SHOT_WIDTHS width (fw ux shots T-4947 ...).
3. Re-dispatch to a reviewer that can see the Arc Closure lines.
