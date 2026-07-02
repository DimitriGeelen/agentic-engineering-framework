---
id: T-1729
name: "meta-rca: agent did substantive work (RCA, diagnostics, edits) without a task
  — multiple breakdown points in single session"
description: >
  Inception: meta-rca: agent did substantive work (RCA, diagnostics, edits) without
  a task — multiple breakdown points in single session

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: [T-1730, T-1731, T-1732, T-1716, T-1726, T-1727]
arc_id: orchestrator-rethink
created: 2026-05-04T22:03:56Z
last_update: '2026-06-11T22:23:57Z'
date_finished: 2026-05-05T06:47:06Z
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

# T-1729: meta-rca: agent did substantive work (RCA, diagnostics, edits) without a task — multiple breakdown points in single session

## Problem Statement

Agent ran four discrete violations of "Nothing gets done without a task"
in a single session post-`/compact`: (1) stale-budget RCA in chat with
no task, (2) Bash diagnostics with no task, (3) Bash mutations of
T-1716 + Edits while focus was T-1727, (4) was about to RCA the
breakdown itself with no task. Only after explicit user demand
("MAJOR BREAKDOWN EVENT … have we created an arc, are we following
framework governance???") did the agent stop, file T-1729, set focus,
produce the artefact.

**For whom:** the framework's governance integrity. CLAUDE.md asserts
*"Nothing gets done without a task. This is enforced structurally by
the framework, not by agent discipline."* Empirically false for Bash
work, exempt-path Edits, and text output — see forensic evidence in
`docs/reports/T-1729-meta-rca.md`.

**Why now:** the failure is the G-018 family (rule + no enforcement →
decay) and the user has flagged it explicitly. Substrate to mitigate
(orchestrator dispatch substrate, T-1689/1690/1691/1692) is in place
and looking for its first real consumer (G-064).

Full RCA: `docs/reports/T-1729-meta-rca.md`.

## Assumptions

- **A1**: The 4 gaps identified (G1 Bash matcher, G2 path-exemption non-diff-aware, G3 focus-target drift, G4 text output) are exhaustive for this failure class. Falsifier: a 5th violation surface emerges within 30 days.
- **A2**: Fix 1 (Bash matcher + focus-drift gate) is tractable in <50 LOC + bats. Falsifier: implementation requires invasive refactor of update-task.sh or settings.json schema.
- **A3**: Fix 2 (Human-AC tick guard via diff inspection) is tractable in <100 LOC. Falsifier: diff parsing is fragile across multiline AC bodies / interleaved Steps blocks.
- **A4**: Prompt-triage workflow latency stays <500ms p95 with ollama-local. Falsifier: spike measures >1s p95.
- **A5**: Fail-OPEN on prompt-triage unreachability is the correct safety stance. Falsifier: post-deploy data shows agents exploit unreachability windows for governance bypass.

## Exploration Plan

Three time-boxed deliverables, each its own task. Each ships independently.

**Deliverable 1 — Bash matcher + focus-drift gate** (build, ~30 min implementation):
- Add `Bash` to `check-active-task` matcher in `.claude/settings.json`
- Augment `agents/context/check-active-task.sh` to detect target-vs-focus drift on `fw task update T-X`, `fw context add-* --task T-X`, `git commit -m "T-X: ..."`
- `--switch-focus` override flag, logged via `log_gate_bypass`
- Bats coverage per Test Plan in §7 of report
- Pin the matcher gap in tests so any regression fails CI

**Deliverable 2 — Human-AC tick guard** (build, ~1 hour implementation):
- PreToolUse hook on Write/Edit to `.tasks/*` files
- Diff-aware: parse old vs new content, detect `[ ]` ↔ `[x]` toggle under `### Human` heading
- Block under `$CLAUDECODE=1`; `--i-am-human` override mirrors T-1671
- Bats coverage including off-task and same-task scenarios

**Deliverable 3 — Prompt-triage as G-064 first consumer** (inception, time-boxed spikes):
- Spike A: `UserPromptSubmit` hook integration with `fw resolver dispatch` — measure p50/p95 latency, cost per call, fail-open behavior on ollama unreachability
- Spike B: prompt classifier on a 30-day backlog — measure precision/recall on "needs task" verdict
- Goal: GO/NO-GO decision on shipping Layer 1; decide if it supersedes T-1726 as v0.5

## Technical Constraints

- `UserPromptSubmit` hook latency budget: <500ms p95 (else user perceives stutter)
- Ollama at 192.168.10.107:11434 (per CLAUDE.md); cloud fallback via litellm proxy
- Cost cap: <$0.10/day at expected prompt volume (10–100 prompts/day)
- Fail-OPEN on orchestrator unreachability — framework must NOT silence the agent
- Hook performance budget: <5ms for synchronous gates (T-1626); LLM-bound gates may exceed this and must be async-friendly
- Settings.json schema: nested matcher format only (CLAUDE.md memory: flat format silently fails)

## Scope Fence

**IN scope (T-1729 itself):**
- Producing the meta-RCA artefact (`docs/reports/T-1729-meta-rca.md`)
- Filing 3 sibling tasks (focus-drift gate, Human-AC tick guard, prompt-triage inception) with cross-tags
- Decision capture (Recommendation GO, decompose into 3 tasks, prompt-triage > escalation-scan as v0.5)

**OUT of scope (deferred to siblings):**
- Implementing the structural fixes (siblings 1+2)
- Running the prompt-triage spikes (sibling 3)
- Modifying T-1726 escalation-scan inception (re-scoping happens once sibling 3 reports)
- New CLAUDE.md text — siblings own their respective text updates

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

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

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

**Recommendation:** GO

**Rationale:**

User-flagged MAJOR BREAKDOWN: agent (a) wrote stale-budget RCA in chat without a task, (b) ran Bash diagnostics + Edits to investigate verification gate failure under stale focus T-1727 not T-1716, (c) was about to RCA the breakdown itself without a task. Need to identify which structural gates failed vs which were absent vs which were correctly working but bypassable. Recommendation GO because the violations are concrete, the failure-class is recurrent (G-018 family — rule+no-enforcement decay), and the user has explicitly named it as a high-severity event.

**Evidence:**

- Hook telemetry: `audit-task-tools=18`, `budget-gate=18`, `check-tier0=17` but `check-active-task=1` between T-1716 commit (`12f0fe7c4`) and T-1729 filing — ~14 Bash commands fired post-commit, zero went through the active-task gate.
- `.claude/settings.json:44-52` — `check-active-task` matcher is `Write|Edit`, `Bash` matcher is bound only to `check-tier0`. The Bash-handling code in `agents/context/check-active-task.sh:50-82` is dead code under current settings.
- `.context/audits/gate-bypass.jsonl` does not exist — no `--force`/`--skip-verification` was used because no gate fired to require one.
- `agents/context/check-active-task.sh:116-120` — `.tasks/*` exempt path is total, no diff-aware logic distinguishes Agent vs Human AC ticks.
- T-1716 completion history: agent edited `[ ] [REVIEW]` → `[x] [REVIEW]` Human AC on the basis of verbal user waiver. CLAUDE.md §Agent/Human AC Split: *"NEVER check a `### Human` AC. Only the human may verify and check these boxes."* Hook didn't catch it.
- Sister-arc context: T-1726 (escalation-scan v0.5) was filed yesterday as named G-064 closure path. Re-evaluation in §6 of the report concludes prompt-triage is a higher-leverage v0.5 consumer.

**Filing decisions captured (see report §8):**
- Three-task decomposition over single mega-task
- Prompt-triage promoted to v0.5; escalation-scan demoted to v0.6
- Fail-OPEN on prompt-triage unreachability

**Risk acknowledged (see report §9):** layer-1 latency tax, false-positive triage fatigue, three-layer drift, §ACD substrate-vs-deliverable conflation. Each sibling task owns its mitigation.

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

**Rationale**: User-flagged MAJOR BREAKDOWN: agent (a) wrote stale-budget RCA in chat without a task, (b) ran Bash diagnostics + Edits to investigate verification gate failure under stale focus T-1727 not T-1716, (c) was about to RCA the breakdown itself without a task. Need to identify which structural gates failed vs which were absent vs which were correctly working but bypassable. Recommendation GO because the violations are concrete, the failure-class is recurrent (G-018 family — rule+no-enforcement decay), and the user has explicitly named it as a high-severity event.

**Date**: 2026-05-05T06:47:06Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-05T05:38:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-05T05:42:29Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-05T05:42:29Z — status-update [task-update-agent]
- **Change:** tags: +meta-rca-anchor

### 2026-05-05T06:47:06Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** User-flagged MAJOR BREAKDOWN: agent (a) wrote stale-budget RCA in chat without a task, (b) ran Bash diagnostics + Edits to investigate verification gate failure under stale focus T-1727 not T-1716, (c) was about to RCA the breakdown itself without a task. Need to identify which structural gates failed vs which were absent vs which were correctly working but bypassable. Recommendation GO because the violations are concrete, the failure-class is recurrent (G-018 family — rule+no-enforcement decay), and the user has explicitly named it as a high-severity event.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2d739e7d
- **Timestamp:** 2026-06-02T14:59:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-05T06:47:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
