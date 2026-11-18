# T-5236 Human AC#1 — evidence report (panel seat claude-code, rung 5)

Revision reviewed: 2ca0b13d20ffd3b6b236a7c493aad6423629059f
Verdict: **green**

## What I opened

The three section crops named in the criterion (sha256 matches `hub-profiles.capture.json`):

- hub-profiles@1024.png — 9a4aed7b…f66e
- hub-profiles@1440.png — bcb70ace…0146
- hub-profiles@1920.png — 1892f03f…e308

and the three rendered-page screenshots (01-approvals, 02-approvals-content, 03-approvals-continuous-state).
Cannot reproduce: I did not re-run the app or the capture; I judged the supplied images.

Freshness: the crops were written 2026-11-18 16:06 +0100, after the last commit to
`web/templates/_approvals_content.html` (beb37d960, 15:50 +0100). The reviewed HEAD commit
(16:31) touches only `lib/…/profile_notices.py`, `operator_pending.py` and a test, not the template,
so the crops show the card markup of the reviewed revision.

## What the cards show (same text at all three widths)

Section "HUB PROFILES TO FIX", heading "Sends that cannot reach a hub from this host",
subline "2 notices — the messages keep retrying; each notice clears itself once a send to that hub is delivered".

Card 1 (missing profile):
- Headline (bold): "User root on host dimitrimintdev has no profile for hub demo-ring20-hub" then "— 1 message waiting · since 2026-11-18T15:05"
- "Fix:" followed by a code block: `add to /root/.termlink/hubs.toml:`, `[hubs.demo-ring20-hub]`,
  `address = "<host:port of hub demo-ring20-hub>"`, `secret_file = "/root/.termlink/secrets/demo-ring20-hub.hex"`,
  and "then place hub demo-ring20-hub's secret (hex) in that secret_file — the operator's step; agents never write credentials".

Card 2 (broken profile):
- Headline (bold): "User root on host dimitrimintdev has a broken profile `demo-lab` for hub demo-lab-hub" then "— 1 message waiting · since 2026-11-18T15:06"
- "Fix (one command, prepared — run it yourself):" `bash /opt/999-Agentic-Engineering-Framework/.context/runme/hub-profile-root-demo-lab-hub/runme.sh`
- "It runs `termlink fleet reauth demo-lab`."

## Against the Expected clause

- who (user + host), which hub, how many waiting, the fix: all four are present on each card, in the
  order the criterion gives ("user X on host Y has no/broken profile for hub Z — N waiting — fix: …").
- actionable without opening anything else: card 1 gives the file, the exact section and keys and the
  secret path; card 2 gives a copyable one-line command and says what it runs. The `address` value is
  a placeholder because the page cannot know the hub's address; it is labelled as such.

## Visual Verification checklist, control by control

| control | 1024 | 1440 | 1920 | what I saw |
|---|---|---|---|---|
| missing-profile card (hubs.toml lines) | ok | ok | ok | all five fix lines visible inside the card; at 1024 the last line wraps onto a second line ("credentials"), nothing clipped, no overlap |
| broken-profile card (runme line + command it runs) | ok | ok | ok | runme line fully visible on one line at every width; at 1024 it moves under the "Fix (…)" label and the "since" timestamp wraps mid-date ("2026-11-" / "18T15:06"), cosmetic; "It runs termlink fleet reauth demo-lab" visible |

Both match the task's own checklist cells and notes.

## Rendered pages

- 01-approvals: top of /approvals (page over the full-page limit, section is further down, judged from the crops). Renders normally, no breakage visible.
- 02-approvals-content: top of the unstyled fragment /approvals/content; renders, section further down.
- 03-approvals-continuous-state: the brake fragment, renders.
The capturing browser reported no console or page errors on all three.

## Minor observations (not blocking)

- The section heading wraps to two lines at 1024 and the subline sits beside it; readable.
- At 1024 the "since" timestamp breaks mid-date; a non-breaking wrapper would tidy it.
