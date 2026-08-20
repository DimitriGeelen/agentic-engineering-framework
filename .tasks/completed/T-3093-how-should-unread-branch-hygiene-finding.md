---
id: T-3093
name: "How should unread branch-hygiene findings escalate?"
description: >
  Inception: How should unread branch-hygiene findings escalate?

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-08-19T23:57:54Z
last_update: 2026-08-20T00:16:24Z
date_finished: 2026-08-20T00:16:24Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-19T23:59:21Z'
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
  - ts: '2026-08-20T00:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=142,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3093: How should unread branch-hygiene findings escalate?

## Problem Statement

`lib/branch-hygiene.sh` correctly detects stranded branches and has been doing so
since it shipped. Nothing acts on what it finds.

Live evidence (2026-08-20): six `behind-threshold` findings at **1432–7177 commits**
past a threshold of **50**, one `diverged-fork`, five `merged-undeleted`, and — after
T-3092 — four `remote-unlanded` refs including one holding 204 commits. Nineteen
findings. The oldest strand forked 2026-03-01 and has sat there since.

The operator's own words on being shown this: *"this seems to be a mess. pollution."*
The rail had been reporting that mess the whole time.

Detection is not the gap. **Escalation is.** T-3092 fixed a real blind spot and, by
its own admission in its RCA, added four more lines to a section nobody reads.

Why now: T-3091 measured the cost. Fifty-odd files exist on stranded branches and
nowhere else — a whole escalation-rules subsystem, `lib/audit_emit.sh` and its tests,
thirteen research artifacts, six unread `.pickup/` messages. That is not tidiness; it
is work that was done, paid for, and lost track of.

The question this inception answers is **which escalation shape**, not whether.

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

- **IW-1: Why has nothing acted on these findings — is it that nobody sees them, or that seeing them changes nothing?**
  confidence: 3
  disposition: answered
  rationale: Nobody sees them — no consumer runs automatically. lib/branch-hygiene.sh:44 has exactly one caller (bin/fw line 3221); fw doctor is on 0 cron lines; agents/audit/audit.sh:1827 only mentions doctor in comments about other checks; agents/handover/handover.sh:393 uses fw_branch_divergence, which covers the current branch only. Evidence F1 in docs/reports/T-3093-branch-hygiene-escalation.md.

- **IW-2: Which surface should carry the escalation — cron audit (FAIL), handover nudge, auto-filed task, or a gate?**
  confidence: 3
  disposition: answered
  rationale: Audit cron, via a direct call rather than a duplicate — the doctor->audit promotion precedent is documented at agents/audit/audit.sh:1827 (T-1771/T-1942/T-1943). But sequenced AFTER recalibration; see IW-3. Artifact F2.

- **IW-3: What is the trigger condition? Every strand is too noisy; "1761 commits behind" is too late. What threshold makes the finding actionable while the fork is still reconcilable?**
  confidence: 3
  disposition: answered
  rationale: The unit is wrong, not the number: master moves ~41 commits/day so the 50-commit threshold trips in ~1.2 days, and 88% (2266/2577) of that movement is governance-only churn. Switch to days-since-last-commit, modelled on FW_STALE_ARC_DAYS (lib/config.sh:245, T-1855). Artifact F3.

- **IW-4: Does escalation risk the opposite failure — pressuring an operator into landing or deleting work that should be deliberately parked?**
  confidence: 2
  disposition: answered
  rationale: Yes — branch worktree-inception-gov-payload-mediation holds the deliberately-parked T-2505 policy artifact, not a strand to clean up. Escalation must reuse existing dismissal vocabulary rather than invent one, which is why no blocking gate is recommended. Evidence F4 in docs/reports/T-3093-branch-hygiene-escalation.md.

## Exploration Plan

Four read-only spikes, all completed — no prototypes, no source edits.

1. **Consumer map** (IW-1) — grep every caller of `fw_branch_hygiene`; check cron for `doctor`; check `audit.sh` and `handover.sh`. **Done** → F1.
2. **Precedent search** (IW-2) — look for an existing doctor→audit promotion in this codebase. **Done** → F2 (`audit.sh:1827`).
3. **Threshold calibration** (IW-3) — measure master's commit rate and the governance-vs-code split; compute time-to-threshold. **Done** → F3.
4. **Dismissal survey** (IW-4) — identify at least one deliberately-parked branch and check what vocabulary exists to express that. **Done** → F4.

Research artifact: `docs/reports/T-3093-branch-hygiene-escalation.md`.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** why the existing findings go unacted-on; which surface should carry escalation;
what trigger condition makes the signal true; whether escalation carries its own risk.

**OUT:** implementing any of it — this is exploration. Also out: the salvage/cherry-pick
decision for the stranded work itself (T-3091, awaiting the operator), and re-litigating
the `remote-unlanded` class (T-3092, shipped).

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
- The reason nothing acts on the findings is identified with evidence, not inferred
- A surface exists that runs without being asked, with precedent in this codebase
- The trigger condition can be stated in a unit that distinguishes a strand from work in progress
- The first slice is bounded, testable and reversible

**NO-GO if:**
- The signal cannot be made true — i.e. no trigger separates strands from healthy branches
- Escalation would require a new dismissal mechanism rather than reusing existing vocabulary
- The only workable answer is a blocking gate (too costly to walk back on a noisy signal)

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

**Recommendation:** GO — but on recalibration first, not on the obvious slice.

**Rationale:**

The filing-time rationale said "the detection rail works; nothing consumes it". The
first half turned out to be wrong, and that inverts the plan.

Nothing consumes it — confirmed. `fw_branch_hygiene` has exactly one caller
(`bin/fw:3221`), `fw doctor` appears on **zero** cron lines, and neither `audit.sh`
nor `handover.sh` calls it. The rail shipped 2026-07-04; the oldest strand forked
2026-03-01. It has never had an automatic surface.

But the signal is also not yet true. `origin/master` moves at **~41 commits/day**, so
the 50-commit threshold is crossed in **~1.2 days** — every healthy in-progress branch
is a "finding" by the next morning. And **88%** of that movement (2266 of 2577 commits
since 2026-06-01) touches nothing outside `.context/` and `.tasks/`: the counter
deciding whether your branch is stale is driven almost entirely by handovers.

So "put it on the cron" — the slice I expected to recommend — would flood the daily
audit with false positives and burn the signal for good. The unit has to be fixed
first: days-since-last-commit, following `FW_STALE_ARC_DAYS` (T-1855), which is the
same problem already solved elsewhere in this framework. All four real strands sat
untouched for weeks to months, so a time-based rule catches every one while staying
silent on a branch you committed to this morning.

Sequence: **(1) recalibrate to time → (2) promote to the audit cron via a direct call,
following the documented doctor→audit precedent → (3) only then consider a handover
nudge.** No blocking gate, no auto-filed tasks: both act on a signal whose
false-positive rate has not been fixed yet, and both are hard to walk back.

**Evidence:**
- `fw_branch_hygiene` callers: `bin/fw:3221` only; `audit.sh`'s 5 textual matches are comments about *other* checks; `handover.sh` uses `fw_branch_divergence` (current branch only)
- `fw doctor` on cron: **0** lines in `/etc/cron.d/agentic-audit-999-agentic-engineering-framework`
- Rail added 2026-07-04 (`f61e9f9d8`); oldest strand fork 2026-03-01 — strands predate the detector
- master velocity: 2577 commits / 63 active days ≈ 41/day → 50-commit threshold reached in ~1.2 days
- governance-only share: 2266/2577 = **88%**
- time-based precedent: `FW_STALE_ARC_DAYS` default 30, `lib/config.sh:245` (T-1855)
- promotion precedent: `agents/audit/audit.sh:1827` "Mirrors `bin/fw doctor` cron-drift logic" (T-1771, T-1942, T-1943)
- parked-not-stranded case: `worktree-inception-gov-payload-mediation` (T-2505 policy artifact) — why no gate is recommended

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

**Rationale**: The filing-time rationale said "the detection rail works; nothing consumes it". The
first half turned out to be wrong, and that inverts the plan.

Nothing consumes it — confirmed. `fw_branch_hygiene` has exactly one caller
(`bin/fw:3221`), `fw doctor` appears on **zero** cron lines, and neither `audit.sh`
nor `handover.sh` calls it. The rail shipped 2026-07-04; the oldest strand forked
2026-03-01. It has never had an automatic surface.

But the signal is also not yet true. `origin/master` moves at **~41 commits/day**, so
the 50-commit threshold is crossed in **~1.2 days** — every healthy in-progress branch
is a "finding" by the next morning. And **88%** of that movement (2266 of 2577 commits
since 2026-06-01) touches nothing outside `.context/` and `.tasks/`: the counter
deciding whether your branch is stale is driven almost entirely by handovers.

So "put it on the cron" — the slice I expected to recommend — would flood the daily
audit with false positives and burn the signal for good. The unit has to be fixed
first: days-since-last-commit, following `FW_STALE_ARC_DAYS` (T-1855), which is the
same problem already solved elsewhere in this framework. All four real strands sat
untouched for weeks to months, so a time-based rule catches every one while staying
silent on a branch you committed to this morning.

Sequence: **(1) recalibrate to time → (2) promote to the audit cron via a direct call,
following the documented doctor→audit precedent → (3) only then consider a handover
nudge.** No blocking gate, no auto-filed tasks: both act on a signal whose
false-positive rate has not been fixed yet, and both are hard to walk back.

**Date**: 2026-08-20T00:16:23Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-19T23:59:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fb503eb2
- **Timestamp:** 2026-08-20T00:16:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
## Recommendation Verdict (v1.0)

- **Scan ID:** RC-977c474c
- **Timestamp:** 2026-08-20T00:16:25Z
- **Overall:** CONFIRMED
- **Claims:** 7

| Claim | Type | Status |
|-------|------|--------|
| `lib/config.sh:245` | file_line | ✓ pass |
| `agents/audit/audit.sh:1827` | file_line | ✓ pass |
| `T-1855` | task | ✓ pass |
| `T-1771` | task | ✓ pass |
| `T-1942` | task | ✓ pass |
| `T-1943` | task | ✓ pass |
| `T-2505` | task | ✓ pass |
### 2026-08-20T00:16:23Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The filing-time rationale said "the detection rail works; nothing consumes it". The
first half turned out to be wrong, and that inverts the plan.

Nothing consumes it — confirmed. `fw_branch_hygiene` has exactly one caller
(`bin/fw:3221`), `fw doctor` appears on **zero** cron lines, and neither `audit.sh`
nor `handover.sh` calls it. The rail shipped 2026-07-04; the oldest strand forked
2026-03-01. It has never had an automatic surface.

But the signal is also not yet true. `origin/master` moves at **~41 commits/day**, so
the 50-commit threshold is crossed in **~1.2 days** — every healthy in-progress branch
is a "finding" by the next morning. And **88%** of that movement (2266 of 2577 commits
since 2026-06-01) touches nothing outside `.context/` and `.tasks/`: the counter
deciding whether your branch is stale is driven almost entirely by handovers.

So "put it on the cron" — the slice I expected to recommend — would flood the daily
audit with false positives and burn the signal for good. The unit has to be fixed
first: days-since-last-commit, following `FW_STALE_ARC_DAYS` (T-1855), which is the
same problem already solved elsewhere in this framework. All four real strands sat
untouched for weeks to months, so a time-based rule catches every one while staying
silent on a branch you committed to this morning.

Sequence: **(1) recalibrate to time → (2) promote to the audit cron via a direct call,
following the documented doctor→audit precedent → (3) only then consider a handover
nudge.** No blocking gate, no auto-filed tasks: both act on a signal whose
false-positive rate has not been fixed yet, and both are hard to walk back.

### 2026-08-20T00:16:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
