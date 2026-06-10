---
id: T-2204
name: "Recommendation-completeness gate has bypass paths — fw task create, fw work-on,
  direct YAML, and review-batch emission all bypass T-1716"
description: >
  Inception: Recommendation-completeness gate has bypass paths — fw task create, fw
  work-on, direct YAML, and review-batch emission all bypass T-1716

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-06-04T09:00:06Z
last_update: 2026-06-08T07:44:40Z
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
  - ts: '2026-06-04T09:02:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-04T09:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2204: Recommendation-completeness gate has bypass paths — fw task create, fw work-on, direct YAML, and review-batch emission all bypass T-1716

## Problem Statement

T-1715/T-1716 shipped a filing-time `--recommendation`+`--rationale` gate on `fw inception start` under `$CLAUDECODE=1`. The gate works on that one path. **It does not fire on any other path that creates a task with `workflow_type: inception`** — `fw task create --type inception`, `fw work-on --type inception`, direct YAML write, or post-hoc `fw task update T-XXX` that flips `workflow_type`. **The downstream handoff verbs `fw task review` / `fw task review-batch` also have no Recommendation-completeness pre-check** — they emit class-correct `/inception/<id>` URLs regardless of whether the body is filled.

This-session repro (third recurrence of the T-679 rule):
- T-2201 (pre-flight Claude CLI config inception) — filed via task-create, `## Recommendation` block = template comment only.
- T-2203 (structural-observation harvester inception) — same.
- Agent ran `fw task review-batch T-2201 T-2203`, posted `/inception/T-2201` and `/inception/T-2203` to operator chat as "awaiting decision" handoffs. Operator opened both, saw blank Recommendation blocks, pushed back.

**For whom:** every agent under `$CLAUDECODE=1` filing inceptions on any path other than `fw inception start`, and every operator who opens a `/inception/<id>` link the agent handed off.

**Why now:** two same-session repro cases; user explicitly named the pattern as "getting lost"; full L-399 (producer/consumer parity for hook bypass contracts) discipline already established but not applied here. Research artifact: `docs/reports/T-2204-recommendation-completeness-bypass-paths.md`.

## Assumptions

- **A1:** T-1716's check shape (require `--recommendation`+`--rationale` under `$CLAUDECODE=1`) is the right shape for the other producer paths. Test: read `lib/inception.sh:107-120`, confirm the check is portable.
- **A2:** A PreToolUse Write/Edit hook on `.tasks/active/T-*.md` can parse YAML frontmatter + grep the `## Recommendation` body in <100ms without measurably slowing edit cadence. Test: time the existing `check-inception-decisions` hook (same path shape) on a real session.
- **A3:** `fw inception retrofit-recommendations --apply` (T-1716 Stream C) is safe to fire on a cron schedule — it injects DEFER stubs only when block is template-only AND no `Recommendation:` line exists. Test: read `lib/inception.sh:902-980`; dry-run `fw inception retrofit-recommendations` against current active/ set.
- **A4:** Operator preference is "refuse emission" over "annotate emission" when `fw task review-batch` hits an empty Recommendation. Evidence: 2026-06-04 pushback ("again surface without recommendation") was unambiguously about refusing the handoff, not just labelling it.

## Open Questions

- **IW-1: Single producer fix (B), single consumer fix (C), pair (B+C), or full hybrid (E = B+C+D cron)?**
  confidence: 4
  disposition: answered — Candidate E (full hybrid: B + B' + C + D). B (T-2205 Write/Edit hook), B' (T-2207 create-task.sh CLI parity), C (T-2206 emit_review/batch consumer), D (T-2208 hourly cron). All four legs shipped 2026-06-04 → 2026-06-05. Per L-399 / T-1890 producer/consumer parity discipline: every plausible filing path closes the gate, unified env-var bypass.
  rationale: B+C alone left direct-YAML and post-hoc workflow_type-flip paths uncovered; cron backstop catches both classes plus the window before the operator wires Slice B's hook into .claude/settings.json (T-2205 operator action pending).

- **IW-2: For Candidate B (Write/Edit hook), what's the bypass mechanism per T-1890 parity rule — env var only, flag only, or both?**
  confidence: 5
  disposition: answered — env-var-only (`FW_ALLOW_EMPTY_RECOMMENDATION=1`) for the Write/Edit hook surface; flag (`--recommendation` / `--rationale` / `--i-am-human`) for CLI surfaces (`do_inception_start`, `create-task.sh`). T-1890 satisfied — bypass-contract symmetric across internal + external producer patterns.
  rationale: Write tool has no flag surface so env-var is mandatory for Slice B (T-2205); CLI surfaces use both — flag for human terminal sessions, env for agent override (T-1716, T-2207). All agent-initiated bypasses log Tier-2 to `.context/working/.gate-bypass-log.yaml`. `FW_INCEPTION_PRE_GATED=1` trusted-caller signal stays silent (internal routing, not override).

- **IW-3: Does `fw task update T-XXX` that flips `workflow_type` to `inception` post-hoc count as a filing event — should it trigger the same Recommendation-completeness check at the moment of the flip?**
  confidence: 3
  disposition: deferred — covered indirectly by Slice D (T-2208) cron backstop rather than a synchronous gate on the flip itself. Hourly retrofit-recommendations sweep injects DEFER stub within ≤60 min of any post-hoc flip that leaves an empty Recommendation block. Synchronous gate revisitable as Slice E if production data shows post-hoc flips are common.
  rationale: A synchronous gate on `fw task update --type inception` would have UX cost — the flip is itself often mid-exploration, no Recommendation can yet be sound. Cron backstop accepts up-to-60min eventual consistency in exchange for not blocking the flip; if production data shows post-hoc flips are common, a synchronous gate can be added later as Slice E.

- **IW-4: Should `fw task review-batch` refuse emission entirely, or emit with a `[NO-REC]` annotation (T-1576 already wires this verb in handover output)?**
  confidence: 5
  disposition: answered — refuse emission entirely (Slice C / T-2206 emit_review_batch BLOCK). T-1576's `[NO-REC]` survey-annotation stays for *describing what exists*; the handoff verb is where the agent *commits* to advisory — different semantics, different surfaces.
  rationale: Per the operator's 2026-06-04 pushback ("again surface without recommendation") on T-2201/T-2203 inception handoffs, the BLOCK semantic was the unambiguous read — T-2206 shipped the consumer leg of the answer. `[NO-REC]` (T-1576) continues to appear in handover queue listings and `fw review-queue` output where the agent is surveying state, not handing off.

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

T-1715/T-1716 closed fw-inception-start filing path under $CLAUDECODE=1. T-2201 + T-2203 are this-session repro: both filed via fw task create + fw work-on (workflow_type: inception set directly), bypassed T-1716, sat with template Recommendation blocks, agent emitted /inception/<id> handoff URLs anyway. Three filing-path bypasses (task create, work-on, direct YAML) plus one consumer-side gap (fw task review/review-batch emission lacks Recommendation-completeness pre-check) remain after T-1716. Retrofit-recommendations exists but is manual-only (no cron, no hook). Bounded fix shape known (extend T-1716 contract to all producers + add review-batch emission gate). Evidence concrete, risk low — GO.

**Evidence:**

- **Slice B (T-2205) — PreToolUse Write/Edit hook** — `lib/hooks/check_inception_recommendation.py`; refuses Write/Edit on `.tasks/active/T-*.md` when frontmatter has `workflow_type: inception` AND `## Recommendation` block is empty / template-only. Operator action still pending: wire into `.claude/settings.json` (B-005 hard-blocks agent — see Updates below).
- **Slice B' (T-2207) — `create-task.sh` CLI parity** — `agents/task-create/create-task.sh` accepts `--recommendation GO|NO-GO|DEFER`, `--rationale "..."`, `--i-am-human`. Inception filings under `$CLAUDECODE=1` refused without rec+rationale. Trusted-caller signal `FW_INCEPTION_PRE_GATED=1` (silent, not logged) prevents double-gating from `do_inception_start`. 11/11 bats PASS (`tests/unit/create_task_inception_recommendation_gate.bats`).
- **Slice C (T-2206) — `emit_review` / `emit_review_batch` BLOCK consumer** — `lib/review.sh` refuses to emit handoff URL for inceptions with empty/template Recommendation; unified env-var bypass `FW_ALLOW_EMPTY_RECOMMENDATION=1` writes Tier-2 NOTE + log entry per task. 14/14 bats PASS + 4-file regression sweep clean.
- **Slice D (T-2208, shipped 2026-06-05) — hourly cron backstop** — `.context/cron-registry.yaml` entry `inception-retrofit-rec-hourly` (schedule `19 * * * *`) wraps `fw inception retrofit-recommendations --apply`. L-364 dual-clause cron sync PASS (`fw doctor` reports "Cron registry in sync"). Idempotent on clean state. 5/5 Verification commands PASS including reviewer.
- **CLAUDE.md §Recommendation-completeness gate** — table now names all 4 producer legs + consumer + cron backstop with unified bypass-env semantics per L-399 / T-1890 producer/consumer parity discipline. Commit landing alongside this Recommendation update.
- **Producer/consumer parity confirmed** — every producer surface refuses under `$CLAUDECODE=1`; all use the same `FW_ALLOW_EMPTY_RECOMMENDATION=1` env-var bypass; agent-initiated bypasses log Tier-2; trusted-caller signal silent. 4-of-4 leg map closed.

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

**Rationale**: T-1715/T-1716 closed fw-inception-start filing path under $CLAUDECODE=1. T-2201 + T-2203 are this-session repro: both filed via fw task create + fw work-on (workflow_type: inception set directly), bypassed T-1716, sat with template Recommendation blocks, agent emitted /inception/<id> handoff URLs anyway. Three filing-path bypasses (task create, work-on, direct YAML) plus one consumer-side gap (fw task review/review-batch emission lacks Recommendation-completeness pre-check) remain after T-1716. Retrofit-recommendations exists but is manual-only (no cron, no hook). Bounded fix shape known (extend T-1716 contract to all producers + add review-batch emission gate). Evidence concrete, risk low — GO.

**Date**: 2026-06-04T16:09:52Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-04T09:02:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-04T16:09:52Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** T-1715/T-1716 closed fw-inception-start filing path under $CLAUDECODE=1. T-2201 + T-2203 are this-session repro: both filed via fw task create + fw work-on (workflow_type: inception set directly), bypassed T-1716, sat with template Recommendation blocks, agent emitted /inception/<id> handoff URLs anyway. Three filing-path bypasses (task create, work-on, direct YAML) plus one consumer-side gap (fw task review/review-batch emission lacks Recommendation-completeness pre-check) remain after T-1716. Retrofit-recommendations exists but is manual-only (no cron, no hook). Bounded fix shape known (extend T-1716 contract to all producers + add review-batch emission gate). Evidence concrete, risk low — GO.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fe0f21e9
- **Timestamp:** 2026-06-05T11:52:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
