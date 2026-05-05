---
id: T-1741
name: "Evaluate alternative ollama models for prompt-triage (qwen3 / gemma4) — gated on T-1740 outcome (Spike D)"
description: >
  If T-1740 prompt-template revision fails to reach >=80% accuracy on the T-1736 50-prompt benchmark, evaluate whether switching the underlying ollama model rescues the classifier. Models to test: claude-3-5-sonnet-qwen3, claude-3-5-sonnet-qwen35, claude-3-5-sonnet-gemma4 (all already exposed via litellm:4000). Same harness (.context/spikes/T-1736-runharness.py with --model flag), same benchmark, same metrics. Decision: keep best model + revised template, or escalate to NO-GO on whole prompt-triage workflow.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [spike, arc:orchestrator-rethink, follow-up]
components: []
related_tasks: [T-1736, T-1740, T-1737]
created: 2026-05-05T08:13:04Z
last_update: 2026-05-05T08:22:17Z
date_finished: null
---

# T-1741: Evaluate alternative ollama models for prompt-triage (qwen3 / gemma4) — gated on T-1740 outcome (Spike D)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [ ] Run T-1736 harness against the **revised** prompt template (T-1740 baseline) with `--model claude-3-5-sonnet-qwen3` on the same 50-prompt benchmark, output to `.context/spikes/T-1741-qwen3-results.jsonl`
- [ ] Same with `--model claude-3-5-sonnet-qwen35` → `.context/spikes/T-1741-qwen35-results.jsonl`
- [ ] Same with `--model claude-3-5-sonnet-gemma4` → `.context/spikes/T-1741-gemma4-results.jsonl`
- [ ] Comparison report `docs/reports/T-1741-spike-d.md` with confusion matrix + per-class P/R/F1 + accuracy + GO recall + DEFER discrimination + confidence calibration gap for all four models (hermes3 from T-1740, plus three alternatives) side-by-side
- [ ] Task `## Recommendation` block names whether T-1737 (Slice 2 hook) is unblocked, citing the best-performing model + delta vs T-1740 baseline; success threshold unchanged: accuracy ≥ 80% AND GO recall ≥ 0.85 AND DEFER F1 ≥ 0.5

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

test -f .context/spikes/T-1741-qwen3-results.jsonl
test "$(wc -l < .context/spikes/T-1741-qwen3-results.jsonl)" -ge 50
test -f .context/spikes/T-1741-qwen35-results.jsonl
test "$(wc -l < .context/spikes/T-1741-qwen35-results.jsonl)" -ge 50
test -f .context/spikes/T-1741-gemma4-results.jsonl
test "$(wc -l < .context/spikes/T-1741-gemma4-results.jsonl)" -ge 50
test -f docs/reports/T-1741-spike-d.md
grep -q -i "confusion" docs/reports/T-1741-spike-d.md
grep -q -i "qwen3" docs/reports/T-1741-spike-d.md
grep -q -i "gemma4" docs/reports/T-1741-spike-d.md
grep -q "## Recommendation" .tasks/active/T-1741-evaluate-alternative-ollama-models-for-p.md

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

### 2026-05-05T08:13:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1741-evaluate-alternative-ollama-models-for-p.md
- **Context:** Initial task creation

### 2026-05-05T08:21:23Z — status-update [task-update-agent]
- **Change:** horizon: later → next
- **Reason:** T-1740 finding promoted: hermes3:8b hit calibration ceiling, model swap is now necessary, not optional

### 2026-05-05T08:22:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
