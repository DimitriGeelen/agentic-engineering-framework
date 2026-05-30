---
id: T-2123
name: "why [REVIEWER] auto-routing isn't clearing the partial-complete backlog"
description: >
  User: 148 partial-completes accumulating despite T-1811/T-1878/T-1896/T-1985 codification
  (REVIEWER/REVIEW/RUBBER-STAMP tiers, default-bias detector, auto-tick). Agent doesn't
  reflexively re-classify existing [REVIEW] ACs to [REVIEWER] at close time, and no
  daemon scans the partial-complete backlog. RCA: detector catches authoring-time
  but not retroactive; reviewer is manual-invoke. Rule: rubber-stamping = agent when
  sensible+low-risk; [REVIEW] = high-impact UX + high-risk only.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-30T20:44:48Z
last_update: '2026-05-30T20:45:03Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-30T20:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-30T20:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2123: why [REVIEWER] auto-routing isn't clearing the partial-complete backlog

## Problem Statement

User: *"i also see a lot of unclosed work-completed items, did we not agree we
would route ACs more to agents, we even have a termlink reviewer agent for
this, please incept why this is not structurally working yet (rubber-stamping
should be agent where sensible and risk acceptable correct, we said on
high-impact UX and high-risk change, ok this is all UX)."*

**Hard data captured at filing time (2026-05-30):**

| Prefix in unticked Human ACs across `.tasks/active/T-*.md` | Count |
|------------------------------------------------------------|-------|
| `[REVIEW]` (human judgment)                                | **152** |
| `[REVIEWER]` (static-scan-verifiable via `fw reviewer`)     | **0** |
| `[RUBBER-STAMP]` (mechanical → should be Agent AC)         | **4** |

**152 : 0 : 4.** The codification (T-1811 + T-1878 conversion rule + T-1896
default-bias detector + T-1985 reviewer auto-tick) is on paper; **zero**
Human ACs in flight today are tagged for the reviewer agent path. Even where
the agreement was *"default to [REVIEWER] when Expected is grep-able /
file-exists / structural"*, the prefix never appears.

The reviewer infrastructure exists and works: `lib/reviewer/static_scan.py`
runs 12+ detectors, `fw reviewer T-XXX [--dispatch]` works in TermLink
isolation (T-1951), and auto-tick (T-1985) atomically ticks `[REVIEWER]` ACs
with full sovereignty-rail consent. **The plumbing is wired, the prefix is
absent — so the plumbing carries zero traffic.**

This pairs with T-2118 (chat-side palette emission gap) and T-2122 (arc-close
recommendation gap) as the **third member** of the §ACD-class-at-the-AC-level
cluster surfaced this week.

## Assumptions

- **A1.** The conversion rule (T-1811/T-1878) exists in CLAUDE.md but the
  agent doesn't run a classifier at AC-write time — so the *author-time
  default* never fires unless the agent thinks about it deliberately.
- **A2.** T-1896 default-bias detector exists but is **advisory-only at
  close** — emits CONCERN findings, doesn't refuse the close, doesn't
  retroactively scan existing partial-completes.
- **A3.** `fw reviewer T-XXX` requires **manual invocation** — no daemon
  scans the 152 partial-completes; no PostToolUse hook runs the reviewer
  on tasks tagged `owner: human` daily.
- **A4.** Auto-tick (T-1985) only fires for ACs that ALREADY have the
  `[REVIEWER]` prefix — it cannot retroactively reclassify a [REVIEW] AC,
  so 152 [REVIEW] ACs stay [REVIEW] forever unless the agent rewrites them.
- **A5.** The user's stated agreement: *"rubber-stamping should be agent
  where sensible and risk acceptable; we said on high-impact UX and
  high-risk change"* — implies the **default** should be agent-checked,
  not human-checked, with `[REVIEW]` reserved for high-impact UX / high-risk.
  Current ratio 152:4 inverts this default.

## Exploration Plan

- **Spike 1 (data, done):** Count [REVIEW] : [REVIEWER] : [RUBBER-STAMP]
  prefixes in `.tasks/active/T-*.md`. **Done — 152 : 0 : 4.**
- **Spike 2 (data, 5min):** Of the 152 [REVIEW] ACs, how many have
  grep-able / file-exists / structural Expected clauses (i.e. would convert
  to [REVIEWER] per T-1811 rule)? Sample 20 randomly.
- **Spike 3 (mechanism, 10min):** Trace why T-1896 default-bias detector
  doesn't trip on these. Is it (a) prefix-blind by design (only scans
  `[REVIEWER]` for prose mismatches), (b) absent from the close gate, or
  (c) silently CONCERN-only?
- **Spike 4 (option synthesis):** Three structural levers below.

## Technical Constraints

- The classifier must run **at AC author time** (PreToolUse Write|Edit on
  task files) AND **retroactively** on the backlog (cron + audit). Neither
  hook exists today.
- The agent's PreToolUse gates today look at task-existence, focus, arc-id
  validity, render-surface, RCA presence — not at AC prefix routing.
- Reclassifying an AC from [REVIEW] to [REVIEWER] retroactively must pass
  the sovereignty boundary: who decides the AC is mechanically verifiable?
  The agent can propose; auto-tick only fires after PASS.

## Scope Fence

**IN.** Define the placement of the prefix-routing enforcement (PreToolUse
gate vs daily audit vs close-gate refusal), the policy for backlog
retroactive reclassification (who proposes, who confirms), and the chat-side
counterpart (`fw review-queue --reviewer-candidates`).

**OUT (for this inception — file as separate builds on GO).**
- The PreToolUse gate implementation
- The audit / cron job that scans backlog
- Migration of the 152 existing [REVIEW] ACs

**OUT (deferred).** Auto-conversion (agent flips the prefix without human
confirmation) — propose-only first; auto-flip later if propose-rate proves
out without false-positive complaints.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — 152:0:4 prefix ratio confirms agent never uses [REVIEWER] at AC author time despite T-1811/T-1878 codification.
<!-- @auto-tick-on-decide -->
- [x] Assumptions A1-A5 enumerated (one of each is testable in a 5-10min spike before build).
<!-- @auto-tick-on-decide -->
- [x] Recommendation written — see `## Recommendation` below; A+B+C combined.

### Human
- [ ] [REVIEW] Decide GO/NO-GO/DEFER on the structural enforcement approach. Optionally: pick a lever sub-set (A=author-time, B=retro backlog scan, C=close-gate refusal). Reply via Watchtower review form.
  **Steps:**
  1. Open http://192.168.10.107:3000/review/T-2123
  2. Read `## Recommendation` block (below) — three levers.
  3. Record decision via the Watchtower form.
  **Expected:** Decision recorded; sibling build task(s) created on GO.
  **If not:** Tell agent which lever is too narrow / too broad.

## Go/No-Go Criteria

**GO if:** prefix-ratio data shows the codification has not produced behavioural
change in 28+ days since T-1878 landed (CURRENT EVIDENCE: 152 [REVIEW] vs 0
[REVIEWER] — codification has produced 0% adoption).

**NO-GO if:** the 152 [REVIEW] ACs are demonstrably high-impact UX / high-risk
where human judgment is correct (a 20-AC sample audit would confirm or refute).

**DEFER if:** a broader review-queue redesign already underway supersedes this
scope (none known).

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

**Recommendation:** GO on combined **A + B + C** (three levers, one direction).

**Rationale:**

The codification exists (T-1811 + T-1878 + T-1896 + T-1985), and the
reviewer infrastructure works (`fw reviewer T-XXX [--dispatch]`). What's
missing is the **enforcement loop** that connects them. Three levers, each
addressing a different temporal phase:

### Lever A — Author-time prefix routing gate
**PreToolUse hook on Write|Edit to `.tasks/active/T-*.md`:** when the diff
adds a `### Human` AC with `[REVIEW]` prefix AND the Expected clause matches
deterministic-test signals (grep-able / file-exists / structural), refuse
the write with a one-line block message: *"Expected clause looks
deterministic — use [REVIEWER] prefix and add `fw reviewer T-XXX` to ##
Verification, or override with FW_ALLOW_REVIEW_PREFIX=1 if human taste
genuinely required."* Same shape as `check-render-surface.sh`. Catches the
default-bias **at the moment of authoring** — closes the upstream gap.

### Lever B — Backlog reclassification audit
**Daily cron / `fw audit` check:** scan partial-complete tasks for [REVIEW]
ACs whose Expected clauses are reviewer-eligible, propose reclassification
via observation. The agent (or the human via Watchtower) can accept or
reject per AC. Closes the 152-deep backlog without batch-overwriting taste
decisions. Output: WARN in `fw audit` + observation entries in
`.context/inbox.yaml`.

### Lever C — Close-gate refusal (escalation of T-1896 to BLOCK)
**`update-task.sh` close gate:** when render-surface or [REVIEW] AC fires,
also run T-1896's prose-mismatch detector. If a [REVIEWER] candidate is
found (Expected is grep-able + AC text contains no taste vocabulary from
L-409 list), refuse close with the same conversion-block message. Same
escalation pattern as G-019 (CONCERN → BLOCK once the data shows the warning
isn't acted on).

**Combined effect:** Lever A stops new [REVIEW]-by-default ACs at write
time. Lever B works through the 152-deep backlog one observation at a time.
Lever C catches the cases that slip past A (e.g. agent overrides) before
they ship as partial-completes.

**Why all three, not one:**

- A alone closes the future-tap but leaves the backlog of 152 untouched.
- B alone is slow and depends on the agent / human triaging observations
  daily.
- C alone is too late (work is already done, just blocked from closing).
- Together they form a closed feedback loop the user explicitly named:
  *"rubber-stamping should be agent where sensible and risk acceptable …
  on high-impact UX and high-risk change [it stays human]."*

**Evidence:**

- 152 : 0 : 4 [REVIEW] : [REVIEWER] : [RUBBER-STAMP] in partial-completes
  (commands: `grep -lE "^- \[ \] \[REVIEW\]" .tasks/active/T-*.md | wc -l`
  and parallels).
- T-1878 (≈21d old) showed 412:7 ratio at the time, 13% mis-classification.
  Today's data: **rate has worsened** to 152:0 (denominator different
  because newer tasks were filed; numerator is the active-only subset).
- The reviewer dispatch path (T-1951) provides ~5-second per-task isolated
  worker scans — cost is bounded.
- L-409 lists the taste-vocabulary signals (reads clearly, tone, voice,
  rhythm, intuitive, feels right, …) that DISQUALIFY a [REVIEWER]
  classification. A simple regex check answers the routing question.
- This inception is itself a third member of the §ACD-class-at-AC-level
  cluster (T-2118, T-2122) — the broader pattern of *"convention captured
  in text, not in structural enforcement"*.

**GO decision unblocks build tasks:**

- **T-NEW-A:** PreToolUse hook `check-ac-prefix-routing.sh` (parallel to
  `check-render-surface.sh`).
- **T-NEW-B:** `fw audit` check + `.context/inbox.yaml` observation
  emitters for reviewer-candidate [REVIEW] ACs in partial-completes.
- **T-NEW-C:** `update-task.sh` close-gate escalation of T-1896 from
  CONCERN-only to BLOCK with `--skip-ac-routing` override (logged Tier-2).

**Hand to human:** http://192.168.10.107:3000/review/T-2123 — Watchtower
decision form. Agent cannot decide (CLAUDECODE-gated per T-1671).
     - Finding 2
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
