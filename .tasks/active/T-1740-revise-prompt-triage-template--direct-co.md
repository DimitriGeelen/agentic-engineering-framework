---
id: T-1740
name: "Revise prompt-triage template — direct-command-GO calibration examples (T-1736 follow-up Spike C)"
description: >
  T-1736 Spike B measured prompt-triage at 40% accuracy (vs 66% always-GO baseline). Failure mode: classifier under-predicts GO on direct commands ('Run X', 'Commit Y', 'T-198 check verdict'), interpreting 'create or focus a task' literally. Revise prompts/prompt-triage.md to add 6-10 calibration examples covering direct-command-GO patterns + agent-dispatch worker prompts. Re-run Spike B harness against same 50-prompt benchmark in .context/spikes/T-1736-sampled.jsonl. Success threshold: accuracy >= 80% AND GO recall >= 0.85. If pass, T-1737 (Slice 2 hook) is unblocked. If fail, T-1741 model-switch is the next move.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [spike, arc:orchestrator-rethink, follow-up]
components: []
related_tasks: [T-1736, T-1733, T-1737]
created: 2026-05-05T08:12:52Z
last_update: 2026-05-05T08:14:31Z
date_finished: null
---

# T-1740: Revise prompt-triage template — direct-command-GO calibration examples (T-1736 follow-up Spike C)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [ ] `prompts/prompt-triage.md` gains ≥6 new calibration examples covering direct-command-GO patterns ("Run: ...", "Commit: ...", "T-XXX: <verb>", "fw <verb> ...", agent-dispatch worker prompts starting with "You are working in ...")
- [ ] Re-run T-1736 harness (`scripts/spikes/T-1736-runharness.py`) against the **same** 50-prompt benchmark (`.context/spikes/T-1736-sampled.jsonl`), output written to `.context/spikes/T-1740-results.jsonl`
- [ ] Metrics report `docs/reports/T-1740-spike-c.md` rendered with confusion matrix + per-class precision/recall/F1 + side-by-side delta vs T-1736 baseline (40% accuracy)
- [ ] Task `## Recommendation` block names whether T-1737 (Slice 2 hook) is unblocked, citing the new accuracy + GO recall — success threshold: accuracy ≥ 80% AND GO recall ≥ 0.85; partial pass (one met) is DEFER; failure is NO-GO and triggers T-1741

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

test "$(grep -c '^- ' prompts/prompt-triage.md)" -ge 13
test -f .context/spikes/T-1740-results.jsonl
test "$(wc -l < .context/spikes/T-1740-results.jsonl)" -ge 50
test -f docs/reports/T-1740-spike-c.md
grep -q -i "confusion" docs/reports/T-1740-spike-c.md
grep -q -i "delta" docs/reports/T-1740-spike-c.md
grep -q "## Recommendation" .tasks/active/T-1740-revise-prompt-triage-template--direct-co.md

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

### 2026-05-05T08:12:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1740-revise-prompt-triage-template--direct-co.md
- **Context:** Initial task creation

### 2026-05-05T08:14:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
