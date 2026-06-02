---
id: T-1674
name: "fabric drift O(n^2) — stale-edge check spawns 1016 python3 processes for 508 cards"
description: >
  fabric drift O(n^2) — stale-edge check spawns 1016 python3 processes for 508 cards

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/fabric/lib/drift.sh, tests/unit/test_fabric_drift_performance.py]
related_tasks: []
created: 2026-05-02T09:09:32Z
last_update: 2026-05-02T09:12:48Z
date_finished: 2026-05-02T09:12:48Z
---

# T-1674: fabric drift O(n^2) — stale-edge check spawns 1016 python3 processes for 508 cards

## Context

`agents/fabric/lib/drift.sh:73-109` runs the stale-edge check by
spawning TWO python3 subprocesses for every fabric card (one to print
unresolved targets, one to count them). Each subprocess re-reads ALL
508 cards from disk to rebuild the `known` set.

Empirical measurement (2026-05-02 on 508-card repo):
- Single python3 reading all 508 cards: ~0.66s
- Two spawns per card × 508 cards = 1,016 spawns
- Estimated total: 1,016 × 0.66s ≈ 11 minutes

`bin/fw fabric drift` consequently times out at any reasonable
verification gate timeout (>60s observed in T-1673 verification
attempt). This makes the command effectively unusable on the live repo
and starves the audit pipeline.

Fix: rewrite the stale-edge check as a single python3 invocation
that processes all cards once. Same shape as the orphan check (fast
shell loop), with a single Python pass at the end if needed for
unresolved-target emission.

Discovered while completing T-1673 (orphan-check absolute-path bug).

## Acceptance Criteria

### Agent
- [x] `bin/fw fabric drift` completes in under 5 seconds on the 508-card live repo
- [x] Stale-edge output is preserved byte-for-byte (same unresolved-target lines, same count)
- [x] All existing fabric tests still pass

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
python3 -m pytest tests/unit/test_fabric_drift_performance.py tests/unit/test_fabric_drift_absolute_paths.py -q

## RCA

**Symptom:** `bin/fw fabric drift` hangs >60s on 508-card repo, regularly
exceeds verification timeouts. Real-world runtime measured at ~11 minutes.

**Root cause:** stale-edge check at `agents/fabric/lib/drift.sh:73-109`
spawns 2 python3 subprocesses per fabric card (one for stdout
emission, one for counting), each one re-loading all 508 cards from
disk to rebuild the `known` set. Total: ~1,016 spawns, each costing
~0.66s for the YAML scan.

**Why structurally allowed:** No performance regression test on the
drift command. The original implementation worked fine on small
fabrics (<50 cards); growth to 508 cards (a healthy fabric for a 2yr
framework) crossed the line where the per-card spawning became
intolerable. The cost was hidden inside an audit subcommand operators
rarely time, and no test fixture exercised more than a handful of
cards.

**Prevention:** `tests/unit/test_fabric_drift_performance.py` —
20-card fixture with hard 10s budget. Catches any future revert to
per-card python3 spawning before it merges. Loose budget (10s vs the
~3s actual) means CI won't flake on slow hosts but a 2× regression
fires.

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

### 2026-05-02T09:09:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1674-fabric-drift-on2--stale-edge-check-spawn.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0b95d6be
- **Timestamp:** 2026-06-02T14:59:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-02T09:12:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
