# T-4836 Human AC#1 — Check button still reports 832's findings
Reviewer: reviewer-judge-t-4836-r5-claude-code-acfc86c53f8a (claude-code, rung-5-panel), revision 583240a099216297580084d6f9b3fd44e2d9c722

## Server under test
- :3000 is `python3 -m web.app --port 3000` (pid 57166), cwd /opt/999-Agentic-Engineering-Framework, started 2026-10-28 10:14:09,
  after T-4836's commit dee563551. `git diff 583240a09 -- web/blueprints/designer_api.py` is empty, so the
  process serves the reviewed loader.

## Steps (headless Chromium via Playwright, real UI)
1. Opened http://192.168.10.107:3000/designer/app. HTTP 200, title "AEF Workflow Designer — investigate.bpmn".
2. With the "investigate" map loaded, clicked #btn-check (the "✓ Check" button).
3. Network: POST /api/validate → **200**, body `{"errors":0,"findings":[],"ok":true,"warnings":0}`.
4. The findings panel (.findings-state) shows data-state=`clean`, text "checked · no findings". The footer bar reads
   "Validator checked · no findings". No "could not check"/"unavailable" text. Screenshot: check-judge-t-4836-r5-claude-code-acfc86c53f8a.png

## Supplementary: the validator really produces findings
POSTed a deliberately flawed BPMN (no lanes, no end event) to the same /api/validate endpoint on :3000 → 200 with
3 errors and 2 warnings (E-XML-LANES-EMPTY, E-XML-NODE-UNASSIGNED x2, W-XML-NO-WORKFLOWMETA, W-XML-NO-END-EVENT),
so the 832 validator itself is loaded and running, not an empty stub.

## Pin integrity
- policy/designer-pin.yaml validator_path vendor/designer/validate-workflow-0.31.0.py, validator_sha256 7793794…0751
- sha256sum of that file = 779379480a68fc2ea2bfb42abb8c1308b8a87492ee9c0de3538d0a2fae650751 (match)
- `find vendor -name __pycache__` returns nothing after the load (consistent with the no-bytecode AC).

## Limits
Tested in the framework repo's own server (the URL the AC names), not in a consumer project. The AC asks only
about this URL.

Verdict: green.
