===VERDICT===
format: verdict/1
task: T-5350
reviewer: reviewer-judge-t-5350-r3-4200b4c3ef5a:reviewer
round: 1
vote: green
failed: []

## AC1 Designer 0.46.0 shows both fixes we asked for (T-1471, T-1472)
Vote: green
Evidence: image: .context/reviews/evidence/T-5350/designer-1920-judge-t-5350-r3-4200b4c3ef5a.png region 1858,10,48,28
Location: .context/reviews/evidence/T-5350/designer-1920-judge-t-5350-r3-4200b4c3ef5a.png region 1858,10,48,28
Evidence: image: .context/reviews/evidence/T-5350/app-1024-judge-t-5350-r3-4200b4c3ef5a.png region 250,104,455,612
Location: .context/reviews/evidence/T-5350/app-1024-judge-t-5350-r3-4200b4c3ef5a.png region 250,104,455,612
Evidence: image: .context/reviews/evidence/T-5350/designer-1920-judge-t-5350-r3-4200b4c3ef5a.png region 236,14,62,20
Location: .context/reviews/evidence/T-5350/designer-1920-judge-t-5350-r3-4200b4c3ef5a.png region 236,14,62,20
Rule: criterion: "Save on the first toolbar row at 1920; starter map readable at 1024" (readable = "labels not clipped or overlapping")
Conclusion: The 1920 px /designer capture (version badge v0.46.0) has one toolbar row with Save as its last button ending near x=1906 inside the 1920 px frame, and the 1024 px /designer/app capture draws the starter map at 100% with every label in view (lane titles, "Investigation requested", "Load context bundle", "Decompose problem" and their ids) whole and separate from its neighbours, so both expected clauses hold.
Guidance: Green on the criterion as written. What the operator should know: at 1024 only the first three nodes of the starter map are in view (about a quarter of the map); the rest lies to the right under the properties panel. The task records this as 832's intended behaviour (open at readable zoom, scroll or Fit for the rest). The images cannot show that scrolling reaches the rest; I did not test it.

## Counter-search
Searched: all eight captures (designer and app at 1024, 1440, 1920; the two 1280 px judge captures) for a Save button off the first row or outside the frame at 1920, and for cut or overlapping labels in the 1024 px starter map; enlarged the regions 1300,0,620,60 (designer@1920) and 250,104,455,612 (app@1024) to check edges.
Found: At 1920 nothing against: one toolbar row, Save whole with a margin to the right edge. At 1024 no label is cut or overlaps another, but only 3 of the map's roughly 12 nodes are in view and the map continues under the properties panel at x=705. At 1024, 1280 and 1440 the toolbar wraps to two rows and Save is on row 2 (the criterion asks for row 1 only at 1920). At 1440 the app capture does cut a node and its id at the panel edge ("S", "agt_5_s" at x~1070-1120), a width the criterion does not name. The designer captures at 1280 and 1440 show an "Open project map" dialog over the page, with blank thumbnails at 1440; the toolbar and Save are still visible behind it. The browser reported two 404s per page; the criterion has no console clause and I cannot tell which resources.

## Change-my-mind
A 1920 px capture where Save sits on a second toolbar row or past the right edge, or a 1024 px capture of /designer/app where a starter-map label is cut by the panel edge or drawn over another label; or evidence that at 1024 the part of the map under the properties panel cannot be reached by scrolling or Fit.
===END===

Notes
- cannot reproduce: judged the supplied images only, as the brief instructs; did not open the app.
- Not part of this criterion, for the producer: /designer captured with the "Open project map" dialog open at 1280 and 1440 but not at 1024 and 1920, so the designer state is not the same across widths; at 1440 the dialog's thumbnails are blank.
