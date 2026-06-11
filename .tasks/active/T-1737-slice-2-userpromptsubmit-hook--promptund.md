---
id: T-1737
name: "Slice 2: UserPromptSubmit hook + $PROMPT_UNDER_TRIAGE substitution (T-1733
  sibling)"
description: >
  T-1733 Slice 1 proved substrate but resolver does not substitute $PROMPT_UNDER_TRIAGE
  — Slice 2 wires the UserPromptSubmit hook to dispatch with the actual prompt and
  surface verdict via additionalContext on GO. Substrate (Spike A) and accuracy (Spike
  B) are prerequisites.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [spike, blocked]
components: []
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-05T07:36:46Z
last_update: '2026-06-11T16:00:02Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 1
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); D4=2
      (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 1
      F2: 0
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); D4=2
      (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1); F2=0 (no-signal)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 3
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=3 
      (body:typed-io-or-gate)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 3
      F1: 1
      F2: 0
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); D4=2
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=3 (body:typed-io-or-gate);
      F1=1 (body/tag hits for 'F1': 1); F2=0 (no-signal)"
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1737: Slice 2: UserPromptSubmit hook + $PROMPT_UNDER_TRIAGE substitution (T-1733 sibling)

## Context

**BLOCKED — full Spike-arc traversed, classifier under threshold across 4 models + binary reframe** (2026-05-05):

| Spike | What | Best result | Verdict |
|-------|------|-------------|---------|
| B (T-1736) | hermes3:8b, original template | 40% acc / GO recall 0.40 | NO-GO |
| C (T-1740) | hermes3:8b, calibrated template | 70% acc / GO recall 0.97 | NO-GO (DEFER F1=0) |
| D (T-1741) | qwen3 / qwen35 / gemma4, calibrated template | qwen35 76.74% / DEFER F1 0.286 | NO-GO |
| D′ (T-1743) | binary reframe (DEFER → NON_GO) on D results | qwen35 79.07% / GO P 0.839 | NO-GO |

Threshold (3-class): accuracy ≥ 80% AND GO recall ≥ 0.85 AND DEFER F1 ≥ 0.5.
Threshold (binary): accuracy ≥ 90% AND GO recall ≥ 0.85 AND GO precision ≥ 0.85.
**No model under any prompt template clears either bar.** Architectural ceiling captured as **L-355**: 7-8B local ollama models can't reliably gate user prompts at production quality. T-1742 (qwen35 max_tokens=4096) remains captured as a marginal experiment but is unlikely to lift the ceiling enough — see L-355.

**Off-ramp:** T-1744 (different G-064 first-consumer; escalation-scan v0.5 / T-1727 named as preferred) sidesteps prompt-triage entirely. This task stays parked until either (a) human picks T-1744 → T-1737 stays parked indefinitely, (b) human picks a heavier classifier (e.g. cloud LLM) → T-1737 reopens with a different worker_kind, or (c) human picks T-1742 + the re-run clears the bar.

When unblocked: the resolver `--var KEY=VALUE` plumbing landed in T-1738; this task only needs the hook integration + envelope substitution, not new resolver work.

## Acceptance Criteria

### Agent
<!-- These ACs apply WHEN UNBLOCKED. As of 2026-05-05 the prompt-triage classifier
     does not meet quality threshold (see Context). Filling ACs to satisfy G-020;
     do not start building until off-ramp decision is made on T-1744. -->
- [ ] UserPromptSubmit hook installed (`.claude/settings.json` / `hooks.d/`) that calls `bin/fw resolver dispatch <task_id> prompt-triage --var PROMPT_UNDER_TRIAGE="$PROMPT"` and emits `additionalContext` envelope on GO verdict
- [ ] Hook respects timeout budget (≤ 5s wall clock; degrade gracefully to no-op if exceeded — never block the user prompt)
- [ ] Resolver workflow `prompts/prompt-triage.md` substitutes `$PROMPT_UNDER_TRIAGE` correctly when invoked through the hook (no shell-quoting issues with multi-line prompts, no escape leaks)
- [ ] Verdict surfaced as a one-line `additionalContext` block prefixed `<prompt-triage>` containing `verdict|confidence|rationale_summary` (truncated to ≤ 200 chars)
- [ ] On NO-GO or DEFER: hook does NOT block the prompt — only emits the verdict for the agent to read; structural blocking is human-policy territory, not classifier territory
- [ ] Smoke test: paste a known-GO prompt + a known-NO-GO prompt, verify `additionalContext` shows correct verdict in both cases
- [ ] Documentation: `docs/orchestrator/prompt-triage-hook.md` describes invocation contract + escape hatch (`FW_DISABLE_PROMPT_TRIAGE=1` env var)

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

### 2026-05-05T07:36:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1737-slice-2-userpromptsubmit-hook--promptund.md
- **Context:** Initial task creation

### 2026-05-05T09:30:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-05-05T09:31:41Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Change:** tags: +spike

### 2026-05-05T09:31:41Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-05T09:31:42Z — status-update [task-update-agent]
- **Change:** tags: +blocked
