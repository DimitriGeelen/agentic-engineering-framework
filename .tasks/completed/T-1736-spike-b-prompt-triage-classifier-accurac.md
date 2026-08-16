---
id: T-1736
name: "Spike B: prompt-triage classifier accuracy on 30-day backlog (T-1733 sibling)"
description: >
  T-1733 Spike A proved substrate; classifier defaulted GO across 3 samples (1/3 accuracy).
  Spike B: harvest 30 days of user prompts from session JSONLs (~/.claude/projects/),
  label each with manual GO/NO-GO/DEFER ground truth (~50-100 samples), run prompt-triage
  workflow, compute precision/recall per class. Decide: keep hermes3, switch model
  (qwen3, gemma4), revise prompt template (calibration examples), or accept under-precision
  under safety-first defaulting.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [spike]
components: []
related_tasks: [T-1733, T-1737]
arc_id: orchestrator-rethink
created: 2026-05-05T07:36:42Z
last_update: '2026-08-16T22:24:42Z'
date_finished: 2026-05-05T08:14:09Z
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
  - ts: '2026-08-16T22:24:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1736: Spike B: prompt-triage classifier accuracy on 30-day backlog (T-1733 sibling)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Harvest script extracts ≥30 deduplicated, real user prompts from `~/.claude/projects/*/*.jsonl` (last 30 days), written to `.context/spikes/T-1736-prompts.jsonl` (one JSON object per line, fields: id, source, text)
- [x] Ground-truth labels for every harvested prompt in `.context/spikes/T-1736-labels.yaml` (each entry: id, label ∈ {GO, NO-GO, DEFER}, optional note)
- [x] Run-harness script invokes prompt-triage classifier (litellm:4000 → ollama hermes3:8b) per prompt, captures `verdict|rationale|confidence`, writes `.context/spikes/T-1736-results.jsonl`
- [x] Per-class precision/recall + 3×3 confusion matrix + class distribution computed and rendered in `docs/reports/T-1736-spike-b.md`
- [x] Task `## Recommendation` block names a concrete next-step decision: keep hermes3, switch model (qwen3/gemma4), revise prompt template (calibration examples), or accept under-precision under safety-first defaulting — with rationale citing the measured numbers

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

test -f .context/spikes/T-1736-prompts.jsonl
test "$(wc -l < .context/spikes/T-1736-prompts.jsonl)" -ge 30
test -f .context/spikes/T-1736-labels.yaml
python3 -c "import yaml; d = yaml.safe_load(open('.context/spikes/T-1736-labels.yaml')); assert len(d) >= 30; assert all(e['label'] in ('GO','NO-GO','DEFER') for e in d)"
test -f .context/spikes/T-1736-results.jsonl
test "$(wc -l < .context/spikes/T-1736-results.jsonl)" -ge 30
test -f docs/reports/T-1736-spike-b.md
grep -q -i "confusion" docs/reports/T-1736-spike-b.md
grep -q -i "precision" docs/reports/T-1736-spike-b.md
# Path-agnostic — task may be in active/ or completed/ at re-run time
{ cat .tasks/active/T-1736-spike-b-prompt-triage-classifier-accurac.md .tasks/completed/T-1736-spike-b-prompt-triage-classifier-accurac.md 2>/dev/null || true; } | grep -q "## Recommendation"

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

### 2026-05-05 — classifier under-precision is *opposite of safety-first*
- **What changed:** Spike A's all-GO bias on 3 hand-crafted prompts predicted classifier conservatism. Spike B on 50 real prompts shows the *opposite* pattern: GO recall 0.39, classifier predicts NO-GO for 15/33 true-GO prompts. The model interprets "create or focus a task" literally — direct commands like "Run: bin/fw upgrade ...", "Commit the changes ...", "T-198: check verdict ..." are read as "no new task needed, just execute" → predicted NO-GO. The correct framing per template definition is "substantive change to code/config/infra" → GO.
- **Plan impact:** Spike B's listed decision options (keep/switch model/revise prompt/accept) collapse to "the prompt template itself misframes GO". Switching model alone (Option B) is unlikely to fix a semantic-definition gap. Accepting under-precision under safety-first (Option D) is invalid because the bias direction is *anti*-safety: defaulting NO-GO means tasks don't get created when they should, downstream agents skip the gate, governance silently degrades.
- **Triggered:** T-1740 (prompt template revision: add direct-command-GO calibration examples + re-run Spike B). T-1741 (model-switch evaluation, gated on T-1740 outcome). T-1737 (Slice 2 UserPromptSubmit hook) **NOT** unblocked yet — must wait for accuracy ≥ 80% on a re-run.

### 2026-05-05 — confidence is uncalibrated, gating won't save it
- **What changed:** Mean confidence on correct = 0.915, on wrong = 0.880. Gap of +0.035. The score is essentially flat — there is no threshold above which "the classifier is reliably right" and below which "fall through to GO". This rules out the obvious mitigation of `if confidence < 0.7: GO`.
- **Plan impact:** Slice 2 hook design must NOT use confidence-based fallback. If we ship the classifier, we need a different escape valve (e.g. agent override syntax, structural retry on disagreement with prior turn).
- **Triggered:** Note in T-1737 scope: do not implement confidence-thresholded fallback.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

- **Recommendation:** **NO-GO on production rollout** of `prompt-triage` workflow with the current `claude-3-5-sonnet-hermes3` model + current prompt template. Spike B Slice 2 (T-1737 UserPromptSubmit hook integration) is **NOT** unblocked.
- **Rationale:** On 50 real user prompts harvested across 30 days from 19+ consumer projects:
  - Classifier accuracy 40% (20/50). **Always-GO baseline is 66%.** Shipping the classifier would *reduce* correctness by 26 percentage points vs the trivial fallback.
  - Macro F1 0.357. GO recall 0.39 (catastrophic — misses 60% of substantive work requests). NO-GO precision 0.23 (most NO-GO predictions are wrong).
  - Failure direction is *anti-safety*: defaults to NO-GO on direct commands ("Run X", "Commit Y", "T-198: check verdict"), meaning tasks would NOT be created when they should, governance degrades silently.
  - Confidence is uncalibrated (gap correct vs wrong = +0.035) — confidence-thresholded fallback ("if conf<0.7 → GO") is not viable.
- **Evidence:** `docs/reports/T-1736-spike-b.md` (full confusion matrix + per-class metrics + 10 sample disagreements). Raw data in `.context/spikes/T-1736-{prompts,sampled,labels.yaml,results.jsonl}`. Inference run at 1171ms p50, $0 cost (ollama-local), 0 errors, 0 parse failures across 50 prompts.
- **Two follow-up tasks pre-filed (per L-349):**
  - **T-1740** — Revise prompt template with direct-command-GO calibration examples ("Run: ...", "Commit: ...", "T-XXX: ...", agent-dispatch worker prompts). Re-run Spike B harness on the same 50-prompt benchmark to measure delta. Cheaper, single-variable change, attempted first.
  - **T-1741** — Evaluate alternative model (qwen3 / gemma4) on the same benchmark. Gated on T-1740 outcome — only run if template revision alone doesn't reach ≥80% accuracy.
- **What this is NOT:** This is not a bug in the substrate (T-1733 closed substrate gap; T-1734 closed worker-kinds drift). The substrate works perfectly: 50/50 dispatches, 0 errors, sub-2-second latency. The problem is calibration of model + prompt template — exactly what Spike B was designed to measure.

## Updates

### 2026-05-05T07:36:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1736-spike-b-prompt-triage-classifier-accurac.md
- **Context:** Initial task creation

### 2026-05-05T07:38:48Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-05-05T08:02:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-05-05T08:03:51Z — status-update [task-update-agent]
- **Change:** tags: +spike

### 2026-05-05T08:03:58Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5a1583e5
- **Timestamp:** 2026-06-02T14:59:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 20
     - evidence: `{ cat .tasks/active/T-1736-spike-b-prompt-triage-classifier-accurac.md .tasks/completed/T-1736-spike-b-prompt-triage-classifier-accurac.md 2>/dev/null || true; } | grep -q "## Recommendation"`
### 2026-05-05T08:14:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
