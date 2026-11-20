===VERDICT===
format: verdict/1
task: T-5303
reviewer: reviewer-judge-t-5303-r5-claude-code-937e488ccdf2:claude-code
round: 1
vote: green
failed: []

## AC1 Watchtower pages render as before after the web/app.py change
Vote: green
Evidence: image: .context/reviews/evidence/T-5303/home-header@1024-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1024,166
Location: .context/reviews/evidence/T-5303/home-header@1024-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1024,166
Evidence: image: .context/reviews/evidence/T-5303/home-header@1440-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1440,104
Location: .context/reviews/evidence/T-5303/home-header@1440-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1440,104
Evidence: image: .context/reviews/evidence/T-5303/home-header@1920-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1920,104
Location: .context/reviews/evidence/T-5303/home-header@1920-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1920,104
Evidence: image: .context/reviews/evidence/T-5303/approvals-header@1024-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1024,166
Location: .context/reviews/evidence/T-5303/approvals-header@1024-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1024,166
Evidence: image: .context/reviews/evidence/T-5303/approvals-header@1440-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1440,104
Location: .context/reviews/evidence/T-5303/approvals-header@1440-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1440,104
Evidence: image: .context/reviews/evidence/T-5303/approvals-header@1920-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1920,104
Location: .context/reviews/evidence/T-5303/approvals-header@1920-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1920,104
Evidence: image: .context/reviews/evidence/T-5303/approvals-footer@1024-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1024,97
Location: .context/reviews/evidence/T-5303/approvals-footer@1024-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1024,97
Evidence: image: .context/reviews/evidence/T-5303/approvals-footer@1440-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1440,97
Location: .context/reviews/evidence/T-5303/approvals-footer@1440-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1440,97
Evidence: image: .context/reviews/evidence/T-5303/approvals-footer@1920-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1920,97
Location: .context/reviews/evidence/T-5303/approvals-footer@1920-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1920,97
Evidence: image: .context/reviews/evidence/T-5303/01-root-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1280,135
Location: .context/reviews/evidence/T-5303/01-root-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1280,135
Evidence: image: .context/reviews/evidence/T-5303/02-approvals-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1280,135
Location: .context/reviews/evidence/T-5303/02-approvals-judge-t-5303-r5-claude-code-937e488ccdf2.png region 0,0,1280,135
Evidence: "app.jinja_env.globals[\"fw_cmd\"] = lambda args=\"\": _fw_user_command(args, str(PROJECT_ROOT))"
Location: web/app.py:252
Rule: criterion: "every framework menu element (logo, Work, Knowledge, Architecture, Govern, Docs, search, settings, theme toggle) and the footer text are present, with no clipping or overlap. At 1024 px the theme toggle on a second header row is the existing layout (T-5261, state menu-no-extension), not a change."
Conclusion: All six header shots show logo, Work, Knowledge, Architecture, Govern, Docs, search, settings and theme toggle unclipped and not overlapping (the toggle on a second row only at 1024 px, identical to the T-5261 menu-no-extension@1024 baseline), all three footer shots show both footer lines whole and centred, and the two 1280 px page captures show the same header with normal page bodies, so the pages render as before.

## Counter-search
Searched: every header shot for a missing, cut-off or overlapping control; every footer shot for text cut at the crop edges or wrapped over itself; the top of .context/visual/T-5261/menu-no-extension@1024.png (the named baseline) for a difference from the 1024 px header here; web/templates for a use of the new fw_cmd global that could change visible output; capture-notes.json for console or page errors
Found: nothing missing, clipped or overlapping at any width; the T-5261 baseline at 1024 px has the same two-row header with the theme toggle alone on row two at the same position; the footer in web/templates/base.html:732 still prints the literal "fw upstream report --title \"...\" --attach-doctor" and does not call fw_cmd, which matches the footer shots; console_error_count is 0 for / and /approvals

## Change-my-mind
A shot at 1024, 1440 or 1920 px in which one of the nine header controls or a footer line is absent, cut by an edge or drawn over another element; or a 1024 px baseline from before f817eea8c in which the theme toggle sits on the first header row.
===END===

Notes
- degraded: single-vendor panel. This run cannot satisfy a multi-vendor requirement; this verdict is recorded and reported, and the criterion stays open.
- cannot reproduce: the images were judged as supplied; the app and the capture were not re-run.
- The full-page captures of / and /approvals show the top 900 px only (pages are 55,267 and 50,602 px tall); the /approvals footer was judged from the fw ux shots crops. There is no footer crop for the home page; the criterion names only the /approvals footer.
- The home page was not captured at 1024/1440/1920 below the header; the criterion's steps name the header and footer crops only.
- The footer version string reads "v1.8.16-be.60-293-g065e73dc1", i.e. the running server was at 065e73dc1, which includes the web/app.py change (f817eea8c); the reviewed revision 8830c3ad1 adds only a task-file edit on top.
