---
id: T-1740
name: "Revise prompt-triage template — direct-command-GO calibration examples (T-1736 follow-up Spike C)"
description: >
  T-1736 Spike B measured prompt-triage at 40% accuracy (vs 66% always-GO baseline). Failure mode: classifier under-predicts GO on direct commands ('Run X', 'Commit Y', 'T-198 check verdict'), interpreting 'create or focus a task' literally. Revise prompts/prompt-triage.md to add 6-10 calibration examples covering direct-command-GO patterns + agent-dispatch worker prompts. Re-run Spike B harness against same 50-prompt benchmark in .context/spikes/T-1736-sampled.jsonl. Success threshold: accuracy >= 80% AND GO recall >= 0.85. If pass, T-1737 (Slice 2 hook) is unblocked. If fail, T-1741 model-switch is the next move.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [spike, follow-up]
components: []
related_tasks: [T-1736, T-1733, T-1737]
arc_id: orchestrator-rethink
created: 2026-05-05T08:12:52Z
last_update: 2026-05-05T08:21:37Z
date_finished: 2026-05-05T08:21:37Z
---

# T-1740: Revise prompt-triage template — direct-command-GO calibration examples (T-1736 follow-up Spike C)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `prompts/prompt-triage.md` gains ≥6 new calibration examples covering direct-command-GO patterns ("Run: ...", "Commit: ...", "T-XXX: <verb>", "fw <verb> ...", agent-dispatch worker prompts starting with "You are working in ...") — 7→28 examples
- [x] Re-run T-1736 harness (`scripts/spikes/T-1736-runharness.py`) against the **same** 50-prompt benchmark (`.context/spikes/T-1736-sampled.jsonl`), output written to `.context/spikes/T-1740-results.jsonl`
- [x] Metrics report `docs/reports/T-1740-spike-c.md` rendered with confusion matrix + per-class precision/recall/F1 + side-by-side delta vs T-1736 baseline (40% accuracy)
- [x] Task `## Recommendation` block names whether T-1737 (Slice 2 hook) is unblocked, citing the new accuracy + GO recall — success threshold: accuracy ≥ 80% AND GO recall ≥ 0.85; partial pass (one met) is DEFER; failure is NO-GO and triggers T-1741

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
# Path-agnostic — task may be in active/ or completed/ at re-run time
{ cat .tasks/active/T-1740-revise-prompt-triage-template--direct-co.md .tasks/completed/T-1740-revise-prompt-triage-template--direct-co.md 2>/dev/null || true; } | grep -q "## Recommendation"

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

### 2026-05-05 — accuracy improved but the win is partly artifact (hallucinated rationales)
- **What changed:** Accuracy 40% → 70% (+30pp), GO recall 0.39 → 0.97 (+0.58 absolute). Direction reversed — classifier no longer under-predicts GO. **But:** disagreement rationales reveal the model is hallucinating prompt content, e.g. on "does this has power consultion imnpact?" (a question, ground-truth NO-GO) the rationale says *"The prompt asks the agent to fix a specific bug, which requires creating or focusing a task first and mutating code state."* The model has confused calibration examples in the template with the prompt-under-triage. Confidence calibration regressed: gap correct−wrong was +0.035 in T-1736, now −0.002. Higher accuracy + worse calibration = the model is guessing more confidently in one direction and the class-distribution prior (66% GO) is doing the work, not reasoning.
- **Plan impact:** The improvement is partly real (the GO definition reframing helped on TRUE-GO direct commands like "Run: bin/fw upgrade ...", "Commit ..." — confusion matrix shows 32/33 true-GO now correctly classified vs 13/33 baseline). But the model collapsed the DEFER class to 0/0 and lost discrimination for analytic NO-GO questions. T-1741 (alternative model) is now **necessary, not optional** — the failure mode shifted from "doesn't understand verb diversity" to "hallucinates from template examples". Further prompt revision is unlikely to help; this is a model capacity / hallucination issue.
- **Triggered:** T-1741 promoted from horizon=later to horizon=next. L-354 captured (calibration-regression-with-accuracy-gain pattern).

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

- **Recommendation:** **DEFER on unblocking T-1737**. The accuracy threshold (≥80%) was not met (70% achieved). The GO recall threshold (≥0.85) was met (0.97 achieved). However, the headline accuracy gain is partly artifact — disagreement rationales show the model is hallucinating prompt content rather than reasoning about it.
- **Rationale:**
  - **Direction reversed (good):** Spike B's anti-safety GO under-prediction is gone. 32/33 true-GO correctly classified (vs 13/33 baseline). The verb-diversity reframing in the GO definition + ≥10 direct-command-GO examples did the work — confirms the calibration hypothesis behind T-1740.
  - **But the model is unreliable (bad):** On NO-GO analytic questions ("does this has power consultion imnpact?"), the model's rationale references calibration examples from the template ("fix the bug ...", "directly asks the agent to take state-mutating actions") AS IF they appear in the prompt. This is hallucination/confabulation. Confidence calibration regressed (gap +0.035 → -0.002) — the model is now equally confident when right and wrong.
  - **DEFER class collapsed:** 0 predictions of DEFER across 50 prompts; precision/recall both 0.0. The model has lost the third class entirely — likely a side effect of the prompt restructuring.
  - **Remaining 30% errors concentrated in NO-GO → GO over-prediction:** 9/12 NO-GO prompts misclassified as GO. The classifier no longer distinguishes "command that mutates state" from "question about something that could mutate state".
- **Evidence:** `docs/reports/T-1740-spike-c.md` (full side-by-side delta with T-1736 baseline). 10 disagreement rationales documented show hallucination. Raw data in `.context/spikes/T-1740-results.jsonl`. Inference: 50/50 dispatches succeeded, 0 errors, p50 1432ms (slight slowdown from 1171ms — extra template tokens).
- **Action:**
  - **T-1741 promoted** to horizon=next. The hermes3:8b model has reached its calibration ceiling on this task; switching to a larger/instruction-tuned model (qwen3, qwen35, gemma4) is the next move. **Prompt template stays as-is** for the T-1741 baseline — we are testing model swap with the now-correct template.
  - **T-1737 (Slice 2) remains blocked.** Do not ship UserPromptSubmit hook integration until accuracy ≥80% AND DEFER class regains ≥0.5 F1 on the same benchmark.
- **What this is NOT:** This is not a regression. T-1740's calibration-example reframing remains the right baseline going forward — it correctly inverts a wrong bias. T-1741 will run against the revised template. T-1740's contribution is the verb-diversity reframing AND the discovery of the hallucination ceiling at hermes3:8b.

## Updates

### 2026-05-05T08:12:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1740-revise-prompt-triage-template--direct-co.md
- **Context:** Initial task creation

### 2026-05-05T08:14:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-2df209ba
- **Timestamp:** 2026-05-05T08:21:38Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — Re-run T-1736 harness (`scripts/spikes/T-1736-runharness.py`) against the **same** 50-prompt benchmark (`.context/spikes/T-1736-sampled.jsonl`), output written to `.context/spikes/T-1740-results.jsonl
  - **AC-verify-mismatch** (narrow, heuristic) — `path=scripts/spikes/T-1736-runharness.py in: Re-run T-1736 harness (`scripts/spikes/T-1736-runharness.py`) against the **same** 50-prompt benchmark (`.context/spikes/T-1736-sampled.jsonl`), outpu`

### 2026-05-05T08:21:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
