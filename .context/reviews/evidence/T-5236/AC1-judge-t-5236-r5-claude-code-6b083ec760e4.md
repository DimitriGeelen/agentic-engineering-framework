# T-5236 Human AC#1 — evidence report (judge-t-5236-r5-claude-code-6b083ec760e4)

Seat: rung-5-panel:claude-code. Revision reviewed: 6949f1077eaf81ff22c3eb9689c3a14f5941efeb (HEAD at the time of review).

## What I opened

Task visual evidence (section crops from `fw ux shots`, steps file sha256 7b32179d…; file hashes match `hub-profiles.capture.json`):

- hub-profiles@1024-judge-t-5236-r5-claude-code-6b083ec760e4.png (sha256 9a4aed7b…)
- hub-profiles@1440-judge-t-5236-r5-claude-code-6b083ec760e4.png (sha256 bcb70ace…)
- hub-profiles@1920-judge-t-5236-r5-claude-code-6b083ec760e4.png (sha256 1892f03f…)

Judge captures of the touched pages (top of page only for the first two; the pages are 47,291 px and 29,009 px tall):

- 02-approvals-judge-t-5236-r5-claude-code-6b083ec760e4.png: /approvals header, brake panel, counters, first decision card. Renders normally. Does not reach the section.
- 03-approvals-content-judge-t-5236-r5-claude-code-6b083ec760e4.png: /approvals/content fragment (unstyled, as expected for a fragment). Does not reach the section.
- 04-approvals-continuous-state-judge-t-5236-r5-claude-code-6b083ec760e4.png: brake fragment, renders normally.

The capture recorded no console or page errors on the three pages. I did not re-run the app or the capture (cannot reproduce; judged the images as given).

The brief lists the directory `.context/visual/T-5236/` as a "page not seen". It is not a page: it is the folder holding the three crops, and I opened all three.

## What the crops show (same content at all three widths)

Heading "HUB PROFILES TO FIX", sub-heading "Sends that cannot reach a hub from this host", note "2 notices — the messages keep retrying; each notice clears itself once a send to that hub is delivered".

Card 1 (missing profile):
"User root on host dimitrimintdev has no profile for hub demo-ring20-hub — 1 message waiting · since 2026-11-18T15:05", then "Fix:" and a block:
add to /root/.termlink/hubs.toml: / [hubs.demo-ring20-hub] / address = "<host:port of hub demo-ring20-hub>" / secret_file = "/root/.termlink/secrets/demo-ring20-hub.hex" / then place hub demo-ring20-hub's secret (hex) in that secret_file — the operator's step; agents never write credentials

Card 2 (broken profile):
"User root on host dimitrimintdev has a broken profile demo-lab for hub demo-lab-hub — 1 message waiting · since 2026-11-18T15:06", then "Fix (one command, prepared — run it yourself): bash /opt/999-Agentic-Engineering-Framework/.context/runme/hub-profile-root-demo-lab-hub/runme.sh" and "It runs termlink fleet reauth demo-lab."

## Against the Expected clause

- who: "User root on host dimitrimintdev", bold, first words of each card. Met.
- which hub: "for hub <name>", bold. Met.
- how many wait: "1 message waiting", directly after the headline. Met.
- the fix: on the card itself, as copyable lines (card 1) or one prepared command plus the command it runs (card 2). Nothing has to be opened to read it. Met. The address in card 1 is a placeholder the operator fills in; the page cannot know it, and the placeholder says what goes there.

## Visual Verification checklist (task file, 2 rows)

| control | 1024 | 1440 | 1920 | my reading |
|---|---|---|---|---|
| missing-profile card (hubs.toml lines) | ok | ok | ok | visible, unclipped, no overlap; last fix line wraps to two lines at 1024, as the task notes |
| broken-profile card (runme line + command it runs) | ok | ok | ok | visible, unclipped, no overlap; at 1024 the "since" timestamp breaks mid-date ("2026-11-" / "18T15:06") and the runme line sits on its own line — cosmetic, still readable |

Template (web/templates/_approvals_content.html:566-590) matches what the shots show, and the section sits directly above "Ready for you" (#section-verifications).

## Notes that do not change the verdict

- Step 1 of the criterion names the demo notices `demo-hub-t5236` and `demo-dash-t5236` and describes full-page shots with the section "near the bottom". The shots were retaken as section crops with demo notices `demo-ring20-hub` (missing) and `demo-lab-hub` (broken); the task's Visual Verification section says so. The title and Expected clause are met as written; only this description of the evidence in Step 1 is behind.
- Small polish, optional: the timestamp "since 2026-11-18T15:06" could be kept unbroken (white-space: nowrap) so it does not split at 1024.

## Verdict

Recorded: not-evaluated.

My reading of the three crops is that the criterion is met (see above), and I first tried to record green. The ledger refused it:

    REFUSED: required page '/opt/999-Agentic-Engineering-Framework/.context/visual/T-5236/' has no verified screenshot (...: HTTP 404)

The capture took the screenshot folder named in Step 1 of the criterion for a page to visit; it is a directory on disk, so the browser got HTTP 404 and no verified screenshot exists for it. The brief says a criterion that depends on a page the capture did not see must be returned not-evaluated, and I did not use any bypass. Nothing in the work itself is at fault.

What is needed: either reword Step 1 so the folder is not read as a page (name the three files relative to the repo, without a leading absolute directory path), or fix the capture so a `.context/visual/...` directory path in a criterion is not treated as a URL; then re-dispatch. A reviewer who then opens the same three crops should be able to record green.
