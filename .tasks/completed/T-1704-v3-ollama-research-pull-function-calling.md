---
id: T-1704
name: "v3 ollama-research: pull function-calling-tuned model (hermes-3:8b OR xlam:7b)
  and re-probe"
description: >
  T-1703 disproved that catalogue restriction rescues tool-use on generalist 8-10B
  models (0/18 across gemma4:8b, qwen3.5:9.7B). Failure mode is structural — models
  emit prose/code instead of tool_use JSON. v3: pull a function-calling-tuned model
  (hermes-3:8b or xlam:7b, both ≤5GB), add litellm alias, re-run tools/t1703-probe-matrix.sh
  with the new alias substituted in CELLS array. If ≥90% on simple-read: update ollama-research.yaml
  + T-1700 Recommendation. If not: file v4 inception (claude-code-router OR accept
  text-only narrow workflow). Predecessors: T-1700 (substrate), T-1703 (catalogue
  probe + L-347).

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [tools/t1704-hermes3-probe.sh]
related_tasks: []
created: 2026-05-03T19:58:50Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-03T20:35:08Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 3
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=3 
      (body:typed-io-or-gate); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1704: v3 ollama-research: pull function-calling-tuned model (hermes-3:8b OR xlam:7b) and re-probe

## Context

T-1703 disproved path (c) from T-1700's recommendation: catalogue restriction does
not rescue tool-use on generalist 8-10B ollama models. Failure mode is structural —
gemma4:8b emits prose/refusal, qwen3.5:9.7b emits bash inside markdown fences. Neither
produces the `tool_use` JSON content blocks claude -p / Anthropic API expects.

Hypothesis for v3: an explicitly function-calling-tuned model will emit the tool_use
format that catalogue-tuning failed to coax out of generalists. Strongest candidate
on 16GB: `hermes3:8b` (Nous Research, 4.66GB Q4) — public benchmarks show reliable
tool-call format emission. Fallback: `xlam:7b` (Salesforce, smaller, function-calling
specialized).

Predecessors: T-1700 (substrate + harness), T-1703 (catalogue probe + L-347 capture).
Reuses `tools/t1703-probe-matrix.sh` shape but with hermes3 alias.

## Acceptance Criteria

### Agent
- [x] `hermes3:8b` pulled to ollama at 192.168.10.107:11434.
      Verified: hermes3:8b 4.3GB Q4_0 visible via `/api/tags`.
- [x] `.context/litellm-config.yaml` adds `claude-3-5-sonnet-hermes3` →
      `ollama_chat/hermes3:8b` mapping; proxy reload picks it up.
      Verified: alias visible in `/v1/models` after restart.
- [x] `tools/t1704-hermes3-probe.sh` exists, mirrors T-1703 shape (3 cells × N=3 simple-read).
      Ran to completion in ~2 min wall, 9 dispatches.
- [x] Probe report `docs/reports/T-1704-hermes3-probe.md` exists, captures per-cell
      `tool_use_pct`, exit-code pass, latency, sample outputs, AND the curated-direct
      vs claude-p comparison (the headline architectural finding).
- [N/A] If best cell ≥90%: workflow updated. (Best cell 0%; this branch is N/A.)
- [N/A] If best cell <90% and >0%: capture partial-rescue. (Best cell 0%; N/A.)
- [x] If best cell = 0%: full negative captured as L-348; v4 inception **T-1705** filed.
      L-348 records the architectural insight (claude -p prompt is bottleneck, not model).

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# hermes3:8b loaded
curl -sf http://192.168.10.107:11434/api/tags | python3 -c "import json,sys; n=[m['name'] for m in json.load(sys.stdin).get('models',[])]; sys.exit(0 if 'hermes3:8b' in n else 1)"
# Litellm alias present
curl -sf -H "Authorization: Bearer sk-litellm-local-dev" http://localhost:4000/v1/models | grep -q hermes3
# Probe script parses
bash -n tools/t1704-hermes3-probe.sh
# Report exists
test -f docs/reports/T-1704-hermes3-probe.md
# Report contains conclusion (winner, partial, or negative)
grep -qE "WINNER:|Partial:|Negative:" docs/reports/T-1704-hermes3-probe.md

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Decisions

### 2026-05-03 — v3 hypothesis disproven; bottleneck is claude -p, not model

- **Chose:** declare path "function-calling-tuned model fixes ollama-research" DEAD.
  hermes3:8b through `fw termlink dispatch` (claude -p wrap): 0/9 across 3 catalogue
  sizes. SAME model via direct litellm `/v1/messages` with 1 curated tool: 3/3 perfect.
- **Why:** the comparison isolates the bottleneck above the model layer. claude -p's
  prompt construction (system prompt + ~100-tool catalogue + instruction format)
  prevents tool_use emission even when `--tools "Read"` restricts the exposed list.
  Function-calling tuning is necessary but NOT sufficient through this proxy path.
- **Rejected:** running xlam:7b — would test the same hypothesis on a different model
  through the same broken path. Won't change the answer.

### 2026-05-03 — Default v4 recommendation: thin tool-loop (skip claude -p)

- **Chose:** scope T-1705 inception with "thin tool-loop" as the default-recommendation.
- **Why:** all the substrate work (litellm proxy, --env plumbing, --tools plumbing, harness,
  alias config, fabric registration) is reusable. The only missing piece is the tool
  execution loop itself (~150 LOC). hermes3 is proven on this path with N=3 curated
  evidence. Smallest surface change to ship a working ollama-research v1.
- **Rejected (default):** claude-code-router — adds another proxy layer; doesn't address
  the prompt-construction problem at the source. Would still need to validate empirically.
- **Rejected (default):** accept text-only — kills the G-064 autonomous-consumer story
  the entire arc is about. Should be considered only if option 1 fails.

## Recommendation

**Recommendation:** SHIP — empirical answer captured, architectural finding identified,
v4 inception filed with default-recommendation.

**Rationale:**
- T-1704 directly tested the v3 hypothesis (function-calling-tuned model fixes it). 0/9.
- Curated-direct comparison (3/3) ISOLATES the bottleneck — claude -p's prompt, not model
  capability. This is a definitive architectural finding, not another negative datapoint.
- L-348 captures the insight; T-1705 carries the v4 inception with thin-loop default.
- Without this comparison, we'd be at "models keep failing, try another" — open-ended
  spend. With this comparison, the v4 path has a falsifiable hypothesis: "hermes3 +
  curated 3-tool def + iterative loop = working ollama-research."

**Evidence:**
- `docs/reports/T-1704-hermes3-probe.md` — full report with N=9 matrix + curated-direct
  comparison + v4 architectural choices
- Curated-direct N=3: `t1704-smoke-1` smoke + 3 raw `/v1/messages` calls (logged in
  proxy.log, all returned `stop_reason: tool_use`)
- Substrate diff: `claude-3-5-sonnet-hermes3` alias in litellm-config.yaml (commit pending)
- `tools/t1704-hermes3-probe.sh` — reusable for future single-model probes

**v4 follow-up scope (T-1705 inception):**
- Validate "thin tool-loop" hypothesis with a 50-line spike: hermes3 + 3-tool def
  (Read, Bash, Grep) + iterative loop on the simple-read prompt class. Target: 90%+
  on the same 3 prompts the matrix used.
- If spike GO: build production version with full wdir layout + dispatch envelope
  compatibility. T-1700/T-1703 substrate carries through.
- If spike NO-GO: try claude-code-router (option 2). If THAT fails: option 3 ships.

## Updates

### 2026-05-03T19:58:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1704-v3-ollama-research-pull-function-calling.md
- **Context:** Initial task creation

### 2026-05-03T19:59:02Z — status-update [task-update-agent]
- **Change:** tags: +v3-prep

### 2026-05-03T20:23:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-147a1e24
- **Timestamp:** 2026-06-02T14:59:13Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#2 (Agent)** — `.context/litellm-config.yaml` adds `claude-3-5-sonnet-hermes3` →
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/litellm-config.yaml in: `.context/litellm-config.yaml` adds `claude-3-5-sonnet-hermes3` →`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `curl -sf -H "Authorization: Bearer sk-litellm-local-dev" http://localhost:4000/v1/models | grep -q hermes3`
### 2026-05-03T20:35:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
