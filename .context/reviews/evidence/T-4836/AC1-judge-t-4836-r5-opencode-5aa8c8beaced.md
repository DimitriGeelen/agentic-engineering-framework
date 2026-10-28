# Reviewer evidence — T-4836 AC#1

- dispatch: `judge-t-4836-r5-opencode-5aa8c8beaced`
- worker kind: `opencode` (vendor `zai`, model `zai-coding-plan/glm-5.3`)
- seat: `opencode`
- reviewed revision: `583240a099216297580084d6f9b3fd44e2d9c722`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `ce95a06c50b7a6791a5aa107c418e8aafcc2a692b4a72689e6eef74b891517ea`
- result.md sha256: `b5ffa1032da031f6bd5496f7e028acc65e0886634ebd9b1945750cbd9e0151e2`

## The worker's verdict block

```
1. [AC] The designer's Check button still reports 832's findings after this change
VERDICT: green
WHY: I executed the AC's exact flow against the live URL in the steps, from this sandbox. (1) GET http://192.168.10.107:3000/designer/app returns 200 and serves the pinned 0.31.0 build byte-identical to this revision's vendored copy — sha256 045726676578…3244e matches both policy/designer-pin.yaml and vendor/designer/aef-workflow-designer-0.31.0.html. (2) The served bundle's Check handler is exactly fetch('/api/validate', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({bpmn})}) (extracted from the served bundle), so I replicated that request: fetched the live aef-task-lifecycle v4 map via /api/version and POSTed its BPMN — got HTTP 200 {"ok":true,"errors":0,"warnings":4,"findings":[…]} with real 832 rule findings (W-XML-GW-AMBIGUOUS on agt_gw_ready/agt_gw_issues/agt_gw_gates); same for aef-dispatch-loop v3 (200, 1 finding). No response contained "validator unavailable". (3) Corroborated the revision's own code in a scratch copy (tree untouched): tests/web/test_t4830_validate.py + tests/web/test_t4836_consumer_validator.py → 21 passed, including the synthetic-consumer test (vendor+install → 200 with findings; sha mismatch → 503) and the no-__pycache__ guarantee (verified: none created under vendor/designer). The pinned validator file vendor/designer/validate-workflow-0.31.0.py is present and its sha256 779379480a68…751 matches the pin's validator_sha256, and _load_validator (web/blueprints/designer_api.py:345-385) resolves PROJECT_ROOT then FRAMEWORK_ROOT with sha refusal — the code path the live 200 exercised.
GUIDANCE: none needed.

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```

## The worker's full output (result.md)

```
I'm reviewing T-4836 (pinned validator delivery + `_load_validator` changes). Criterion 1 is that the designer's Check button still returns findings (no "validator unavailable"). Let me inspect the changed code and then try to exercise it.
The pin declares `validator_path: vendor/designer/validate-workflow-0.31.0.py` and the file exists in the tree. Now let me check (a) whether the live designer URL is reachable from this sandbox, (b) the sha matches, and (c) what the Check button actually calls in the pinned bundle.
The live URL is reachable from this sandbox. Now I'll replicate exactly what the Check button does: the pinned bundle posts the current BPMN to `POST /api/validate`. First verify the live app serves this revision's pinned build, then POST a real map.
Live app serves the exact pinned 0.31.0 build (sha `04572667…` matches both pin and this revision's vendored copy). Now the exact Check-button flow: fetch a map's BPMN and POST it to `/api/validate`.
The bundle's Check posts `{bpmn}` as JSON to `/api/validate`. Replicating that exact request on the live server with the live map:
Live Check flow verified end-to-end. For corroboration that this revision's code itself produces that behavior, I'll run the repo's own validate tests in a scratch copy (not the fingerprinted tree):
All checks complete. Here is my verdict:

1. [AC] The designer's Check button still reports 832's findings after this change
VERDICT: green
WHY: I executed the AC's exact flow against the live URL in the steps, from this sandbox. (1) `GET http://192.168.10.107:3000/designer/app` returns 200 and serves the pinned 0.31.0 build byte-identical to this revision's vendored copy — sha256 `045726676578…3244e` matches both `policy/designer-pin.yaml` and `vendor/designer/aef-workflow-designer-0.31.0.html`. (2) The served bundle's Check handler is exactly `fetch('/api/validate', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({bpmn})})` (extracted from the served bundle), so I replicated that request: fetched the live `aef-task-lifecycle` v4 map via `/api/version` and POSTed its BPMN — got HTTP 200 `{"ok":true,"errors":0,"warnings":4,"findings":[…]}` with real 832 rule findings (W-XML-GW-AMBIGUOUS on agt_gw_ready/agt_gw_issues/agt_gw_gates); same for `aef-dispatch-loop` v3 (200, 1 finding). No response contained "validator unavailable". (3) Corroborated the revision's own code in a scratch copy (tree untouched): `tests/web/test_t4830_validate.py` + `tests/web/test_t4836_consumer_validator.py` → 21 passed, including the synthetic-consumer test (vendor+install → 200 with findings; sha mismatch → 503) and the no-`__pycache__` guarantee (verified: none created under vendor/designer). The pinned validator file `vendor/designer/validate-workflow-0.31.0.py` is present and its sha256 `779379480a68…751` matches the pin's `validator_sha256`, and `_load_validator` (web/blueprints/designer_api.py:345-385) resolves PROJECT_ROOT then FRAMEWORK_ROOT with sha refusal — the code path the live 200 exercised.
GUIDANCE: none needed.

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```
