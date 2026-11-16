# T-4944 — can harness review seats see a supplied screenshot?

**Date:** 2026-11-01
**Why it matters:** a render "green" in the verdict ledger must cite every required page's screenshot. For a harness seat (codex, opencode) the runtime records the verdict and cites only the seat's report, so such a seat can never go green on a render criterion. Letting the runtime cite the screenshots is only honest if the seat actually saw them.

## Probe

Both seats got the same brief, run as review dispatches through the normal runtime: `git archive` export, cited screenshot copied in by `lib/review_seat_evidence.py` (T-4933), launched as for a real review. The screenshot was `.context/visual/T-4947/arc-closure@1440.png` (the T-4947 Arc Closure crop). The brief asked:

1. How many cards carry a BLOCKED badge?
2. Quote exactly the first card's link title.
3. Which mechanism did you use?

It also said: answer `CANNOT VIEW` rather than guess.

Ground truth: 8 cards; first title "Onboarding: fw init detects project shape by enumeration, not manifest allowlist".

| Seat | Dispatch | Answer | Verdict |
|---|---|---|---|
| codex | `probe-t4944-codex-5d1b39dbef58` | 8; the exact title; "Used `view_image`" | **Sees images** |
| opencode | `probe-t4944-opencode-c6d68f23c404` | `CANNOT VIEW`: its Read tool returned "Cannot read image (this model does not support image input)" | **Cannot see images**; it said so honestly |

### 2026-11-16 re-run, scripted (T-5176, for T-5175)

`fw reviewer probe-vision <kind>` now runs this probe the same way each time: the screenshot alone in a
throwaway folder, the kind's registered binary in its review-runtime form, the same three questions,
graded against the ground truth (re-checked by eye: still 8 BLOCKED cards and the same first title;
image sha256 `4d0744704c6b7…`). Each run is a line in `.context/reviews/vision-probes.jsonl`.

| Seat | Answer | Verdict |
|---|---|---|
| codex (control) | 8; the exact title; "tools.view_image via functions.exec" | **Sees images** (matches the 2026-11-01 result, so the scripted probe agrees with the manual one) |
| antigravity (agy 1.5.9) | 8; the exact title; "read_file (native image viewing tool)" | **Sees images** |

antigravity was added to the registry after this probe and has had no `vision:` entry, so every render
verdict it gave was refused (T-3786, T-5172). With this result the entry would be `vision: true`;
widening what counts as evidence is the operator's change (T-5175).

## Side observation, checked, not a defect

opencode reported opening the file "with the Read tool". The review runtime launches opencode as `--agent plan --pure` (`agents/termlink/termlink.sh` run.sh, opencode branch). The plan agent is opencode's built-in read-only agent and may read the reviewed code in its export; that is intended, since a reviewer must read code. The tools-off configuration in `policy/review-backends.yaml` (`isolation.tools_off_config`, T-4437) belongs to a different launch path. No write happened and no finding is filed.

## What this means for the provenance rule

- A codex citation of a supplied screenshot can be true: codex views it with `view_image`.
- An opencode citation would be false: its model cannot take images. Sending render criteria to opencode costs a seat and can only ever return not-evaluated (as on T-4947).

## Options put to the operator

1. **Vision-gated citation (recommended):**
   - Each backend in `policy/review-backends.yaml` declares `vision: true|false`; codex `true` (this probe), opencode `false`.
   - For a vision seat, the runtime cites a supplied screenshot only when the seat's verdict names that screenshot's file, so the citation rests on the seat's own statement, not on what it was handed.
   - Render criteria go only to vision seats; opencode judges the other criteria.
2. **Named-file citation only:** the runtime cites any supplied screenshot that the seat's verdict names, with no registry flag. Simpler, but a non-vision seat that names a file without seeing it would be believed.
3. **Keep as is:** only claude seats can go green on render criteria; harness seats keep returning not-evaluated there.
