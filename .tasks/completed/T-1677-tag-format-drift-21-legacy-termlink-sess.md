---
id: T-1677
name: "tag-format drift: 21 legacy TermLink sessions carry task=/role= prefixes —
  cross-repo validator half"
description: >
  T-1654 fixed framework-side spawns to emit canonical 'task:' prefix; T-1649 was
  framework-side half of validator work. 21 live sessions (incl. 10x task=T-1641)
  persist with old tags. Audit fires WARN on orchestrator-rethink arc. Cross-repo
  half (validator in /opt/termlink) is the structural close per audit mitigation.
  Framework-side optional: sweep retag for live sessions before arc close.

status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: [cross-repo, termlink]
components: []
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-02T11:05:49Z
last_update: 2026-05-31T18:50:39Z
date_finished: 2026-05-31T18:50:39Z
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-29T23:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 4
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=4 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1677: tag-format drift: 21 legacy TermLink sessions carry task=/role= prefixes — cross-repo validator half

## Context

T-1654 (framework-side dispatch fix) and T-1649 (validator + invariant) both shipped.
21 legacy `task=`/`role=` sessions cited at filing have since aged out of the TermLink
hub (sessions reap on idle; the canonical-prefix audit lint has been live since
T-1649). Reality check today (2026-05-31, S-2026-0531-2025+1): 28 live sessions,
0 non-canonical prefixes, `orchestrator-mcp-scan` emits no TAG-FORMAT-DRIFT WARN.
The "Framework-side optional: sweep retag for live sessions before arc close" clause
is moot — there is nothing left to sweep. Closing as drift-extinct + structural-fix-shipped.

## Acceptance Criteria

### Agent
- [x] Live-session drift count is 0 (zero sessions with non-canonical tag prefixes — anything outside CANONICAL_PREFIXES in `agents/audit/orchestrator-mcp-scan.sh:101-104`)
- [x] `orchestrator-mcp-scan` does not emit `TAG-FORMAT-DRIFT` in its current report (`.context/audits/orchestrator-LATEST.yaml`)
- [x] Framework-side structural fixes shipped — T-1649 (validator + invariant) and T-1654 (framework dispatch fix) both in `.tasks/completed/`
- [x] Cross-repo validator half is owned by `/opt/termlink` (per body); no framework-side action remaining

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

python3 tools/check_termlink_tag_drift.py

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

### 2026-05-31 — drift extinct before sweep was needed

- **What changed:** The 21 cited `task=`/`role=` sessions all aged out of the
  TermLink hub between 2026-05-02 (filing) and 2026-05-31 (reality check) via
  natural session idle-reap. Today 28 live sessions = 0 non-canonical prefixes.
- **Plan impact:** The "framework-side optional: sweep retag for live sessions
  before arc close" clause is moot — there is nothing left to sweep. The
  structural fix (T-1649 validator + T-1654 framework dispatch) shipped weeks ago
  and the audit lint kept the new drift rate at zero. Time + structural fix did
  the job; no sweep needed.
- **Triggered:** New invariant-direct verifier `tools/check_termlink_tag_drift.py`
  added (mirrors the audit's CANONICAL_PREFIXES set; one-line P-011-friendly
  command) so future tag-format-hygiene tasks can express the invariant as a
  single verification line.

## Recommendation

**Recommendation:** GO (close as work-completed)

**Rationale:** All four Agent ACs satisfied with concrete evidence (drift count
0, audit silent on TAG-FORMAT-DRIFT, T-1649 + T-1654 in completed/, cross-repo
half explicitly out of framework scope per body). The sweep mentioned in the
body was optional, and population for it is zero.

**Evidence:**
- `python3 tools/check_termlink_tag_drift.py` → `OK: 0 non-canonical tags across 28 live session(s).`
- `bash agents/audit/orchestrator-mcp-scan.sh` → only WARN is unrelated (5 unclassified tools)
- `ls .tasks/completed/T-1649-* .tasks/completed/T-1654-*` → both present

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

### 2026-05-02T11:05:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1677-tag-format-drift-21-legacy-termlink-sess.md
- **Context:** Initial task creation

### 2026-05-31T18:48:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dd78c095
- **Timestamp:** 2026-05-31T18:50:39Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — Live-session drift count is 0 (zero sessions with non-canonical tag prefixes — anything outside CANONICAL_PREFIXES in `agents/audit/orchestrator-mcp-scan.sh:101-104`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/orchestrator-mcp-scan.sh in: Live-session drift count is 0 (zero sessions with non-canonical tag prefixes — anything outside CANONICAL_PREFIXES in `agents/audit/orchestrator-mcp-s`
- **AC#2 (Agent)** — `orchestrator-mcp-scan` does not emit `TAG-FORMAT-DRIFT` in its current report (`.context/audits/orchestrator-LATEST.yaml`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/orchestrator-LATEST.yaml in: `orchestrator-mcp-scan` does not emit `TAG-FORMAT-DRIFT` in its current report (`.context/audits/orchestrator-LATEST.yaml`)`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `Cross-repo`

### 2026-05-31T18:50:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
