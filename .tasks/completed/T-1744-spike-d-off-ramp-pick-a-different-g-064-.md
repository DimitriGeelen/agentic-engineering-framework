---
id: T-1744
name: "Spike D off-ramp: pick a different G-064 first-consumer (drop prompt-triage)"
description: >
  Spike D (T-1741) NO-GO outcome rules out prompt-triage as orchestrator's first production
  consumer. The systemic signal is that 3-class prompt classification on a 7-8B local
  model is too noisy for production gating, not that we picked the wrong model or
  template. T-1688 G-064 candidate survey already named escalation-scan v0.5 (T-1727)
  as preferred. Inception-class task to evaluate: does T-1727 belong as the orchestrator's
  first consumer, or is there a stronger candidate from the T-1688 survey? Decision
  criteria: workload that benefits from route_cache learning, doesn't require 80%+
  classification accuracy, has clear success metric. Filed captured/later per L-349
  — human decides.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [inception, follow-up]
components: [lib/inception_recommendation.sh, lib/task-audit.sh, 
      web/blueprints/inception.py, web/templates/inception_detail.html]
related_tasks: [T-1741, T-1737, T-1688, T-1727]
arc_id: orchestrator-rethink
created: 2026-05-05T09:25:37Z
last_update: '2026-06-11T22:23:57Z'
date_finished: 2026-05-05T13:50:15Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1744: Spike D off-ramp: pick a different G-064 first-consumer (drop prompt-triage)

## Problem Statement

**For:** the orchestrator-rethink arc (G-064 first-consumer question).
**The problem:** Spike D (T-1741) and binary-reframe re-score (T-1743) both NO-GO — prompt-triage classification is below production-gating quality on every 7-8B local ollama model tested, under both 3-class and binary formulations. T-1737 (Slice 2 hook) is BLOCKED indefinitely. The orchestrator substrate (T-1689/T-1690/T-1691/T-1692) is shipped and healthy (5 real dispatches, 100% outcome enrichment per `bin/fw orchestrator status`) but has no living first consumer. **G-064 stays open until a real consumer is wired.**
**Why now:** Spike-arc is freshly closed (B → C → D → D′, four sessions of work). Decision can be made on the same evidence that closed prompt-triage. Delaying loses context.

## Assumptions

- **A1:** T-1727 (escalation-scan v0.5 build) is still the right consumer named by T-1688/T-1726, not invalidated by Spike-arc findings. → Validates by re-reading T-1688 conclusion (`docs/reports/T-1688-candidate-consumer-survey.md`).
- **A2:** Promoting T-1727 to active horizon is cheaper than starting a fresh inception. → Validates by checking T-1727's existing scope.
- **A3:** Spike D's learning ("3-class on 7-8B local can't hit 90%") generalises — T-1727's escalation-scan must tolerate ~75-80% LLM accuracy, not assume 90%+. Carry this as a design constraint.
- **A4:** No new candidate has surfaced since T-1688 that competes with T-1727.

## Exploration Plan

This is a **promotion decision, not exploration.** The exploration was T-1688 (survey) + Spike B/C/D/D′ (eliminating prompt-triage). Work for THIS task:

1. Re-read T-1688 + T-1726 conclusions — done.
2. Verify T-1727 is build-ready: scope, ACs, Verification.
3. Write the Recommendation: promote T-1727, DEFER, or NO-GO.

No spikes. No prototypes. Pure decision artifact.

## Technical Constraints

- T-1727 inherits Spike D's learning: orchestrator consumers cannot assume >85% LLM accuracy on 7-8B local models. Design must tolerate noise (confidence-thresholded fallback, non-blocking advisory output, or human-in-loop for edge cases).
- route_cache success-rate learning needs ground truth; T-1727 design must specify how the framework verifies escalation-scan output (probably via outcome-enrichment hook → `dispatch-outcomes.jsonl`, same path T-1690 wired for prompt-triage).

## Scope Fence

**IN:** Decide whether to promote T-1727 to active horizon now. Update T-1727 frontmatter (horizon, related_tasks) if GO. Document the decision so future audit can trace G-064 mitigation.
**OUT:** Building T-1727 (separate build, separate session). Rewriting T-1727's ACs (its inception T-1726 set them). Considering brand-new candidates (would be a new inception).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if (promote T-1727 to active horizon):**
- T-1727 was already named in T-1688 + T-1726 as the orchestrator's first real consumer (not invalidated)
- T-1727 has an ACs/Verification scope from its inception
- No competing candidate surfaced in the Spike arc
- The Spike-D learning (75-80% accuracy ceiling) is design-tolerable for an escalation-scan workload, not blocking

**DEFER if:**
- T-1727's scope needs rework before it's build-ready (would imply a fresh inception, T-1726 wasn't enough)
- A non-orchestrator priority outranks the G-064 consumer wiring this week
- Open arc work upstream of T-1727 is unresolved (T-1718 evolution-gate, T-1722 artefact paths, etc.)

**NO-GO if:**
- A stronger candidate has surfaced since T-1688 (none observed)
- The architectural learning from Spike D rules out LLM-augmented orchestrator consumers entirely (it doesn't — only rules out 90%+ classification on 7-8B local)
- G-064 is being closed by accepting "developer-facing tool, no production consumer" as the long-term answer (this was option 1 of T-1688's 1+4 — half-accepted, but option 4 is the live path)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** **GO** — promote T-1727 (escalation-scan v0.5 build) from `captured/next` to `started-work/now`. Wire it as the orchestrator's first real production consumer. Close G-064 via option 4 of T-1688's 1+4 plan.

**Rationale:** Three independent decisions converge on the same answer:

1. **T-1688** (G-064 candidate-consumer survey, completed 2026-05-02): surveyed 18 autonomous workloads, ruled out retrofit, named T-1727 (escalation-scan v0.5) as the smallest concrete real-consumer path, with internal source-code precedent (`tools/escalation-scan-v0.py:1` calls itself a v0 spike, lines 6-10 say "intentionally simple"). Lib hook already exists (`lib/reviewer/static_scan.py:18-19` → "Orchestrator routing (v3+)").
2. **T-1726** (escalation-scan v0.5 inception, completed 2026-05-04 with **GO** decision): explicitly approved the LLM-augmentation path. T-1727 is the build-task child of that GO.
3. **Spike B/C/D/D′** (this week, T-1736/T-1740/T-1741/T-1743): closed prompt-triage as a viable consumer. Confirms T-1688's prediction that "none of the existing autonomous workloads is LLM-amenable today" applied to prompt-triage too — it never was a retrofit candidate, it was a green-field experiment that didn't reach quality.

The Spike-arc's architectural finding — 7-8B local ollama models cap at ~75-80% accuracy on prompt classification — is **design-tolerable** for escalation-scan: the workload's purpose is to surface candidate escalations for human review, not to gate user prompts. False positives are cheap (human ignores), false negatives are mitigated by the existing static-scan layer. The 80% ceiling becomes a virtue here: noisy-but-better-than-zero augmentation is exactly what an advisory escalation queue needs.

**Evidence:**
- T-1688 Recommendation block: GO on option 1+4 (`docs/reports/T-1688-candidate-consumer-survey.md` + `.tasks/completed/T-1688-g-064-candidate-consumer-survey--classif.md`)
- T-1726 Decision: GO on escalation-scan v0.5 (`.tasks/completed/T-1726-escalation-scan-v05--llm-augmentation-as.md`, `**Recommendation:** GO`)
- T-1727 (build task, captured/next): `.tasks/active/T-1727-v05-build--escalation-scan-with-llm-augm.md` — ready to promote
- Orchestrator substrate health: `bin/fw orchestrator status` reports 5 real dispatches, 100% outcome enrichment, route_cache learning live
- Spike-D NO-GO closes prompt-triage: `docs/reports/T-1741-spike-d.md`, `docs/reports/T-1743-binary-rescore.md`
- T-1737 (Slice 2 hook) parked: full BLOCKED context in `.tasks/active/T-1737-slice-2-userpromptsubmit-hook--promptund.md`

**On the off-ramps named in T-1741:**
- T-1742 (qwen35 max_tokens=4096): stays captured/later. Marginal even at optimistic ceiling. Run only if a future agent specifically needs to know whether the parse-fails were correct.
- T-1743 (binary reframe): completed this session — NO-GO confirmed.
- T-1744 (this task): named the path forward → T-1727.

**Asks of the human:**
1. Confirm the GO recommendation, OR
2. DEFER if other work outranks this week, OR
3. NO-GO if you'd rather close G-064 by accepting "developer-facing tool, no production consumer" (option 1 of T-1688 alone, dropping option 4).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Three independent decisions converge on the same answer:

1. **T-1688** (G-064 candidate-consumer survey, completed 2026-05-02): surveyed 18 autonomous workloads, ruled out retrofit, named T-1727 (escalation-scan v0.5) as the smallest concrete real-consumer path, with internal source-code precedent (`tools/escalation-scan-v0.py:1` calls itself a v0 spike, lines 6-10 say "intentionally simple"). Lib hook already exists (`lib/reviewer/static_scan.py:18-19` → "Orchestrator routing (v3+)").
2. **T-1726** (escalation-scan v0.5 inception, completed 2026-05-04 with **GO** decision): explicitly approved the LLM-augmentation path. T-1727 is the build-task child of that GO.
3. **Spike B/C/D/D′** (this week, T-1736/T-1740/T-1741/T-1743): closed prompt-triage as a viable consumer. Confirms T-1688's prediction that "none of the existing autonomous workloads is LLM-amenable today" applied to prompt-triage too — it never was a retrofit candidate, it was a green-field experiment that didn't reach quality.

The Spike-arc's architectural finding — 7-8B local ollama models cap at ~75-80% accuracy on prompt classification — is **design-tolerable** for escalation-scan: the workload's purpose is to surface candidate escalations for human review, not to gate user prompts. False positives are cheap (human ignores), false negatives are mitigated by the existing static-scan layer. The 80% ceiling becomes a virtue here: noisy-but-better-than-zero augmentation is exactly what an advisory escalation queue needs.

**Date**: 2026-05-05T13:50:15Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-05T09:33:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-05-05T13:50:15Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Three independent decisions converge on the same answer:

1. **T-1688** (G-064 candidate-consumer survey, completed 2026-05-02): surveyed 18 autonomous workloads, ruled out retrofit, named T-1727 (escalation-scan v0.5) as the smallest concrete real-consumer path, with internal source-code precedent (`tools/escalation-scan-v0.py:1` calls itself a v0 spike, lines 6-10 say "intentionally simple"). Lib hook already exists (`lib/reviewer/static_scan.py:18-19` → "Orchestrator routing (v3+)").
2. **T-1726** (escalation-scan v0.5 inception, completed 2026-05-04 with **GO** decision): explicitly approved the LLM-augmentation path. T-1727 is the build-task child of that GO.
3. **Spike B/C/D/D′** (this week, T-1736/T-1740/T-1741/T-1743): closed prompt-triage as a viable consumer. Confirms T-1688's prediction that "none of the existing autonomous workloads is LLM-amenable today" applied to prompt-triage too — it never was a retrofit candidate, it was a green-field experiment that didn't reach quality.

The Spike-arc's architectural finding — 7-8B local ollama models cap at ~75-80% accuracy on prompt classification — is **design-tolerable** for escalation-scan: the workload's purpose is to surface candidate escalations for human review, not to gate user prompts. False positives are cheap (human ignores), false negatives are mitigated by the existing static-scan layer. The 80% ceiling becomes a virtue here: noisy-but-better-than-zero augmentation is exactly what an advisory escalation queue needs.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-48c74fc1
- **Timestamp:** 2026-06-02T14:59:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-05T13:50:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
