---
id: T-1743
name: "Spike D off-ramp: re-score 4-model results as binary GO / non-GO (drop DEFER
  class)"
description: >
  DEFER is the consistently weakest class across all 4 models in Spike D (T-1741).
  Truth distribution is 5/50 DEFER (10%), making it under-represented. Cheapest off-ramp:
  re-score existing .context/spikes/T-1741-{qwen3,qwen35,gemma4}-results.jsonl + .context/spikes/T-1740-results.jsonl
  by collapsing DEFER labels into NO-GO and re-running T-1741-metrics.py with a binary
  CLASSES tuple. ~5 min, no new inference. If binary accuracy clears 90% on any model,
  T-1737 unblocks with a binary classifier (still meaningful: GO unblocks the prompt,
  non-GO triggers framework intervention). Filed captured/later per L-349 — preferred
  first off-ramp per T-1741 Recommendation.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [spike, follow-up]
components: []
related_tasks: [T-1741, T-1737]
arc_id: orchestrator-rethink
created: 2026-05-05T09:25:32Z
last_update: '2026-06-11T22:23:57Z'
date_finished: 2026-05-05T09:30:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1743: Spike D off-ramp: re-score 4-model results as binary GO / non-GO (drop DEFER class)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Write `scripts/spikes/T-1743-binary-rescore.py` that loads `.context/spikes/T-1736-labels.yaml` + the 4 result files (T-1740 hermes3 + T-1741 qwen3/qwen35/gemma4), collapses DEFER → NO-GO in both truth and predictions, computes binary accuracy + GO P/R/F1 + NON_GO F1 + macro F1 per model
- [x] Render `docs/reports/T-1743-binary-rescore.md` with side-by-side headline + per-model binary confusion + verdict (binary thresholds: accuracy ≥ 0.90 AND GO recall ≥ 0.85 AND GO precision ≥ 0.85)
- [x] Task `## Recommendation` block names whether T-1737 unblocks under binary formulation, citing best-model accuracy + which threshold(s) it clears or fails

## Recommendation

**Recommendation:** **NO-GO** on T-1737 unblock under binary formulation. Architectural ceiling confirmed — promote T-1744 (different G-064 first-consumer) over T-1742 (qwen35 max_tokens spike).

**Rationale:** Binary re-score (DEFER → NON_GO) on the existing 4 result files lifted accuracy modestly (qwen35: 76.74% → 79.07%) but **no model clears 90%**. Best-by-accuracy qwen35 misses both binary thresholds: accuracy 79.07% < 90%, GO precision 0.839 < 0.85 (GO recall 0.867 ✓ does pass). The 2.3pp accuracy gain from collapsing DEFER means DEFER was contributing some confusion, but the underlying noise floor is the architecture, not the class structure. Same headline observed across all 4 models (hermes3, qwen3, qwen35, gemma4) — none clears 90% even on the easier binary task. This rules out "DEFER was the problem" and confirms T-1741's architectural concern: prompt-triage classification on 7-8B local ollama models is consistently below production-gating quality.

**Evidence:**
- Headline table: `docs/reports/T-1743-binary-rescore.md` lines 14-19 (4-model binary, accuracy delta vs T-1741 3-class)
- Per-model binary confusion: same file (TP/FN/FP/TN counts)
- No new inference — pure re-score of `.context/spikes/T-1741-{qwen3,qwen35,gemma4}-results.jsonl` + `.context/spikes/T-1740-results.jsonl`
- Always-GO baseline (binary): 66% (33/50 prompts) — qwen35 +13pp over null at best
- Re-score script: `scripts/spikes/T-1743-binary-rescore.py`

**Implication for next move:**
1. **T-1742** (qwen35 max_tokens=4096) — even optimistic +14pp accuracy lands at 93%, but the 7 parse-fails would have to ALL be correct AND qwen35 would have to gain accuracy on the other 43 too. Realistic ceiling ~83-86%. Marginal — would inform but not decide.
2. **T-1744** (different G-064 first-consumer / escalation-scan v0.5 / T-1727) — sidesteps prompt-triage entirely, lets orchestrator route_cache learn on a workload that doesn't need 90%+ classification accuracy. **Preferred next step.**

**T-1737 status:** stays BLOCKED. Binary reframe doesn't rescue. The orchestrator-rethink arc's first production consumer should not be prompt-triage.

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

test -f scripts/spikes/T-1743-binary-rescore.py
test -f docs/reports/T-1743-binary-rescore.md
grep -q -i "binary" docs/reports/T-1743-binary-rescore.md
grep -q -i "always-GO" docs/reports/T-1743-binary-rescore.md
grep -q "## Recommendation" .tasks/active/T-1743-spike-d-off-ramp-re-score-4-model-result.md

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

### 2026-05-05 — DEFER wasn't the problem; noise floor is architectural
- **What changed:** Going in, the hypothesis was "DEFER class is under-represented (5/50) and dragging accuracy — collapse to binary and the picture changes." Result: accuracy lifted modestly (qwen35: 76.74% → 79.07%, hermes3: 70% → 70%, qwen3: 66% → 70%, gemma4: 68% → 74%) but **no model clears 90%** even on the easier binary task. GO precision tightens because the FP rate doesn't improve when DEFER→NON_GO collapse moves more truth-NON_GO into the same bucket. The DEFER class was contributing some confusion (~2-6pp accuracy drag depending on model) but the underlying noise floor isn't a class-structure artifact.
- **Plan impact:** T-1741 Recommendation listed three off-ramps with "T-1743 cheapest first." That's now decided: T-1743 ran, NO-GO. Updated guidance: skip T-1742 (qwen35 max_tokens spike — marginal even at optimistic ceiling) and promote T-1744 (different G-064 first-consumer). The architectural concern propagates from 3-class to 2-class, so model-level fixes (more tokens, different model) won't move the needle enough.
- **Triggered:** No new task. The off-ramp tree from T-1741 is now traversed: T-1743 NO-GO → T-1744 is the live path. T-1742 stays captured/later (could be useful as a smaller-scope experiment but not the main route).



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

### 2026-05-05T09:25:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1743-spike-d-off-ramp-re-score-4-model-result.md
- **Context:** Initial task creation

### 2026-05-05T09:27:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3650d9bb
- **Timestamp:** 2026-06-02T14:59:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Write `scripts/spikes/T-1743-binary-rescore.py` that loads `.context/spikes/T-1736-labels.yaml` + the 4 result files (T-1740 hermes3 + T-1741 qwen3/qwen35/gemma4), collapses DEFER → NO-GO in both trut
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/spikes/T-1736-labels.yaml in: Write `scripts/spikes/T-1743-binary-rescore.py` that loads `.context/spikes/T-1736-labels.yaml` + the 4 result files (T-1740 hermes3 + T-1741 qwen3/qw`
### 2026-05-05T09:30:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
