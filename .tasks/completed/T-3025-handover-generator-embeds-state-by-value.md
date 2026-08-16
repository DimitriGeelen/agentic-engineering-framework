---
id: T-3025
name: "handover generator embeds state by value — reference it instead (candidate
  F)"
description: >
  handover generator embeds state by value — reference it instead (candidate F)

status: started-work
workflow_type: inception
owner: human
horizon: now
target_blast_radius: 3   # agents/handover/handover.sh + section builders; single subsystem
voi_score: 0.7           # settles 79% of corpus growth and the G-018 quality question
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-15T22:12:24Z
last_update: 2026-08-15T23:08:43Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-08-15T22:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-15T22:15:13Z'
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
  - ts: '2026-08-15T22:16:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 4
      D4: 4
      F-RECALL: 4
      F-AUTONOMY: 4
      F3: 4
      F1: 4
      F2: 4
    rationale: D1=4 (no-signal); D2=4 (no-signal); D3=4 (no-signal); D4=4 
      (no-signal); F-RECALL=4 (no-signal); F-AUTONOMY=4 (no-signal); F3=4 
      (no-signal); F1=4 (no-signal); F2=4 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3025: handover generator embeds state by value — reference it instead (candidate F)

## Context

Candidate F from T-3022 (inception, GO 2026-08-15). Filed as **inception, not build**: the
measurement is settled, but the remedy trades away a real property, so it needs a design
decision before anyone writes code.

**What is measured (T-3022 spike 10, `docs/reports/T-3022-recall-latency-scaling.md`):** the
handover embeds global state **by value rather than by reference**. A representative handover
is 265,888 bytes of which **97.3% is state dumps** — Observation Inbox 137,505 B, Work in
Progress 69,568 B, Awaiting Your Action 48,355 B. Those sections are **byte-identical between
consecutive handovers** (0 differing lines) and 99.7% / 100% identical across a three-hour gap
with real work in between. Archive-wide, 8 of 9 sampled consecutive pairs are ≥96.3% identical,
sustained March → August. At corpus scale the dumps are **82% of all 90.6 MB** of handovers.

Total bytes ≈ *number of handovers × size of state*, with **both terms growing** — which is why
handovers are 68% of the indexed corpus and 79% of its growth, and why their share has climbed
monotonically every month (27 → 68%) with no reversal.

**The open question is not whether this is real. It is what a handover is for.** Referencing
instead of embedding cuts ~74 MB and ~79% of corpus growth at source, and makes handovers
readable — currently 342 bytes of "Where We Are" sit buried in a quarter-megabyte. But it
trades away the ability to read a handover without a live system, which is worth something
during exactly the recovery scenarios handovers exist for. That tradeoff is the operator's,
which is why this is an inception.

**Why nothing reported it:** every individual handover is correct, and the state it embeds is
real and current. There is no defective file to find and no event to notice — the defect exists
only as a property of the *sequence*, and nothing measures sequences.

**Secondary finding, arguably the more serious one:** in that same 265,888-byte file,
`## Decisions Made This Session` is 38 B, `## Things Tried That Failed` 35 B,
`## Open Questions / Blockers` 36 B and `## Gotchas` 66 B — **175 bytes total, all empty**, in a
session that produced all four. The mechanical dumps grow without bound while the sections
carrying antifragile content go unfilled. This is G-018 (handover quality decay) with a
measurement attached, and it may deserve a task of its own rather than riding on this one.

Registered as OBS-272. **Nothing here has been built.**

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these.
     This is an inception: the deliverable is a decision-ready artifact, not code. -->
- [x] The four options (embed all / reference all / digest+reference / delta-only) are stated
      with the property each trades away, so the decision is between real alternatives rather
      than yes/no on the first one proposed.
- [x] Option (3) is **built and measured** rather than estimated — `docs/reports/T-3025-digest-spike.py`
      runs against a real handover and reports its own reduction, and every count it emits is
      cross-checked against an oracle it does not control (each section's self-reported figure).
- [x] IW-2 is answered empirically, not by argument: a two-arm probe with the unmodified
      handover as control, both arms committed at `docs/reports/T-3025-iw2-arm-{a,b}-*.md`.
- [x] The probe's disagreement with my own prior conclusion (§11c) is recorded **as a
      reversal**, naming what I got wrong and why, rather than quietly restating it.
- [x] Defects surfaced that are independent of this decision are filed separately and not
      absorbed into the byte-count story — OBS-275 (push-state), OBS-276 (`tasks_active:`).
- [x] `## Recommendation` states GO/NO-GO with rationale and evidence, and names explicitly
      what it does **not** settle (IW-1) rather than implying the decision is complete.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
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
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

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

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

**Recommendation:** GO — option (3) digest-plus-reference, conditional on carrying per-task
status, and scoped to the three dump sections only.

*(This replaces an auto-retrofitted DEFER stub whose stated promotion criterion was
"re-surface when concrete spike data emerges". Spikes 11 and 12 are that data. The backstop
did its job by flagging the gap; its placeholder content was never an assessment.)*

**Rationale:**

The cost side is settled and large. 97.3% of a representative handover is state dumps, those
dumps are byte-identical between consecutive handovers, and they are 82% of a 90.6 MB corpus
whose total is growing on both terms at once (count 32 → 1,717, mean size 4.5 KB → 54.2 KB).
A built digest reduces a real handover 14.6× with all 14 narrative sections byte-identical.

The case against was offline readability — a referencing handover cannot be read without a
live system, and the scenarios that matters for are disproportionately the ones handovers
exist for. **Spike 12 substantially weakens that objection for option (3) specifically.**
The digest preserves narrative in full, and narrative is what a cold reader actually needs:
the probe arm given only the digest answered "what must you not do", "name a decision and
its reasoning", and "what should you do first" with high confidence and correct quotations.
What it loses is enumerated live state — a queue snapshot that is stale the moment it is
written, and which every consumer would re-derive anyway. Referencing the part that goes
stale and embedding the part that does not is the right split, not a compromise.

Two conditions, both cheap, both worth doing regardless:

1. **The digest must carry per-task `Status`.** Without it the probe's digest arm read 82
   parked tasks as live work and stated one as in-progress with high confidence. Cost is
   4,764 B for all 119 entries — 6.8% of a section that is 25% of the file.
2. **`tasks_active:` must mean active.** This is the actual defect behind condition 1 and it
   is wrong in the full handover too, merely survivable there because the dump below
   contradicts it. Fixing it makes condition 1 unnecessary. (OBS-276.)

I am not recommending (2) reference-everything — it discards the narrative value the probe
just demonstrated — nor (4) delta-only, which is uncosted and whose failure mode (a chain
where one broken link orphans everything after it) is worse than the problem.

**What I am NOT recommending, and why this is not a full GO on candidate F:** IW-1 — is the
handover's primary consumer a cold reader or a live session? — is untouched by all of this
and is genuinely yours. My argument above assumes narrative is the cold-reader payload. If
you think the enumerations *are* the payload, option (3) is wrong and the answer is to keep
embedding and attack the growth elsewhere. No measurement settles that.

**Evidence:**

- **Corpus:** 0.5 → 133.6 MB, +62% in the last month, 79% handovers (T-3022 §Spike 9,
  measured against HEAD after a stale-`master` error produced a false flat tail — L-608).
- **Redundancy:** consecutive handovers byte-identical across the three dumps; 8 of 9
  sampled pairs ≥96.3% identical, sustained March → August (T-3022 §Spike 10).
- **Digest built and measured:** 273,761 → 18,762 B (6.9%), 14/14 narrative sections
  byte-identical by md5 (§Spike 11). Script committed at
  `docs/reports/T-3025-digest-spike.py` so the numbers are reproducible.
- **Dump content is mostly constant:** 119/119 entries `Next step: See task file`; 119/119
  `Blockers: None`; 17/119 `Last action: See git log` (§11b, §12).
- **Two-arm probe, zero parent context:** neither arm confabulated across the elision; both
  named the right command. Outputs committed at `docs/reports/T-3025-iw2-arm-{a,b}-*.md`.
- **The reversal, stated against my own prior conclusion:** §11c claimed the digest drops no
  task identity and the trade is cheap. The probe showed the surviving carrier asserts a
  false status. I had counted the bits without asking what depended on them. A single arm
  would not have caught it.
- **Two defects surfaced that are independent of this decision:** OBS-275 (handover reports
  vs-master, not push state — the quantity its own discipline turns on) and OBS-276.
  Both were raised unprompted by the probe arms.

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-15T22:12:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3025-handover-generator-embeds-state-by-value.md
- **Context:** Initial task creation

### 2026-08-15T22:15:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-08-15T22:16:04Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-08-15T22:16:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-08-15T22:18:40Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-08-15T22:19:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-08-15T22:19:50Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-08-15T22:23:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
