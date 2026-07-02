---
id: T-2471
name: "Watchtower triple-file liveness gap — cached URL emitted when process dead
  (port reused by unrelated service)"
description: >
  Inception: Watchtower triple-file liveness gap — cached URL emitted when process
  dead (port reused by unrelated service)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-02T19:16:39Z
last_update: 2026-07-02T19:18:00Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-07-02T19:18:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F-AUTONOMY: 2
      audit_severity: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F-AUTONOMY=2 
      (no-signal); audit_severity=2 (no-signal); F3=2 (no-signal); F1=2 
      (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2471: Watchtower triple-file liveness gap — cached URL emitted when process dead (port reused by unrelated service)

## Problem Statement

**Symptom:** User requests Watchtower link, agent emits `http://192.168.10.107:3000` from triple-file cache, but URL does NOT respond. User frustration: "check fricing port".

**Root Cause Analysis:**

1. **What happened:**
   - Watchtower process PID 1285653 died/crashed (no longer in `ps aux`)
   - Triple files (`.context/working/watchtower.{pid,port,url}`) NOT cleaned up
   - Port 3000 got reused by different Python process (PID 982089, unrelated service)
   - Framework reads stale triple file, emits cached URL without health check

2. **Why structurally allowed:**
   - No liveness validation between triple-file read and URL emission
   - No PID validation (`/proc/$PID` existence + process name match)
   - No auto-cleanup of stale triple files when Watchtower dies
   - `fw watchtower url/status` trusts PID file blindly
   - Port reuse by unrelated service is silent failure mode

3. **Impact:**
   - User gets wrong URL to different service (confusing 404s or wrong content)
   - Lost time debugging "why isn't Watchtower responding"
   - Trust erosion: framework gives wrong information

**Structural Gap:** Triple-file system is write-once cache with no staleness detection. Origin: L-328 established triple-file as source-of-truth for runtime metadata but didn't spec liveness guarantees.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Is PID validation sufficient or do we need health check?**
  confidence: 2 (high - both are cheap, layered defense is better)
  disposition: answered
  rationale: Recommend both - PID check catches dead process, health check catches wrong service on port

- **IW-2: Should auto-cleanup run on Watchtower start or on fw watchtower url call?**
  confidence: 2 (high - start-time is cleaner)
  disposition: answered  
  rationale: Start-time cleanup is single choke-point, url-call would need to handle cleanup failures

- **IW-3: How often do users hit this in practice?**
  confidence: 1 (low - need handover corpus grep)
  disposition: deferred
  rationale: Not blocking for GO decision - fix is cheap regardless of frequency

## Exploration Plan

1. **Reproduce (5 min):** Kill Watchtower, verify triple files stay, port gets reused
2. **Survey consumers (10 min):** How often do users hit this? Check handover corpus for "watchtower not responding"
3. **Design candidates (15 min):**
   - **A:** Add health check to `fw watchtower url` (curl -sf before emit)
   - **B:** PID validation in `fw watchtower status` (check `/proc/$PID/cmdline`)
   - **C:** Auto-cleanup stale triple files on Watchtower start
   - **D:** Background liveness monitor (overkill for this scope)
4. **Prototype winner (20 min):** Implement health-check wrapper in `lib/watchtower.sh`
5. **Test (10 min):** Kill Watchtower, verify new behavior surfaces "not running" instead of stale URL

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN scope:**
- Liveness detection for `fw watchtower url/status` commands
- PID validation before emitting cached URL
- Stale triple-file cleanup strategy
- Health check (curl -sf) before URL emission
- Prevention: detect when Watchtower process dies

**OUT of scope:**
- Watchtower process monitoring/restart (arc-012 continuous-mode handles that)
- systemd integration (T-1309 deferred)
- Cross-project triple-file coordination
- Generic triple-file liveness for other services

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

High-value structural remediation. Root cause: no liveness check between triple-file cache read and URL emission. Evidence: PID 1285653 dead, port 3000 reused by PID 982089 (different service), framework emitted stale URL http://192.168.10.107:3000. Structural fix: add health check (curl -sf + PID validation) before URL emission + auto-cleanup stale triple files + fw watchtower status should detect mismatch. Prevents user confusion when Watchtower crashes and port gets reused.

**Evidence:**

- PID file: `/opt/999-Agentic-Engineering-Framework/.context/working/watchtower.pid` → `1285653`
- Process check: `ps aux | grep 1285653` → no output (dead process)
- Port check: `ss -tlnp | grep :3000` → `pid=982089` (different Python process)
- User impact: S-2026-0702-2013 session, user requested "wtahctower link please", got stale URL
- Related: L-328 (triple-file source-of-truth), no liveness spec

**Candidates:**

- **A (Recommended):** Health check in `fw watchtower url` — curl -sf before emit, fallback to "not running" message
- **B:** PID validation — check `/proc/$PID/cmdline` contains "watchtower" before trusting triple file
- **C:** Auto-cleanup — `bin/watchtower.sh` start clears stale triple files from prior crashed instance
- **All three:** Layered defense (cheap to implement, high reliability)

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

### 2026-07-02T19:18:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
