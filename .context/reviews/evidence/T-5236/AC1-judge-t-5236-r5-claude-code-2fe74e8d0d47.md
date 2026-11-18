# T-5236 Human AC#1 — evidence report (panel seat claude-code, rung 5)

Revision reviewed: 3b1c610ab604ef31603f8d982181af8416e6ffe5

## What I did
Opened the three task screenshots named in the criterion and the three judge-evidence captures.
The task screenshots are full-page (45,000–50,000 px tall), so I cropped the stored PNGs (no re-capture,
no app run — cannot reproduce / not attempted, per brief) to the "Hub profiles to fix" section.
Crops are byte-for-byte regions of the task's own images:
- `crop-section@1024-*.png` = hub-profiles@1024.png rows 44800–45800
- `crop-section@1440-*.png` = hub-profiles@1440.png rows 42082–43482
- `crop-end-of-content@1920-*.png` = hub-profiles@1920.png rows 39700–40900

## Findings

### 1024 — section fully shown, clean
Heading "HUB PROFILES TO FIX", sub-heading "Sends that cannot reach a hub from this host — 2 notices —
the messages keep retrying; each notice clears itself once a send to that hub is delivered", directly above
"READY FOR YOU".
- Missing card: "User root on host dimitrimintdev has no profile for hub demo-hub-t5236 — 2 messages
  waiting · since 2026-11-18T11:51". "Fix:" then a code block: `add to /root/.termlink/hubs.toml:`,
  `[hubs.demo-hub-t5236]`, `address = "<host:port of hub demo-hub-t5236>"`,
  `secret_file = "/root/.termlink/secrets/demo-hub-t5236.hex"`, then "place hub demo-hub-t5236's secret (hex)
  in that secret_file — the operator's step; agents never write credentials" (last line wraps, as the
  task's checklist notes; nothing clipped).
- Broken card: "User root on host dimitrimintdev has a broken profile `demo-dash-t5236` for hub
  demo-dash-t5236 — 0 messages waiting · 1 refused, resend after the fix · since 2026-11-17T14:51".
  "Fix (one command, prepared — run it yourself):" `bash /opt/999-Agentic-Engineering-Framework/.context/runme/hub-profile-root-demo-dash-t5236/runme.sh`,
  "It runs `termlink fleet reauth demo-dash-t5236`."
Both cards give who (user+host), which hub, how many wait, and a fix that can be acted on from the card.
No overlap, no clipping, both cards inside the content column.

### 1440 — section shown, wording identical, but the image is damaged
Same text for both cards, all readable. The screenshot has blank rectangles painted over the page:
the missing-profile card loses its background, right border and bottom border right of x≈763, and the
"Ready for you" block below is blanked right of x≈525. Text of the long last fix line is still drawn.
Sharp rectangular edges crossing unrelated sections, and absent at 1024, look like a full-page capture
artifact on a ~47,000 px page rather than a layout fault — but from the image alone I cannot prove that,
and the image does not show a clean card at 1440.

### 1920 — the section is NOT in the screenshot
hub-profiles@1920.png is 45,553 px tall but has no painted content below row 40,648; it stops inside
the "Messages waiting for a recipient" list ("From 010-termlink — waiting 17.5 h · unh…", with the same
blank-rectangle damage from x≈525). "Hub profiles to fix" does not appear anywhere in it.
So the task's Visual Verification cells "1920 = ok" for both cards are not supported by the stored
evidence (the task says the section was "checked at each width in a cropped view"; no such crop is stored).

### Judge-evidence captures
02-approvals, 03-approvals-content, 04-approvals-continuous-state show only the top of /approvals
(viewport-only per capture-notes.json) and the brake panel; no errors visible, the section is far below
and (demo notices removed) would not be on the live page anyway. They neither support nor contradict the criterion.

## Verdict: amber
Content and wording of the cards meet the Expected clause (verified at 1024, text confirmed at 1440).
Not green because the criterion's own step 1 names three screenshots and one of them (1920) does not
show the section at all, and a second (1440) shows the first card damaged.

Small wording note (not blocking): the missing-profile fix has a placeholder
`address = "<host:port of hub …>"` — the operator must know the hub's address and secret; that is
inherent to a missing profile and the card says so plainly.
