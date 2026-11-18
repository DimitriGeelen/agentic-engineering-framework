# T-5236 Human AC#1 — evidence report (panel seat claude-code, dispatch judge-t-5236-r5-claude-code-4cd0cd03087d)

Revision reviewed: 3b0279ac629ea1b789663a4aafd7ea2d713356ab. Verdict: **green**.

## What I checked

I opened all six supplied images and judged them as given. Cannot reproduce: I did not re-run the app or the capture (the brief says not to).

The three section crops match the sha256 values in `.context/visual/T-5236/hub-profiles.capture.json` (afc8bfa2…, 8dc2909e…, e50cfa1b…), so they are the files `fw ux shots` wrote.

## What the crops show (hub-profiles@1024 / @1440 / @1920)

Section "HUB PROFILES TO FIX", heading "Sends that cannot reach a hub from this host", with "2 notices — the messages keep retrying; each notice clears itself once a send to that hub is delivered".

**Missing-profile card**
- Bold lead: "User root on host dimitrimintdev has no profile for hub demo-ring20-hub", then "— 1 message waiting · since 2026-11-18T15:44". Who, host, hub and count are all on the first line.
- "Fix:" block: "add to /root/.termlink/hubs.toml:", the `[hubs.demo-ring20-hub]` header, `address = "<host:port of hub demo-ring20-hub>"`, `secret_file = "/root/.termlink/secrets/demo-ring20-hub.hex"`, a line saying no hubs.toml on this host names the hub and that `termlink hub status` on the hub's own host prints its address, and a last line telling the operator to place the hub's secret in that secret_file ("agents never write credentials").
- The address is a placeholder, but the card says where the value comes from and which command prints it, and names the secret step and its path. The fix is complete as read from the card.

**Broken-profile card**
- Bold lead: "User root on host dimitrimintdev has a broken profile `demo-lab` for hub demo-lab-hub", then "— 1 message waiting · since 2026-11-18T15:44".
- "Fix (one command, prepared — run it yourself): `bash /opt/999-Agentic-Engineering-Framework/.context/runme/hub-profile-root-demo-lab-hub/runme.sh`", then "It runs `termlink fleet reauth demo-lab`."
- The full command line is visible and unclipped at every width.

## Visual Verification checklist, control by control

| control | 1024 | 1440 | 1920 |
|---|---|---|---|
| missing-profile card (hubs.toml lines) | ok — visible, unclipped, no overlap; the two long explanatory lines wrap inside the block | ok | ok |
| broken-profile card (runme line + command it runs) | ok — the runme line fits on one line; the "since" timestamp wraps mid-date ("2026-11-" / "18T15:44") | ok | ok |

This agrees with the task's own checklist, including both notes it makes about 1024.

## Rendered pages

- 01-approvals: top of /approvals renders normally (nav, brake panel, count tiles, Decisions). The section is further down than the 16,000 px capture limit, so it is judged from the crops.
- 02-approvals-content: top of the /approvals/content fragment, unstyled as expected for a fragment; nothing broken.
- 03-approvals-continuous-state: brake fragment, unstyled as expected; nothing broken.
- The capturing browser reported no console or page errors on any of the three.

## Minor observations (not blocking)

- In the missing-profile block the instruction lines ("add to …:", the parenthetical, "then place …") sit in the same monospace block as the three literal hubs.toml lines, so a copy of the whole block takes prose with it. The lines to paste are still obvious.
- At 1024 the timestamp on the broken card breaks mid-date; cosmetic.
- The screenshots use two demo notices; the live page shows the section only when a real notice exists, so I did not see it with real data.
