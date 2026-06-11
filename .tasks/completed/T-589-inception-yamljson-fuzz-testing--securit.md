---
id: T-589
name: "Inception: YAML/JSON fuzz testing — security fuzzing for framework parsing
  surfaces"
description: >
  OpenClaw has dedicated fuzz test files testing 6 attack vector categories (type
  confusion, Unicode attacks, injection, prototype pollution, XSS vectors, edge cases)
  against parsing surfaces. Our framework processes YAML frontmatter from task files,
  component cards, config files, and skill files with zero fuzz coverage. Investigate:
  which parsing surfaces are security-critical, what attack vectors apply to YAML
  (anchors, billion laughs, merge keys, prototype-like keys), how to structure fuzz
  tests in bash/Python, and whether this justifies a dedicated test suite. Source:
  T-023 comparative analysis, OpenClaw nostr-bus.fuzz.test.ts (548 LOC).

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: [T-549, T-569]
created: 2026-03-23T21:49:31Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-28T09:31:49Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
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

# T-589: Inception: YAML/JSON fuzz testing — security fuzzing for framework parsing surfaces

## Problem Statement

The framework processes YAML frontmatter from task files (~600 tasks), component cards (~162 files), config files (concerns.yaml, learnings.yaml, metrics-history.yaml), and skill files — all via `yaml.safe_load()` in Python and inline `python3 -c` blocks in bash. There is zero fuzz testing for these parsing surfaces. A malicious or malformed task file could corrupt framework state, crash hooks, or cause silent data loss (R-018: "Invalid YAML data disappears without error").

OpenClaw's approach: dedicated `.fuzz.test.ts` files with explicit attack vector constants (not randomized fuzzing) covering 6 categories. Each test verifies either throws or graceful handling.

## Assumptions

1. `yaml.safe_load()` already prevents code execution (unlike `yaml.load()`) — but doesn't prevent all attacks
2. YAML-specific attacks (billion laughs, anchor bombs, merge key abuse) could DoS or confuse the framework
3. Framework YAML parsing trusts file contents completely — no schema validation before processing
4. A single corrupted task file could cascade through handover, metrics, audit, and episodic generation

## Exploration Plan

1. **Map parsing surfaces** — enumerate every `yaml.safe_load`, `json.load`, `python3 -c "import yaml"` invocation
2. **Classify attack vectors** — which of OpenClaw's 6 categories apply to YAML (not all are relevant)?
3. **Build 3 proof-of-concept attacks** — malformed task file, injection via component card, oversized YAML
4. **Assess blast radius** — what breaks when a parsed file is malicious?
5. **Prototype test structure** — 1 fuzz test file in bash/pytest covering top 5 vectors

## Technical Constraints

- Tests must run without external dependencies (no fuzzing frameworks)
- Must work with Python 3.9+ (framework minimum)
- Test execution must complete in <30 seconds (CI-friendly)

## Scope Fence

**IN scope:** YAML/JSON parsing surfaces in framework scripts, explicit attack vector tests, schema validation gaps
**OUT of scope:** Randomized/generative fuzzing, web UI input validation (separate concern), third-party library auditing

## Acceptance Criteria

### Agent
- [x] Parsing surface map complete (53 Python files, 10+ bash files)
- [x] Attack vector classification (8 categories evaluated — see research artifact)
- [x] 3+ proof-of-concept attack results documented (duplicate key divergence, multiline confusion, anchor bombs — all low-risk with safe_load)
- [x] Blast radius assessment for each surface (Python: safe_load mitigated; Bash: grep-immune)
- [x] Go/No-Go decision made with evidence (NO-GO — attack surface smaller than expected)

## Go/No-Go Criteria

**GO if:**
- At least 1 proof-of-concept attack causes unexpected behavior (crash, silent corruption, data loss)
- Parsing surfaces are concentrated enough to cover with <200 LOC of tests
- Tests can run in existing CI pipeline without new dependencies

**NO-GO if:**
- `yaml.safe_load()` handles all attack vectors gracefully (Python's YAML library is robust enough)
- Attack surface is too dispersed — too many parsing points to cover meaningfully
- Real-world risk is negligible (all YAML files are agent-generated, not user-supplied)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
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

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T19:18:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T09:31:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e31acbaa
- **Timestamp:** 2026-06-02T15:03:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
