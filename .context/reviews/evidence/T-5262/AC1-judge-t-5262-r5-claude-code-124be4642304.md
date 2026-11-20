# T-5262 Human AC#1 — evidence report

Reviewer: reviewer-judge-t-5262-r5-claude-code-124be4642304:claude-code, rung-5-panel:claude-code, revision dd232926ab36fcb4ab5a287194cc37dcb02517ac.

**degraded: single-vendor panel.** Fewer vendors can be dispatched than the panel requires, so this
run cannot satisfy a multi-vendor requirement: this verdict is recorded and reported, and the criterion stays open.

Cannot reproduce: I did not re-run the app or the capture; I judged the supplied images, as instructed.

## What I opened

All nine T-5262 crops (home-header, approvals-header, approvals-footer at 1024/1440/1920), the two
judge captures (01-root.png, 02-approvals.png, 1280 px, top of page only), and the T-5260 baseline
(home-header, cron-header, home-footer, cron-footer at the three widths).

## Findings

1. **Home header**: T-5262 home-header@1024/1440/1920 are byte-identical (same sha256) to T-5260
   home-header at each width (aa33db7e…, 8f81efd1…, 22441c8a…). Logo, Work, Knowledge, Architecture,
   Govern, Docs, search, settings and theme toggle are all present.
2. **/approvals header**: T-5260 holds no /approvals shot. The nearest baseline is its cron-header
   (also a Govern page): T-5262 approvals-header is byte-identical to it at all three widths
   (3a5a7de8…, f0c91e0d…, adbef03f…). Same controls, Govern highlighted as the active group.
3. **/approvals footer**: same size (97 px tall) as T-5260 cron-footer at each width; the pixel diff
   is confined to one box on the version line (x 437-773 at 1024, 645-981 at 1440, 885-1221 at 1920;
   y 30-44). Reading the images, the only difference is the build string:
   v1.8.16-be.60-141-g722718588 before, v1.8.16-be.60-175-g1235bb179 now. Rule line, "Agentic
   Engineering Framework" and the "Found a framework bug? fw upstream report …" line are unchanged.
4. **Shots are of the changed code**: the build in the footer, 1235bb179, is a T-5262 commit and has
   the web/app.py change (b73e47ab2) as an ancestor, so the pages were served after the restart.
5. **Judge captures**: 01-root.png and 02-approvals.png show the full menu, ambient strip and page
   content rendering normally at 1280 px; /approvals shows its form ("Engage the brake") intact.
   capture-notes.json records zero console or page errors on both pages. Nothing new is visible.
6. **Visual Verification checklist** (three states, ok at 1024/1440/1920): every control is visible,
   unclipped and without overlap at every width. At 1024 the theme toggle wraps to a second row in
   both headers; the T-5260 baseline shows the same wrap (identical bytes), so it predates this task.

## Limits

- Both pages exceed the 16,000 px capture limit, so the judge captures show the top only; the footer
  was judged from the task's own crop. No home-footer was captured for T-5262 (the criterion asks
  only for the /approvals footer).
- The /approvals comparison uses a different Govern page (/cron) as baseline, since T-5260 has no
  /approvals shot. Header and footer are shared chrome, so I treat this as a valid comparison.

## Verdict

green — menu, header and footer look the same as before; nothing missing or broken; the only
difference is the build identifier in the footer, which is expected content.
