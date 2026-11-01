# Reviewer evidence — T-4947 Human AC#1 (dispatch judge-t-4947-r3-f0a60a9bb3f1)

Revision under review: e21eadb07ba6d36bb7e25d0c215620da64d41857

## Verdict: not-evaluated

The judge capture was PARTIAL: no screenshot of the full `/approvals` page exists in
`.context/working/judge-evidence/T-4947/`. It holds only `02-approvals-content.png` (/approvals/content)
and `03-approvals-continuous-state.png` (/approvals/continuous-state, which shows only the continuous-run brake panel).
The criterion's Expected clause includes "the page renders without errors", and that covers the whole of
/approvals and its console. I did not see the whole page and had no access to the console, so I cannot vote green. The brief
says to return not-evaluated in this case.

## What I did see (input for the next seat)

`fw ux shots` crops of the Arc Closure band of /approvals (from #section-arc-closure to #section-bvp-proposals),
at 1024, 1440 and 1920. I checked that the sha256 of each file matches arc-closure.capture.json, and that the
steps file sha256 is 491259fb…08f2, which matches the brief.

- All 8 arcs listed ("8 arcs — nothing unestimated (L1)…"). Each one shows a "Demo evidence:" line reading
  "none recorded — closure asks for a captured artefact showing the headline mechanic working."
- In the demo lines and the not-yet-reviewable advisories: no raw `fw` gate text, no `--skip`, no `FW_` flags.
  The one `--start` that appears is in the arc's own "Headline mechanic" text ("user runs create with --start flag …"),
  which comes from the arc's data. It is not a bypass flag and not in the demo state line.
- Layout: nothing clipped, hidden or overlapping at any width. At 1024 the first arc's Review button
  wraps under its long title. It is still visible and reachable.
- So from what I could see, the Arc Closure band itself meets the demo-line part of the Expected clause.
- "As before": there is no baseline screenshot to compare against, so I could not check this part.
