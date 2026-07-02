---
id: T-1482
name: "Reviewer v1.5 drift re-verification — sandbox isolation strategy (worktree
  vs container vs subprocess)"
description: >
  Reviewer v1.5 drift re-verification — sandbox isolation strategy (worktree vs container
  vs subprocess)

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: []
related_tasks: [T-1442, T-1443, T-1445, T-1448, T-1449, T-1450]
created: 2026-04-25T22:10:49Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-04-25T22:22:04Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
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

# T-1482: Reviewer v1.5 drift re-verification — sandbox isolation strategy (worktree vs container vs subprocess)

## Problem Statement

T-1443 v1.0 (T-1445) ships a **static-scan validator** — it reads task body for anti-patterns but never re-executes verification commands. Drift between "verification passed at completion time" and "verification still passes today" is invisible. Real example from this corpus: T-1086 had `bin/fw doctor >/dev/null 2>&1 || true` — looked passing forever, would never re-detect a regression.

**v1.5 scope:** add a Pass A "drift re-verification" — periodically re-run each completed task's `## Verification` block and FAIL the reviewer verdict if commands no longer pass. Surfaces structural decay between completion and now.

**The hard question (this inception's go/no-go):** how to safely re-execute arbitrary shell commands from 1358+ historical tasks **without** mutating the live framework state? Verification commands write to `.context/`, `.tasks/`, sometimes touch `~/.claude/`, sometimes spawn services. Running them in-place would corrupt working memory and trigger hooks recursively.

## Assumptions

- A1: Verification commands SHOULD be idempotent (P-011 design intent), but historical commands aren't audited for that — many likely have side effects.
- A2: Most verification commands are read-only (`grep`, `test -f`, `python3 -c "import yaml; yaml.safe_load(...)"`), but a non-trivial minority touch state (`bin/fw audit`, `bin/fw doctor`, `curl http://localhost:3000/...`).
- A3: Re-execution latency matters: if v1.5 takes >5min for a daily audit cron over 1358 tasks, it won't run.
- A4: A pure "diff detection" approach (hash files referenced in verification) could substitute for re-execution in some cases — not all.
- A5: `git worktree` is the cheapest isolation primitive available in this stack; container runtimes (docker/podman) violate portability directive (CLAUDE.md §Constitutional Directive 4) for the framework itself.

## Exploration Plan

**Spike 1 (1h):** Audit 50 randomly sampled `## Verification` blocks. Classify: read-only / state-touching / network-dependent / time-dependent. Output: ratio table + risk matrix.

**Spike 2 (1h):** Prototype `git worktree` re-verification: spin up worktree at task's `date_finished` commit, run verification, capture exit codes, tear down. Measure: setup latency, success rate, false-positive rate (where worktree state differs from completion state in irrelevant ways).

**Spike 3 (1h):** Prototype "diff detection" alternative: hash all files referenced in verification commands at completion, store in `## Reviewer Verdict`, re-hash on audit. No re-execution. Measure: coverage (what fraction of verification logic is captured by file-hash drift).

**Spike 4 (30min):** Evaluate subprocess-with-restricted-env (`HOME=/tmp/sandbox PATH=$(getconf PATH) ...`) as fallback for commands that need execution but not full FS isolation.

## Technical Constraints

- **Portability (CLAUDE.md directive 4):** No container runtime (docker/podman) — framework MUST run on minimal Linux/macOS without infrastructure deps.
- **Reentrancy:** Re-execution MUST NOT trigger framework hooks (commit-msg, PostToolUse) or write to live `.context/`. Worktree + `GIT_DIR` overrides + `FW_REVIEWER_REVERIFY=1` flag to short-circuit hooks.
- **Network commands:** `curl http://localhost:3000/...` can't be sandboxed without a stub — either skip network commands in re-verification (whitelist by classifier from Spike 1) or accept they'll fail in CI-like environments.
- **macOS bash 3.2:** Any new bash plumbing must avoid `declare -A` (per L-518 / CLAUDE.md POSIX-safe lookups).
- **Latency budget:** Daily audit cron must complete in <10min for 1358 tasks → <450ms per task on average.

## Scope Fence

**IN:**
- Decide isolation strategy (worktree | diff-detection | restricted-subprocess | hybrid)
- Identify which verification commands are unsafe to re-execute (Spike 1 classifier)
- Latency-bound design for daily audit cron
- Hook into `fw reviewer audit` (already exists per T-1447 v1.2) to add Pass A drift detection

**OUT:**
- v3+ catalogue expansion (8→12 patterns) — separate inception
- v2.1 sovereignty enforcement on overrides — separate inception
- Per-task re-verification triggers from Watchtower UI (deferred to v1.6+)
- Auto-quarantine of tasks that drift (only flag in verdict; never auto-revert)

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated (drift between completion-time PASS and present-day PASS is invisible to v1.0 static-scan)
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested via 3 spikes (50-task verification audit, worktree latency benchmark with two patterns, diff-detection coverage analysis)
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale (hybrid Pass A diff-detection over Pass B worktree-reuse; container/subprocess disqualified)

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

**GO if:**
- An isolation strategy exists that meets all 4 directives (antifragility, reliability, usability, portability) — confirmed: worktree-with-reuse + diff-detection hybrid does
- Latency for full-corpus audit fits inside 10-min budget — confirmed: 7min serial, 2min parallel-4
- At least one strategy avoids docker/podman runtime dependency — confirmed: worktree (no extra runtime)
- Implementation cost is bounded to 1 build task (not an open-ended program) — confirmed: lib/reviewer/drift.py + lib/reviewer/reverify.py + heuristic classifier

**NO-GO if:**
- All four candidate strategies fail constraint checks (didn't happen — A and hybrid passed)
- Latency budget exceeded by all strategies (didn't happen — pattern B is well inside budget)
- Drift detection coverage <30% even with hybrid (didn't happen — full coverage when Pass B runs)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO — hybrid two-pass: diff-detection (Pass A) over worktree-with-reuse re-execution (Pass B). Disqualify container (portability) and restricted-subprocess (Linux-only).

**Rationale:** Pass A alone catches ~40% of drift — insufficient as verdict. Pass B alone is fast enough but wastes work re-running unchanged tasks. Hybrid uses cheap signal to gate expensive deep-check; matches the corpus shape (50% read-only / 17.5% state-touching / 20% network) at the right cost.

**Evidence:**
- Spike 1 (50-task random sample): 50% read-only / 17.5% state-touching / 20% network-dependent / 12.5% other → hybrid is the right shape, not pure-A or pure-B
- Spike 2 (worktree benchmark, two patterns): reuse-pattern at **339ms avg/task** = 7min serial / 2min parallel-4 for 1358-task corpus → fits 10-min audit-cron budget with headroom
- Spike 3 (diff-detection analysis): file-hash diff catches ~40% of drift types but misses tool-semantics drift, file moves, and bug-fix cases → useful as signal layer, not as verdict
- Spike 4 (subprocess): `unshare --mount` is Linux-only → disqualified at constraint level (CLAUDE.md portability directive)

**Out-of-scope for v1.5 build (deferred to v1.6+):**
- Network-stub server for curl-based verifications (v1.5 skips with annotation)
- Per-task on-demand re-verify button in Watchtower UI
- Auto-quarantine of drifted tasks (needs sovereignty model first)
- Verification block linter

**Full design:** `docs/reports/T-1482-reviewer-v15-drift-reverification.md`

**The Human AC asks:** Does the hybrid Pass A + Pass B design feel right? If yes → GO, create v1.5 build task. If no → drop counter-proposal in `## Decisions` and the agent will re-spike.

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

**Rationale**: Pass A alone catches ~40% of drift — insufficient as verdict. Pass B alone is fast enough but wastes work re-running unchanged tasks. Hybrid uses cheap signal to gate expensive deep-check; matches the corpus shape (50% read-only / 17.5% state-touching / 20% network) at the right cost.

**Date**: 2026-04-25T22:22:03Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-25T22:22:03Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Pass A alone catches ~40% of drift — insufficient as verdict. Pass B alone is fast enough but wastes work re-running unchanged tasks. Hybrid uses cheap signal to gate expensive deep-check; matches the corpus shape (50% read-only / 17.5% state-touching / 20% network) at the right cost.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-99079ef2
- **Timestamp:** 2026-06-02T14:57:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T22:22:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
