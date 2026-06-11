---
id: T-1666
name: "T-1642-B4 framework: fw config plumbing for routing-policy.yaml"
description: >
  Implementation half of T-1642 GO decision (substrate-side B1/B2/B3 file in /opt/termlink).
  Lift the 13 routing-policy constants from code defaults to a routing-policy.yaml
  read via fw_config. Wire DISPATCH_MODEL_DEFAULT, ARC_COMPLETION_THRESHOLD, and the
  new keys (PROMOTION_THRESHOLD_BYPASS, PROMOTION_THRESHOLD_TEMPLATE, FAILURE_THRESHOLD,
  COOLDOWN, DEFAULT_TTL_HOURS, CONFIDENCE_THRESHOLD, etc.) so projects can override
  per-instance via .framework.yaml. Validate at audit time.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [from-T-1642]
components: []
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-02T05:37:42Z
last_update: '2026-06-11T22:23:55Z'
date_finished: 2026-05-02T10:21:07Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
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

# T-1666: T-1642-B4 framework: fw config plumbing for routing-policy.yaml

## Context

T-1642's recommendation called for four follow-up build tasks (B1–B4):
B1/B2/B3 substrate-side in `/opt/termlink` (lift 13 routing-policy
constants to `/opt/termlink/etc/routing-policy.yaml`), B4 framework-side
(`fw_config` plumbing).

Inspection during scoping (2026-05-02) revealed:

1. The framework currently consumes only **2 of the 13 constants**
   (`DISPATCH_MODEL_DEFAULT`, `ARC_COMPLETION_THRESHOLD`) — both already
   plumbed (lib/config.sh:167–168).
2. The other 11 are substrate-internal `termlink-hub` constants
   (`template_cache.rs`, `bypass.rs`, `circuit_breaker.rs`,
   `route_cache.rs`).
3. Substrate-side B1/B2/B3 has NOT shipped as of 2026-05-02
   (`/opt/termlink/etc/routing-policy.yaml` does not exist).

Reclassified from build → inception. Three feasibility paths analyzed
(wait-for-substrate / env-var-passthrough / drop-scope). Full analysis
in `docs/reports/T-1666-fw-config-plumbing-routing-policy.md`.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated (only 2/13 constants are framework-side; 11 are substrate-internal)
<!-- @auto-tick-on-decide -->
- [x] Three feasibility paths evaluated (wait / env-var passthrough / drop scope)
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with promotion criteria for revisiting

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

## Recommendation

**Recommendation:** DEFER

**Rationale:** The 11 substrate-internal constants (PROMOTION_THRESHOLD,
FAILURE_THRESHOLD, COOLDOWN, DEFAULT_TTL_HOURS, CONFIDENCE_THRESHOLD,
task_type taxonomy, tag prefix, discovery filter, concurrency cap,
attribution) belong in `/opt/termlink/etc/routing-policy.yaml` and
should be consumed by `termlink-hub` directly. The 2 framework-side keys
(DISPATCH_MODEL_DEFAULT, ARC_COMPLETION_THRESHOLD) are already plumbed
via lib/config.sh:167–168. Adding 11 keys to lib/config.sh that nothing
in the framework reads is dead surface area at risk of config drift.

**Promotion criteria (revisit if):**
- Substrate ships `/opt/termlink/etc/routing-policy.yaml` AND a consumer
  project requests per-project override via `.framework.yaml`.
- A new framework feature emerges that reads any of the 11
  substrate-internal constants (none currently planned).

**Evidence:**
- `lib/config.sh:167–168` — DISPATCH_MODEL_DEFAULT + ARC_COMPLETION_THRESHOLD
  already plumbed; remaining 11 keys absent.
- `/opt/termlink/crates/termlink-hub/src/{template_cache,bypass,circuit_breaker,route_cache}.rs`
  — all 11 constants live in Rust hub code, not consumed by framework.
- `git -C /opt/termlink log --since=2026-05-01` — no commits matching
  T-1642/B1/B2/B3/routing-policy since GO; substrate focused on
  T-1438/T-1418 chat-arc + auth-healing work.
- `docs/reports/T-1666-fw-config-plumbing-routing-policy.md` —
  full three-path analysis.

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

### 2026-05-02T05:37:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1666-t-1642-b4-framework-fw-config-plumbing-f.md
- **Context:** Initial task creation

### 2026-05-02T05:37:51Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-02T05:37:52Z — status-update [task-update-agent]
- **Change:** tags: +from-T-1642

### 2026-05-02T08:53:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-05-02T08:55:00Z — status-update [task-update-agent]
- **Change:** workflow_type: build → inception

### 2026-05-02T08:56:29Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-02T10:21:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: DEFER

Rationale: The 11 substrate-internal constants (PROMOTION_THRESHOLD,
FAILURE_THRESHOLD, COOLDOWN, DEFAULT_TTL_HOURS, CONFIDENCE_THRESHOLD,
task_type taxonomy, tag prefix, discovery filter, concurrency cap,
attribution) belong in `/opt/termlink/etc/routing-policy.yaml` and
should be consumed by `termlink-hub` directly. The 2 framework-side keys
(DISPATCH_MODEL_DEFAULT, ARC_COMPLETION_THRESHOLD) are already plumbed
via lib/config.sh:167–168. Adding 11 keys to lib/config.sh that nothing
in the framework reads is dead surface area at risk of config drift.

Promotion criteria (revisit if):
- Substrate ships `/opt/termlink/etc/routing-policy.yaml` AND a consumer
  project requests per-project override via `.framework.yaml`.
- A new framework feature emerges that reads any of the 11
  substrate-internal constants (none currently planned).

Evidence:
- `lib/config.sh:167–168` — DISPATCH_MODEL_DEFAULT + ARC_COMPLETION_THRESHOLD
  already plumbed; remaining 11 keys absent.
- `/opt/termlink/crates/termlink-hub/src/{template_cache,bypass,circuit_breaker,route_cache}.rs`
  — all 11 constants live in Rust hub code, not consumed by framework.
- `git -C /opt/termlink log --since=2026-05-01` — no commits matching
  T-1642/B1/B2/B3/routing-policy since GO; substrate focused on
  T-1438/T-1418 chat-arc + auth-healing work.
- `docs/reports/T-1666-fw-config-plumbing-routing-policy.md` —
  full three-path analysis.

### 2026-05-02T10:21:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bb2771fb
- **Timestamp:** 2026-06-02T14:58:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-02T10:21:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
