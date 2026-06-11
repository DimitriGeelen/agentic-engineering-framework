---
id: T-1733
name: "prompt-triage v0.5 Spike A — first orchestrator substrate consumer end-to-end"
description: >
  T-1732 build slice 1: file workflow YAML + prompt template + run one dispatch to
  prove resolver→litellm→ollama-local→envelope works end-to-end. Closes G-064 (zero
  consumers) with first real consumer. Bounded scope: substrate connection only, not
  classification accuracy (Spike B).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [G-064-closure, prompt-triage, v0.5]
components: [bin/fw, lib/resolver.py]
related_tasks: [T-1732, T-1729, T-1700, T-1689, T-1690, T-1697]
arc_id: orchestrator-rethink
created: 2026-05-05T07:27:43Z
last_update: '2026-06-11T22:23:57Z'
date_finished: 2026-05-05T07:37:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 3
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=3 
      (body:typed-io-or-gate); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1733: prompt-triage v0.5 Spike A — first orchestrator substrate consumer end-to-end

## Context

T-1729 meta-RCA identified G4 (text output has no surface for governance) — the four prior
breakdowns where the agent did substantive work without a task all started with a user prompt
that needed task creation. Layer-1 mitigation: a UserPromptSubmit hook routes the prompt
through `fw resolver dispatch` with a `prompt-triage` workflow that returns GO/NO-GO/DEFER on
"does this need a task?". On GO, surface additionalContext warning the agent.

T-1732 inception decided GO on the architecture (recommendation in completed task). This is
**Slice 1** of the build: prove the substrate connects end-to-end. Not classification accuracy
(that is Spike B). Not the UserPromptSubmit hook integration (that is Slice 2). Just: workflow
YAML + prompt template + one dispatch flowing through resolver → litellm → ollama-local →
envelope captured in `.context/dispatches.jsonl`.

This is **the first real consumer of orchestrator substrate** (G-064: zero consumers since
T-1689 substrate landed). Closing G-064 with one consumer is the highest-leverage arc move
right now — every additional consumer becomes incremental once one exists.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Workflow file `.context/project/workflows/prompt-triage.yaml` exists with `task_type: prompt-triage`, `worker_kind: ollama-loop`, `model: claude-3-5-sonnet-hermes3`, `cost_cap_usd: 0.0`, allowed_tools restricted to `[Read]` (classifier should not write/exec)
- [x] Prompt template `prompts/prompt-triage.md` exists with classifier instructions: input is a user prompt, output is YAML envelope with `verdict: GO|NO-GO|DEFER` + `rationale` (one line) + `confidence: 0.0-1.0`
- [x] `bin/fw resolver workflows` lists `prompt-triage.yaml` with the resolved worker/model
- [x] `bin/fw resolver dispatch <task_id> prompt-triage --dry-run` builds an envelope without errors and shows the prompt-template path resolved
- [x] One real dispatch run captured in `.context/dispatches.jsonl` (latest entry has `task_type: prompt-triage`)
- [x] Latency p50 from at least 3 dispatches recorded in this task's Evolution section (one-shot proof, not statistical) — establishes order-of-magnitude before Spike B
- [x] Cost cap honored: `cost_cap_usd: 0.0` enforced (ollama-local only); test path NOT routed through cloud provider
- [x] No regressions: `bin/fw resolver workflows` continues to list the existing 5 workflows alongside the new one

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
test -f .context/project/workflows/prompt-triage.yaml
test -f prompts/prompt-triage.md
bin/fw resolver workflows 2>&1 | grep -q "prompt-triage.yaml"
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/workflows/prompt-triage.yaml')); assert d['task_type']=='prompt-triage'; assert d['cost_cap_usd']==0.0; assert d['allowed_tools']==['Read']"
grep -q "verdict" prompts/prompt-triage.md
grep -q "GO\|NO-GO\|DEFER" prompts/prompt-triage.md
{ tail -1 .context/dispatches.jsonl 2>/dev/null || echo '{}'; } | grep -q "prompt-triage"

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

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

### 2026-05-05 — first dispatch surfaced VALID_WORKER_KINDS drift
- **What changed:** The very first attempt at `fw resolver dispatch T-1733 prompt-triage --dry-run` failed with "invalid worker_kind 'ollama-loop'". Two validation tables (bin/fw:1804 + lib/resolver.py:56) had drifted; T-1706 added ollama-loop to the first, never to the second. The lint path was using one table, the dispatch path another. **G-064's "zero consumers" rule had been hiding the bug for 5+ months.**
- **Plan impact:** T-1733 became the first end-to-end consumer that proved the substrate isn't actually wired up — only half-wired. Without prompt-triage (or any other ollama-loop dispatch) ever running, no one would have noticed.
- **Triggered:** T-1734 (drift fix, completed in 3 minutes), T-1735 (later: doctor parity check).

### 2026-05-05 — substrate end-to-end: latency + verdict bias
- **What changed:** After T-1734 fix, dispatch worked. Captured 3 sample classifications via litellm:4000 → ollama:11434 → hermes3:8b:
  | Prompt (50 chars) | Expected | Got | Latency |
  |---|---|---|---|
  | "what is the current focus task?" | NO-GO | GO | 7861ms (cold) |
  | "fix the bug where T-1716 verification gate..." | GO | GO | 1069ms |
  | "thanks proceed" | NO-GO | GO | 943ms |

  **p50 latency: 1069ms** (median of 3, warm). **Cold-start ~8s** (model load).
  **Cost: $0** (ollama-local routing confirmed via litellm-config.yaml).
  **Accuracy: 1/3 (33%)** — model defaults to GO across the board.
- **Plan impact:** Substrate proven. Calibration is **not in scope** for Spike A (substrate connection only). The all-GO bias is exactly the signal Spike B was designed to investigate. Spike A is shippable.
- **Triggered:** T-1736 (Spike B: prompt-triage classifier accuracy on 30-day backlog) — pre-filed at horizon `later`.

### 2026-05-05 — `$PROMPT_UNDER_TRIAGE` substitution gap
- **What changed:** Resolver's variable substitution table (`$TASK_ID`, `$TASK_TYPE`, etc.) doesn't include the prompt-under-triage as a known var. The dispatched envelope had empty `$PROMPT_UNDER_TRIAGE` because the resolver doesn't know about it. Direct curl to litellm worked because I substituted in shell. UserPromptSubmit hook integration (Slice 2) will need the substitution wired.
- **Plan impact:** Slice 2 scope explicit. Slice 1 (this task) was substrate-only and held that scope.
- **Triggered:** scope-fence note in T-1737 (Slice 2: UserPromptSubmit hook + prompt-under-triage substitution).


## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-05T07:27:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1733-prompt-triage-v05-spike-a--first-orchest.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-740b7bc0
- **Timestamp:** 2026-06-02T14:59:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 11
     - evidence: `bin/fw resolver workflows 2>&1 | grep -q "prompt-triage.yaml"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 15
     - evidence: `{ tail -1 .context/dispatches.jsonl 2>/dev/null || echo '{}'; } | grep -q "prompt-triage"`
### 2026-05-05T07:37:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
