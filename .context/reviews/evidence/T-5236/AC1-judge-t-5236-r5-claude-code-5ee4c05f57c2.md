# T-5236 Human AC#1 — evidence report (judge-t-5236-r5-claude-code-5ee4c05f57c2, seat claude-code, rung-5-panel)

Revision reviewed: bbddc108498817326e81ceba0d7e68ded1707c8b. Verdict: **green**.

Cannot reproduce: I did not re-run the app or the capture (image-evidence criterion; judged the supplied images as given).

## What I opened

Step 1 names the folder relative to the project root (.context/visual/T-5236); all three files exist there and their
sha256 match hub-profiles.capture.json (9a4aed7b…, bcb70ace…, 1892f03f…). Each is cropped to the "HUB PROFILES TO FIX" section.

- hub-profiles@1024-judge-t-5236-r5-claude-code-5ee4c05f57c2.png
- hub-profiles@1440-judge-t-5236-r5-claude-code-5ee4c05f57c2.png
- hub-profiles@1920-judge-t-5236-r5-claude-code-5ee4c05f57c2.png
- 01-approvals-judge-t-5236-r5-claude-code-5ee4c05f57c2.png, 02-approvals-content-judge-t-5236-r5-claude-code-5ee4c05f57c2.png, 03-approvals-continuous-state-judge-t-5236-r5-claude-code-5ee4c05f57c2.png (rendered pages; top of page only,
  the section is further down, so these show only that the pages render with no breakage in the header, brake panel and counters)

## What the cards show (same text at all three widths)

Section heading "Sends that cannot reach a hub from this host", sub-line "2 notices — the messages keep retrying; each
notice clears itself once a send to that hub is delivered".

Card 1 (missing): bold "User root on host dimitrimintdev has no profile for hub demo-ring20-hub" — "1 message waiting ·
since 2026-11-18T15:05". "Fix:" followed by a code block: "add to /root/.termlink/hubs.toml:", "[hubs.demo-ring20-hub]",
'address = "<host:port of hub demo-ring20-hub>"', 'secret_file = "/root/.termlink/secrets/demo-ring20-hub.hex"', and
"then place hub demo-ring20-hub's secret (hex) in that secret_file — the operator's step; agents never write credentials".

Card 2 (broken): bold "User root on host dimitrimintdev has a broken profile [demo-lab] for hub demo-lab-hub" —
"1 message waiting · since 2026-11-18T15:06". "Fix (one command, prepared — run it yourself):"
"bash /opt/999-Agentic-Engineering-Framework/.context/runme/hub-profile-root-demo-lab-hub/runme.sh", then
"It runs termlink fleet reauth demo-lab."

## Against Expected

- who (user root, host dimitrimintdev): in the bold lead of each card. Met.
- which hub: named in the bold lead. Met.
- how many wait: "1 message waiting" right after the lead. Met.
- the fix: shown inside the card, full file path, full lines to add / full command with absolute path, and the command the
  script runs. Nothing has to be opened to act. The address placeholder and the secret are values only the operator has,
  and the card says so. Met.
- Reads as "user X on host Y has no/broken profile for hub Z — N waiting — fix: …". Met, literally.

## Visual Verification checklist, control by control

| control | 1024 | 1440 | 1920 |
|---|---|---|---|
| missing-profile card (hubs.toml lines) | visible, unclipped, no overlap; last fix line wraps onto a second line (as noted) | ok, single lines | ok, single lines |
| broken-profile card (runme line + command it runs) | visible, unclipped, no overlap; runme line on its own line under the label; "since" timestamp wraps mid-date "2026-11-" / "18T15:06" (as noted, cosmetic) | ok | ok |

No text is cut off at the card edge at any width; the long runme path fits inside the card at 1024.

## Minor, not blocking

- At 1024 the timestamp breaks inside the date. Cosmetic; still readable. A no-wrap on the "since …" span would fix it.
