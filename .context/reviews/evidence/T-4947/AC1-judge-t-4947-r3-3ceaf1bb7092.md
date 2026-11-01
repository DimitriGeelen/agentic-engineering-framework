# Reviewer evidence — T-4947 AC#1

- dispatch: `judge-t-4947-r3-3ceaf1bb7092`
- worker kind: `opencode` (vendor `zai`, model `zai-coding-plan/glm-5.3`)
- seat: `opencode`
- reviewed revision: `615ead9b2b72164e5d3a2bf6ab775b8d5c893a00`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `74fb38f443d4144e0d4a482906474f664099b404509b007ba802e852167c5abc`
- result.md sha256: `d28aea7acf1f70b5f939622a9a6b413fe44a68c7a14705f2061e471a669186d8`

## The worker's verdict block

```
1. [AC] Arc Closure section of /approvals still renders as before
VERDICT: not-evaluated
WHY: The criterion depends on /approvals, and that page's screenshot was not captured ("Capture was PARTIAL"); only /approvals/content (.context/working/judge-evidence/T-4947/02-approvals-content.png) and /approvals/continuous-state (.context/working/judge-evidence/T-4947/03-approvals-continuous-state.png) exist, and the dispatch bars a green on an unseen page. Additionally this seat could not visually inspect any image (image input unsupported); all screenshots were read via tesseract OCR, which verifies text but not layout or console errors. What OCR could check is consistent with the criterion: .context/visual/T-4947/arc-closure@1024.png, arc-closure@1440.png, arc-closure@1920.png (crops of /approvals's #section-arc-closure, hashes matching arc-closure.capture.json) each show the 8 arc cards with human-readable demo state lines ("Demo evidence: none recorded — closure asks for a captured artefact showing the headline mechanic working.") and zero --skip/FW_/raw-gate matches, corroborated by the judge's /approvals/content capture and by the source (web/templates/_approvals_content.html:316-418, sanitizer at web/shared.py:2475 dropping --skip-*/FW_*=1 lines). That is supporting evidence only — not a sighting of /approvals, and not a visual one.
GUIDANCE: Recapture the full /approvals page (the missing 01-approvals.png) at the configured widths and re-review with a vision-capable seat: expected to pass on current evidence, but the full page must be seen (and its rendering/console checked visually, not just OCR'd) before this criterion can go green.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
Hashes match the capture manifest. The `arc-closure` visual shots are a crop of `/approvals` between `#section-arc-closure` and `#section-bvp-proposals` — but the full-page `/approvals` capture (`01-approvals.png`) is absent, consistent with the PARTIAL notice. Now reading every screenshot.
The image content isn't visually accessible to me in this run — I'll extract what I can structurally (dimensions, OCR) instead.
OCR of the 1440 crop shows per-arc demo state lines and no bypass flags. Now checking the other widths, the second judge page, the task's Visual Verification checklist, and the source.
Template matches the OCR'd content. Checking the source path for any raw gate/bypass text, and OCR'ing the large judge capture of `/approvals/content` (which contains the same Arc Closure section) for corroboration.
`operator_facing_stderr` (web/shared.py:2475) is the sanitizer that strips `--skip-*` / `FW_*=1` bypass lines — the exact mechanism this criterion guards. Now a piped crop-OCR (no files written) on the judge's own `/approvals/content` capture to corroborate the Arc Closure section.
Investigation complete. Printing the verdict.

---

## Evidence report — T-4947 (revision 615ead9b2b72164e5d3a2bf6ab775b8d5c893a00)

**What was and wasn't captured.** Required pages were `/approvals`, `/approvals/content`, `/approvals/continuous-state`. The judge-evidence directory contains only `02-approvals-content.png` (sha256 `b199c58e…`) and `03-approvals-continuous-state.png` (sha256 `36a2ab46…`). The full `/approvals` capture is absent — the dispatch itself flags "Capture was PARTIAL. You did NOT see: `/approvals`."

**Seat limitation.** This seat could not view images: `Read` on the PNGs returned successfully but the model does not accept image input, so every screenshot was examined via `tesseract` OCR (text content only — no layout, clipping, overlap, or console-error visibility).

**What the OCR evidence shows (corroborating, not conclusive):**
- `.context/visual/T-4947/arc-closure@{1024,1440,1920}.png` (sha256 `0351ed14…`/`4d074470…`/`60ad61e5…`, matching `arc-closure.capture.json`, captured 2026-11-01T11:30:25Z): these are `fw ux shots` crops of `http://192.168.10.107:3000/approvals` from `#section-arc-closure` to `#section-bvp-proposals`. OCR at all three widths shows the "ARC CLOSURE" heading, the queue subtitle ("8 arcs — nothing unestimated (L1) and no high-value work left (L2); demo evidence and anchor advisory shown per arc"), and 8 arc cards each with a verdict badge, "Not yet reviewable…" advisory, a human-readable demo state line ("Demo evidence: none recorded — closure asks for a captured artefact showing the headline mechanic working."), and a "Headline mechanic:" box. Grep of the OCR for `--skip`, `FW_`, `skip-review`, `SKIP` found zero matches at any width. The only "fw"/"--start" strings present are the arcs' own titles/mechanic prose (e.g. an arc titled "fw init detects project shape…"), not gate output.
- Judge's own `02-approvals-content.png` (crop band y=8000–16000 piped through OCR, no files written): "Arc Closure" heading plus the same 8 "Demo evidence: none recorded…" lines, zero `--skip`/`FW_[A-Z]` matches.
- Source at the reviewed revision: `web/templates/_approvals_content.html:316-418` renders each arc card from `a.blocked_reason`, `a.readiness.l4.summary` and `a.headline_mechanic`; `web/shared.py:2475` `operator_facing_stderr` explicitly drops `--skip-[a-z-]+` and `FW_[A-Z_]+=1` lines before operator display.

**Why this is still not-evaluated.** The criterion's Steps name `/approvals` and its Expected includes "the page renders without errors" — a whole-page judgement. The full-page `/approvals` screenshot was never captured, and the dispatch states a green on an unseen page is refused by the ledger and must be returned as `not-evaluated`. The section crops cover only part of the page, and OCR cannot judge rendering quality regardless. The criterion's URL and references are current (the capture manifest used the same URL today), so no restatement is needed — the gap is in evidence capture, not in the criterion text.

---

1. [AC] Arc Closure section of /approvals still renders as before
VERDICT: not-evaluated
WHY: The criterion depends on `/approvals`, and that page's screenshot was not captured ("Capture was PARTIAL"); only `/approvals/content` (`.context/working/judge-evidence/T-4947/02-approvals-content.png`) and `/approvals/continuous-state` (`.context/working/judge-evidence/T-4947/03-approvals-continuous-state.png`) exist, and the dispatch bars a green on an unseen page. Additionally this seat could not visually inspect any image (image input unsupported); all screenshots were read via tesseract OCR, which verifies text but not layout or console errors. What OCR could check is consistent with the criterion: `.context/visual/T-4947/arc-closure@1024.png`, `arc-closure@1440.png`, `arc-closure@1920.png` (crops of `/approvals`'s `#section-arc-closure`, hashes matching `arc-closure.capture.json`) each show the 8 arc cards with human-readable demo state lines ("Demo evidence: none recorded — closure asks for a captured artefact showing the headline mechanic working.") and zero `--skip`/`FW_`/raw-gate matches, corroborated by the judge's `/approvals/content` capture and by the source (`web/templates/_approvals_content.html:316-418`, sanitizer at `web/shared.py:2475` dropping `--skip-*`/`FW_*=1` lines). That is supporting evidence only — not a sighting of `/approvals`, and not a visual one.
GUIDANCE: Recapture the full `/approvals` page (the missing `01-approvals.png`) at the configured widths and re-review with a vision-capable seat: expected to pass on current evidence, but the full page must be seen (and its rendering/console checked visually, not just OCR'd) before this criterion can go green.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
