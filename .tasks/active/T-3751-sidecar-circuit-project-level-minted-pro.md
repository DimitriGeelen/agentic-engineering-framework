---
id: T-3751
name: "Sidecar circuit project level: minted project_id instead of the folder name
  (010-termlink T-3325 request)"
description: >
  Inception: Sidecar circuit project level: minted project_id instead of the folder
  name (010-termlink T-3325 request)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-02T22:57:45Z
last_update: 2026-10-02T23:29:58Z
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
  - ts: '2026-10-02T22:59:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-10-02T23:00:30Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=136,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3751: Sidecar circuit project level: minted project_id instead of the folder name (010-termlink T-3325 request)

## Problem Statement

The sidecar's five-level circuit (host / hub / project / session / agent, D-660, lib/aef_address.py) puts the project's folder basename at the project level (`lib/sidecar/circuit.py:136 project_id()`), and every inbox topic name (`inbox:<hub>/<project>`) inherits it. Folder names change on rename, collide across hosts, and differ between instances of one project; the minted id (T-3534, `pid-<16 hex>`, back-filled by `fw upgrade` since T-3750) has none of those faults. 010-termlink is about to make its notify sidecar wake an agent only when `to_circuit` matches its own circuit (their T-3325), so every address written before this is settled must be migrated later. Their operator asked for it as a priority (sidecar @129, 2026-10-02).

## Assumptions

- Every peer that sends to us can learn our minted id (via `fw whoami` or a published directory) before the folder-name topics are retired.
- Dual-reading old and new inbox topics during the migration costs one extra `channel subscribe` per poll (the same shape `v9_topics` / `legacy_topics` already use).

## Open Questions

- **IW-1: Where exactly does the minted id appear in both grammars?** Path form (`//host/hub/<project>/session/agent`, sent today as `from_circuit`) and the V9 form (`aef::host=…::hub=…::project=…::session=…::@agent::`). Does `project=` carry the id alone, or id plus display name?
  confidence: 3
  disposition: answered
  rationale: operator ruling 2026-10-03 (decision brief, option C) — the minted id (pid-…) in the project slot of BOTH forms (path //host/hub/pid-…/…, V9 project=pid-…); the readable name is display-only via display_format() and never on the wire; reverses T-3287 D2 (root path) for the project slot; see docs/reports/T-3751-project-id-circuit.md

- **IW-2: How do inbox topics migrate without losing messages?** New topic `inbox:<hub>/<pid>`, with the receiver dual-reading the folder-name topic until no peer has written to it for N days?
  confidence: 1

- **IW-3: How does `--to <name>` resolve to an id?** Human-readable names stay the operator's way to address a peer, so a name→id directory (hub kv, or each peer's published whoami) is needed. Which, and who owns it (Gap Homing: TermLink or us)?
  confidence: 1

- **IW-4: Is the fallback ladder exactly as 010 states it?** Deliver to the deepest level that resolves, falling back towards level 1 (host) when the full address is not found. Confirm, or name the exceptions (for example: never fall back across projects).
  confidence: 2

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

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

The minted id exists (T-3534, pid-16hex, back-filled by fw upgrade since T-3750) but circuit.project_id() still returns the root basename, so the circuit project level and every inbox topic name (inbox:hub/project) are folder names that collide across hosts and change on rename. TermLink is about to key wake-up on to_circuit (their T-3325) and asked us to settle it before they build. Open: topic migration (dual-read old and new topics, as v9_topics/legacy_topics already do), the name-to-id alias for --to, and the fallback ladder confirmed with TermLink.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-03 — IW-1: what goes in the project slot (operator ruling)
- **Chose:** C — minted project_id (`pid-…`) in the project slot of both the path form and the V9 form; the readable project name is display-only (`display_format()`), never on the wire.
- **Why:** the address must survive a folder rename/move and not collide across hosts, and stay readable for people; C is the only option with both (score +35 vs B +25, D −7, A −25).
- **Rejected:** A keep path/basename (breaks on rename, the two forms already disagree); B id only (unreadable logs and inboxes); D defer (TermLink builds on folder names meanwhile).
- **Left open:** name→id resolution (IW-3), topic migration (IW-2), fallback ladder (IW-4); two checkouts of one project on one host share an id — session level separates them (raise in IW-4). Reverses T-3287 D2 for the project slot only.

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-02T22:59:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
