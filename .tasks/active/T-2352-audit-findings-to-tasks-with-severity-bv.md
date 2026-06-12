---
id: T-2352
name: "audit-findings-to-tasks-with-severity-bvp-boost"
description: >
  Inception: audit-findings-to-tasks-with-severity-bvp-boost

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-12T11:49:03Z
last_update: 2026-06-12T11:51:42Z
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
  - ts: '2026-06-12T11:51:42Z'
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

# T-2352: audit-findings-to-tasks-with-severity-bvp-boost

## Problem Statement

Audit findings (WARN/FAIL) emitted by `bin/fw audit` have no structural carrier into the task system. They print to stderr, get silently re-emitted by `full-daily` / `structural-30m` / `traceability-hourly` / `oe-*` crons, and pile up unaddressed. The framework's keystone *"nothing gets done without a task"* doesn't apply to its own audit output.

For whom: agent + operator (both lose track of which findings are old, which are new, which are addressed). Why now: operator surfaced the gap post-/resume after seeing multiple cron-driven audit channels but zero task representation, and explicitly tied it to BVP drain-pressure (FAIL=1.0, WARN=0.75 normalized boost).

## Assumptions

- A1: `bin/fw audit` emits WARN/FAIL lines in a parse-stable format (verify in spike — current format is `WARN/FAIL:` prefixed lines).
- A2: A sha1 of normalized finding text is stable across audit runs (verify — section context might shift wording).
- A3: `workflow_type: bugfix` + existing T-1550 RCA gate is sufficient classification machinery; no new workflow class needed.
- A4: BVP estimator can absorb a new `score_audit_severity` handler without disturbing existing V_* / F-* handlers (sibling-of-T-2329 pattern).
- A5: Volume on a "bad audit day" is bounded (<50 findings) — if not, S3 digest mode is mandatory not optional.

## Open Questions

- **IW-1: One task per finding, or one per class/section?**
  confidence: 2
  disposition: answered
  rationale: Per finding-text — dedupe handles re-emit (IW-2). Section-level would lose granularity needed for RCA-per-finding. Direction confirmed in dialogue 2026-06-12.

- **IW-2: Dedupe key — finding-text hash, or finding-id from audit emit?**
  confidence: 2
  disposition: answered
  rationale: sha1 of normalized finding text, stored as `audit_finding_hash:` frontmatter. Validates in S1 spike against re-emit; if section context drift causes false-negatives, fall back to section+normalized-text. See artifact §5.

- **IW-3: Trigger surface — `audit.sh` post-emit, hourly cron, or pre-push hook?**
  confidence: 2
  disposition: answered
  rationale: `audit.sh` post-emit — same script that prints WARN/FAIL writes the tasks. Lowest latency, idempotent via IW-2 dedupe, no new cron entry.

- **IW-4: BVP boost carrier — `bvp_scores_proposed[]`, new `audit_severity:` frontmatter, or composite formula?**
  confidence: 2
  disposition: answered
  rationale: New `audit_severity: fail|warn` frontmatter + estimator handler `score_audit_severity` mapping to 1.0 / 0.75. Mirrors T-2329 F-AUTONOMY handler pattern. Avoids polluting bvp_scores_proposed[] which is for confidence-aware proposals.

- **IW-5: Which existing carrier does this layer on — OBS, concerns register, or new direct path?**
  confidence: 3
  disposition: answered
  rationale: Direct audit → task with workflow_type=bugfix. Operator reframe 2026-06-12 (*"this are audit finding not per se structural, that why task with RCA is needed"*) ruled out OBS (substantive triage hop wasted) and concerns register (pre-judges structural classification that RCA exists to determine). See artifact §3.

- **IW-6: Auto-close when finding stops emitting?**
  confidence: 2
  disposition: answered
  rationale: No. RCA conclusion + Verification command (re-run audit, finding absent) is the close gate. Matches existing bugfix flow. Auto-close would skip the RCA classification work which is the entire reason for the task.

- **IW-7: workflow_type — bugfix, refactor, or new class?**
  confidence: 3
  disposition: answered
  rationale: bugfix. T-1550 RCA gate fires for free; G-019 root-cause escalation already applies. Refactor has no RCA gate; new class is unjustified infra. See artifact §4.

- **IW-8: Volume safety — what if audit emits 50 FAILs on a bad day?**
  confidence: 1
  disposition: deferred
  rationale: Genuine evidence gap. Answer requires S1 dry-run data on actual audit emission count. If >N (TBD threshold), S3 digest mode (single approval task fanning out on operator GO) is required not optional. Calibration after S1 lands.

## Exploration Plan

- **Spike A (≤30 min)** — parse stability: run `bin/fw audit 2>&1`, grep `^(WARN|FAIL):` lines, sample 10, verify regex coverage + normalized-text stability across two consecutive runs. Output: dedupe-key viability.
- **Spike B (≤45 min)** — volume reality: count WARN/FAIL across last 7 days of cron-audit log artifacts (`.context/audits/2026-06-*.yaml`). Histogram of per-run counts. Output: IW-8 threshold calibration (or "always batch" if median >5).
- **Spike C (≤30 min)** — BVP estimator: dry-run patched estimator on 10 existing tasks plus 2 synthetic audit-finding tasks with `audit_severity: fail`/`warn`. Verify boost surfaces them above routine backlog. Output: IW-4 carrier validated.
- **Decision point** — after Spikes A/B/C, decide if S3 (digest mode) ships in v1 or as follow-on.

## Technical Constraints

- `audit.sh` is shell; can shell out to `bin/fw task create` for emission. Avoid Python rewrite for v1.
- Dedupe lookup must scan both `.tasks/active/` AND `.tasks/completed/` — a finding fixed-and-completed shouldn't re-file. ~2300 files total, grep by `audit_finding_hash:` is fast enough.
- Audit runs from multiple cron entries with different working directories — emit hook must use `PROJECT_ROOT` not `pwd`.
- Bugfix-class workflow_type triggers RCA gate at close, NOT at create — emission can proceed without populated RCA.

## Scope Fence

**IN scope:**
- Post-`audit.sh` emit hook (S1)
- BVP severity handler + `audit_severity` frontmatter (S2)
- Dedupe by finding-hash (S1)
- Volume-safety digest mode (S3, conditional on Spike B)
- Reuse of T-1550/G-019/G-066 gates

**OUT of scope:**
- Audit detection logic (existing checks unchanged)
- Cross-project audit findings (TermLink consumer audits)
- OBS inbox restructure (keeps its `fw note` triage role)
- Concerns register restructure (G-XXX stays as post-RCA structural carrier)
- Replacing existing audit crons (this layers on top)
- Watchtower batch-triage UI (follow-on if S3 calibration shows operator pain)

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

Audit WARN/FAIL findings have no structural carrier into the task system today; they re-emit silently across daily/30m/hourly audit crons and pile up unaddressed. Direction: post-audit hook creates one bugfix-class task per finding (workflow_type=bugfix gets T-1550 RCA gate for free; G-019 root-cause escalation enforces structural-or-not classification at close), dedupe by sha1 of normalized finding text, BVP boost via audit_severity:fail|warn carrier (FAIL=1.0 normalized, WARN=0.75) so they out-rank routine backlog and drain. Reuses two existing gates with no new RCA infrastructure. Only genuine evidence gap is IW-8 volume safety (50-finding fan-out on a bad audit day) — first dry-run answers it.

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

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-12T11:51:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
