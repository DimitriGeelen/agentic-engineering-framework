---
id: T-1741
name: "Evaluate alternative ollama models for prompt-triage (qwen3 / gemma4) — gated on T-1740 outcome (Spike D)"
description: >
  If T-1740 prompt-template revision fails to reach >=80% accuracy on the T-1736 50-prompt benchmark, evaluate whether switching the underlying ollama model rescues the classifier. Models to test: claude-3-5-sonnet-qwen3, claude-3-5-sonnet-qwen35, claude-3-5-sonnet-gemma4 (all already exposed via litellm:4000). Same harness (.context/spikes/T-1736-runharness.py with --model flag), same benchmark, same metrics. Decision: keep best model + revised template, or escalate to NO-GO on whole prompt-triage workflow.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [spike, follow-up]
components: [bin/fw]
related_tasks: [T-1736, T-1740, T-1737]
arc_id: orchestrator-rethink
created: 2026-05-05T08:13:04Z
last_update: 2026-05-05T09:26:28Z
date_finished: 2026-05-05T09:26:28Z
---

# T-1741: Evaluate alternative ollama models for prompt-triage (qwen3 / gemma4) — gated on T-1740 outcome (Spike D)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Run T-1736 harness against the **revised** prompt template (T-1740 baseline) with `--model claude-3-5-sonnet-qwen3` on the same 50-prompt benchmark, output to `.context/spikes/T-1741-qwen3-results.jsonl`
- [x] Same with `--model claude-3-5-sonnet-qwen35` → `.context/spikes/T-1741-qwen35-results.jsonl`
- [x] Same with `--model claude-3-5-sonnet-gemma4` → `.context/spikes/T-1741-gemma4-results.jsonl`
- [x] Comparison report `docs/reports/T-1741-spike-d.md` with confusion matrix + per-class P/R/F1 + accuracy + GO recall + DEFER discrimination + confidence calibration gap for all four models (hermes3 from T-1740, plus three alternatives) side-by-side
- [x] Task `## Recommendation` block names whether T-1737 (Slice 2 hook) is unblocked, citing the best-performing model + delta vs T-1740 baseline; success threshold unchanged: accuracy ≥ 80% AND GO recall ≥ 0.85 AND DEFER F1 ≥ 0.5

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
# Path-agnostic — task may be in active/ or completed/ at re-run time
{ cat .tasks/active/T-1741-evaluate-alternative-ollama-models-for-p.md .tasks/completed/T-1741-evaluate-alternative-ollama-models-for-p.md 2>/dev/null || true; } | grep -q "## Recommendation"

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

### 2026-05-05 — qwen3 is a reasoning model — harness assumed simple chat-completion
- **What changed:** First qwen3 dispatch produced empty `content` and PARSE_FAIL across all prompts. Direct curl revealed qwen3 puts its output into `reasoning_content` (separate field), and `content` ends up empty when `max_tokens=256` runs out during the model's internal reasoning. Same harness worked perfectly on hermes3:8b (T-1733, T-1736, T-1740 all returned populated `content`).
- **Plan impact:** `scripts/spikes/T-1736-runharness.py` patched: `max_tokens` raised 256 → 2048 (default) with `--max-tokens` CLI flag, and `call_litellm` now falls back to `reasoning_content` when `content` is empty. Default request timeout raised 60s → 120s for slower models. The patch is back-compatible — hermes3 still works identically because it always populates `content`.
- **Triggered:** No new task. The fix is local to the harness. Note for future Spike-class work: model-family assumptions matter — reasoning models, multimodal models, and tool-using models all have non-trivial response shape variations even behind a chat-completion-shaped litellm proxy.

### 2026-05-05 — 4-model bench complete: NO model clears thresholds
- **What changed:** Spike D headline (50-prompt benchmark, T-1740 revised template):
  - hermes3:    accuracy 70.00%, GO recall 0.970, DEFER F1 0.000  — fails acc + DEFER
  - qwen3:      accuracy 66.00%, GO recall 0.667, DEFER F1 0.471  — **below always-GO baseline (66%)**, fails all three
  - qwen35:     accuracy **76.74%**, GO recall 0.867, DEFER F1 0.286 — best by accuracy but 7 parse-fails (qwen35 is also a reasoning model, may need higher max_tokens)
  - gemma4:     accuracy 68.00%, GO recall 0.727, DEFER F1 0.500   — only model that clears DEFER, fails acc + GO recall
  No single model passes all three thresholds (acc ≥ 80% AND GO recall ≥ 0.85 AND DEFER F1 ≥ 0.5). qwen35 is closest: needs +3.3pp accuracy and +0.21 DEFER F1. The 7 qwen35 parse-fails (14% of bench) suggest harness max_tokens=2048 is still inadequate — qwen35 reasoning may exceed budget. Calibration: all reasoning models show conf_gap > 0 (qwen3 +0.091 best); hermes3 negative (-0.002, confabulating).
- **Plan impact:** T-1737 (Slice 2 hook) **stays BLOCKED**. Spike D was the gating decision point — the rollout decision arc that T-1733 opened, T-1736 measured, and T-1740 revised does not close GO. Three off-ramps surface (filed as captured tasks for human triage, not auto-promoted):
  1. Re-run qwen35 with `--max-tokens 4096` to recover the 7 parse-fails (~2-hour spike, single model)
  2. Reframe as binary GO / non-GO (drop DEFER class — it's the consistently weakest signal across all 4 models; conflate with NO-GO and re-score)
  3. Drop prompt-triage as the orchestrator's first production consumer — pick a different G-064 candidate from the T-1688 survey (escalation-scan v0.5 / T-1727 is already named)
- **Triggered:** New captured tasks: T-1742 (qwen35 max_tokens spike), T-1743 (binary reframe re-score), T-1744 (G-064 candidate re-pick). Recommendation in this task names option (3) as preferred — qwen35 marginal-improvement spike is rationally bounded, but the architecture question (does prompt-triage classification belong on a 7-8B local model at all?) is the systemic concern, not a max_tokens tweak. §ACD: don't paper over the ceiling, recognise it.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** **NO-GO** on T-1737 (Slice 2 hook unblock). Drop prompt-triage as the orchestrator's first production consumer.

**Rationale:** Spike D measured 4 ollama-local models on the same 50-prompt benchmark with the T-1740 revised template. **No model clears the thresholds (accuracy ≥ 80% AND GO recall ≥ 0.85 AND DEFER F1 ≥ 0.5).** Best result is qwen35 at 76.74% accuracy / 0.867 GO recall / 0.286 DEFER F1 — short on accuracy by 3.3pp and short on DEFER F1 by 0.21. Spike B/C/D consumed 4 spikes across 2 sessions and never closed the gap; the systemic signal is that **3-class prompt classification on a 7-8B local model is too noisy for production gating** — not that we picked the wrong model or the wrong template. qwen3 underperformed the always-GO baseline (66% bench prevalence), proving a reasoning model is no rescue. DEFER F1 is the consistently weakest class across all 4 models — there is no positive bias toward any architecture solving it. Calibration improved (positive conf-gap for all 3 reasoning models) but matters only if we ship; we don't.

**Evidence:**
- Headline table: `docs/reports/T-1741-spike-d.md` lines 8-19 (4-model side-by-side)
- Per-model confusion matrices: same file, lines 21-99 (rows 23, 43, 63, 83 give accuracy)
- 50/50 inference completed for all 3 alternatives: `.context/spikes/T-1741-{qwen3,qwen35,gemma4}-results.jsonl` (each 50 lines)
- Always-GO baseline (66%) computed from `.context/spikes/T-1736-labels.yaml` (33 GO / 12 NO-GO / 5 DEFER)
- Bench seed: `.context/spikes/T-1736-sampled.jsonl` (50 stratified prompts harvested across consumer projects, T-1736)
- Harness: `scripts/spikes/T-1736-runharness.py` (T-1740/T-1741 patched: max_tokens 256→2048, reasoning_content fallback, timeout 60s→120s)

**Off-ramps (captured but not chosen):** Three follow-ups filed as `captured/later` for human triage, not auto-promoted:
1. **T-1742** — qwen35 with `--max-tokens 4096` to recover 7 parse-fails (~2h spike). Optimistic ceiling +14pp accuracy IF every recovered fail is correct, more realistically +4-8pp. Even at +8pp qwen35 lands at ~85% acc but DEFER F1 still well below 0.5. Marginal — doesn't fix the architectural concern.
2. **T-1743** — binary reframe (GO / non-GO, drop DEFER). DEFER is 5/50 of the bench; merging into NO-GO eliminates the weakest signal. Re-scoring the existing 4 result files takes ~5 min. If binary acc clears 90%+ across multiple models, T-1737 unblocks with a binary classifier. **Cheapest off-ramp.**
3. **T-1744** — pick a different G-064 first-consumer candidate from T-1688 survey (escalation-scan v0.5 / T-1727 already named as preferred). Sidesteps prompt-triage entirely, lets orchestrator route_cache learn on a workload that doesn't need 80%+ classification accuracy.

**Preferred next step:** Run T-1743 first (5-min re-score, no new inference) — if binary numbers don't pass 90%, the architectural concern is confirmed and the human picks between T-1742 (one more spike) or T-1744 (different consumer).

**T-1737 status:** stays BLOCKED. Hook integration is not safe to wire — 76.74% accuracy means roughly 1 in 4 user prompts gets misclassified, and the asymmetric cost (false-NO-GO blocks legitimate work, false-GO under-gates risky work) makes both error modes user-visible.

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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ffb9e4eb
- **Timestamp:** 2026-06-02T14:59:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 21
     - evidence: `{ cat .tasks/active/T-1741-evaluate-alternative-ollama-models-for-p.md .tasks/completed/T-1741-evaluate-alternative-ollama-models-for-p.md 2>/dev/null || true; } | grep -q "## Recommendation"`
### 2026-05-05T09:26:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
