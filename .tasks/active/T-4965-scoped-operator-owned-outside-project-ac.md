---
id: T-4965
name: "Scoped, operator-owned outside-project access grants (read / create / create-project)
  — 050 Pen T-2500 ask"
description: >
  Inception: Scoped, operator-owned outside-project access grants (read / create /
  create-project) — 050 Pen T-2500 ask

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-11-01T13:34:31Z
last_update: 2026-11-01T17:14:16Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-11-01T13:45:16Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=120,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-11-01T13:45:29Z'
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
---

# T-4965: Scoped, operator-owned outside-project access grants (read / create / create-project) — 050 Pen T-2500 ask

## Problem Statement

050-email-archive's agent needs standing, per-directory access to a NAS share outside its project: read, create (modify only its own) and create-project, with every delete approved by the operator. Today the boundary hook offers only a whole-path read exemption (`BOUNDARY_EXTRA_READ_PATHS`). The question is how much of the rest the framework can enforce honestly, given that hooks see only typed commands and that the agent runs as root on the same host as the operator's admin mount.

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

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

- **IW-1: Can the boundary hook enforce per-directory read / create / create-project grants, from an operator-owned grant file, without widening anything a grant does not name?**
  confidence: 3
  disposition: answered-pending-review
  rationale: design read done 2026-11-01 (report §Design read). Yes for typed actions, with one new piece: lib/shell_write_scan.py must classify each target as create/modify/rename/delete/metadata (today it only finds targets). Probe: rm/mv/cp on an extra read path are already refused. Scope limit stays: scripts are fenced only by the NAS accounts, never by the hook.
- **IW-2: How does level 2 ("modify only what the agent created") work when the filesystem cannot tell who created a file?**
  confidence: 3
  disposition: answered-pending-review
  rationale: 050's model change moves "own" to the NAS (pen-create, CREATOR OWNER), which holds against scripts. The framework ledger (pending in PreToolUse, confirmed in PostToolUse, renames move the entry) remains the audit aid, the source for temp items and the scope of deletes; a missing entry means the operator's file (report §Design draft 3).
- **IW-3: Can a delete credential be kept from an agent that runs as root on the same host?**
  confidence: 3
  disposition: answered-pending-review
  rationale: No, not by anything local (same residual as T-3581). Real separation needs an off-host executor (Ring20 Manager or NAS-side) that holds pen-delete and confirms the operator's approval itself; a local runtime only adds visibility. Report §Design draft 4c; operator's choice, asked of 050.

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

**Recommendation:** GO for a reduced framework layer; NO-GO for any framework-side delete or temp authority

**Update (050's operator, msg 34998006):** their side has adopted exactly this split. The NAS (`pen-create`, phone notice per delete or rename, btrfs snapshots) is the authority for ownership and deletes; there is no Tier 0 delete flow and no temp rule. What AEF builds:
1. an operator-owned grant file mapping each path to its read or create mount; on create mounts, typed create, modify, rename and delete are allowed, and the NAS judges ownership;
2. `never_write` for the admin mount;
3. refusal of opaque forms;
4. doctor and Watchtower visibility.

That is about three slices, with no ledger and no executor.

**Rationale (2026-11-01, after the design read and two independent reviews):** the framework can honestly fence *typed* commands under an operator-owned grant file. That covers the read and create levels, steering to the profile mounts, refusal of opaque forms (variables, links, archive extractors, recursive copies, replacing moves), and visibility. It cannot be the authority for deletes, temporary items or "created by the agent". The agent runs as root on 050's host, so every local record (ledger, approval, credential) can be forged or watched. Both reviewers found ways to steer a delete from a forged ledger row (opencode: sound with fixes; codex: unsound as drafted). That authority must live off the host: the NAS's own ownership plus an executor owned by Ring20 Manager, which checks approval, ownership and object identity itself. Real protection of operator files also needs the agent kept off the admin mount, which is 050's host decision. Report: `docs/reports/T-4965-scoped-access-grants.md` (§Design draft, §Review seat 1, §Review seat 2).

*Filing-time rationale (kept for the record):* Requested by 050-email-archive (msg d7a70b98, Pen T-2500, priority not urgent): standing per-directory grants for one agent to paths outside its project (read; create + modify only what it created, via a created-by-agent ledger; create-project; deletes never standing, always Tier 0), operator-owned grant file the agent cannot edit, audit log of every outside write, grants shown in fw doctor and Watchtower. Today check-project-boundary.sh offers only BOUNDARY_EXTRA_READ_PATHS. This widens the project boundary, so the requester and the framework both want a co-designed spec and an independent external review before any build. Evidence for GO/NO-GO does not exist yet: no design read against the boundary hook, the Tier 1 write scanner and the Tier 0 grammar has been done. Next: design doc, external review, then GO/NO-GO.

**Evidence:**

- Hook probe (scratch project, 2026-11-01): rm/mv/cp on a `BOUNDARY_EXTRA_READ_PATHS` path are refused today; `lib/shell_write_scan.py` finds write targets but not their kind (create/modify/rename/delete).
- Reviews: `docs/reports/T-4965-review-opencode.md` (sound with fixes), `docs/reports/T-4965-review-codex.md` (unsound as drafted); all findings answered in the report.
- A present defect found on the way: a write through a shell variable passes the boundary hook (G-126, T-4983).
- Open for 050's operator: who runs the executor (Ring20 Manager?), keeping the agent off the admin mount, and whether chmod/touch on own files is needed.

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

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-01T14:40:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
