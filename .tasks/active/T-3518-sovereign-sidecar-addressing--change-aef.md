---
id: T-3518
name: "SOVEREIGN: sidecar addressing — change AEF to dm:/inbox: prefixes, or have
  TermLink generalise ack matching"
description: >
  010-termlink answered AEF's T-3397 scoping ask on 2026-09-22 (their T-3062, DM offset
  5). Two findings. (1) PREMISE DISPROVED: the T-967 persistence contract AEF's design
  assumed never became code — they verified no crate carries persistent/receptionist/cleanup-exemption
  logic, termlink clean only removes dead-pid registrations, and session.needs_restart
  exists nowhere. Their words: do not depend on cleanup exemption or needs_restart.
  T-3397 closed before this arrived, so the finding has no home on it (OBS-250 class).
  (2) OPEN SOVEREIGN QUESTION: they ask AEF to address on dm:<fp>:<fp> or inbox:<agent-id>
  rather than sidecar:<agent-id>, because the ears, receipts, auto-confirm and wake
  events all key on those two prefixes — and they offer the alternative explicitly:
  'If you keep the addressing you have, say so and I file the --await-ack-from generalisation.'
  That is a cross-project interface commitment, not an implementation detail, so it
  is not agent-delegable. Options and directive scoring are in the body. Parked pending
  the operator's ruling; no reply sent to 010-termlink.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [termlink, sidecar, sovereign, cross-project]
components: []
related_tasks: [T-3397, T-3396, T-1135]
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-09-27T12:32:35Z
last_update: '2026-09-27T12:45:27Z'
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
  - ts: '2026-09-27T12:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=359,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-27T12:45:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 4
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=4 (body:cross-machine); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3518: SOVEREIGN: sidecar addressing — change AEF to dm:/inbox: prefixes, or have TermLink generalise ack matching

## Context

**RULED 2026-09-27 by the operator: OPTION 1 — AEF adopts `dm:<fp>:<fp>` /
`inbox:<agent-id>`.** Recorded as **D-660**. The question below is answered; it is
kept in full because the four options and their scoring are the record of *why*.

Consequence for the peer: 010-termlink does **not** need to file the
`--await-ack-from` generalisation they offered — AEF changes its side. They were told
so on the DM thread (see `## Updates`).

Implementation — migrating AEF's sidecar strings and any docs naming
`sidecar:<agent-id>` — is **separate work and was not started under this ruling**;
T-3517's procAsFit run held the active lock at the time.

Remaining open here: **Finding 2** below (nothing consumes AEF's ready-for-input flag
at a yield point — their T-3061's "WAKE = NOT-WIRED"). The ruling did not touch it.

Source: DM `dm:8e6fd77ec6f74b37:d1993c2c3ec44c94` offset 5, from 010-termlink under
their task T-3062, answering AEF's T-3397. Found unread on 2026-09-27 while checking
messages. Their fuller alignment is on `agent-chat-arc` under correlation
`AEF-SIDECAR-E2E` (they cite our @1611/@1633/@1634 and @1651).

### Finding 1 — the premise T-3397 was built on is disproved

010-termlink verified against their own tree: **the T-967 persistence contract never
became code.** No crate carries `persistent` / `receptionist` / cleanup-exemption
logic; `termlink clean` only removes registrations whose pid is dead and never kills
a live session; `session.needs_restart` does not exist anywhere. T-967 was an
inception that reached GO on 2026-04-12 and had no build follower on either side —
our T-1135's pickup (their T-968) closed as "DEFER: subsumed by T-967".

Verbatim: *"do not depend on cleanup exemption or needs_restart — neither exists."*

What they offer instead is **supervision rather than exemption**: T-3050 runs a cron
supervisor that restarts a notify sidecar for every agent declared in
`.context/cron/notify-sidecar-agents.conf`, and T-3051 canaries any declared agent
whose heartbeat goes stale.

This matters beyond the addressing question: any AEF design that assumed an
always-on session survives cleanup by exemption is resting on nothing.

### Finding 2 — they name a gap back at us

Their T-3061 measured that **nothing consumes AEF's ready-for-input flag at a yield
point** — "WAKE = NOT-WIRED". The hook-written flag is ours, it is the piece they
lack, and wiring its consumer is ours to do. That is not this task; it is recorded
here so it is not lost a second time.

## The Sovereign question

They ask AEF to address on `dm:<fp>:<fp>` or `inbox:<agent-id>` instead of
`sidecar:<agent-id>`, because the ears, receipts, auto-confirm and wake events all
key on those two prefixes. And they name the alternative themselves:

> *"If you keep the addressing you have, say so and I file the `--await-ack-from`
> generalisation."*

So both directions are on the table and **they are waiting on us to pick one.** This
is a cross-project interface commitment, which is why it is parked rather than
answered: an agent choosing here binds AEF's side of a protocol with another project.

### Options

1. **Adopt their prefixes.** AEF addresses on `dm:<fp>:<fp>` / `inbox:<agent-id>`.
2. **Keep `sidecar:<agent-id>`** and accept their offer to generalise ack matching
   with `--await-ack-from`.
3. **Support both** — emit on their prefixes, keep accepting ours inbound.
4. **Defer the whole sidecar** until the WAKE consumer (Finding 2) is wired, on the
   grounds that addressing is moot while nothing consumes the flag.

### Pros and contras

| | Pro | Contra |
|---|---|---|
| **1** | Rides rails that already exist and are already tested on their side — ears, receipts, auto-confirm and wake all work today on these prefixes. Zero work for them, so nothing waits on their queue | AEF changes an interface it already designed; any AEF-side code or docs naming `sidecar:` needs revising. Their identity-key caveat for receipts applies and is not yet understood on our side |
| **2** | AEF's addressing stays as designed; the semantic layer is ours and this keeps it coherent | Puts the work on their backlog and makes our delivery depend on their release. Their own message says the existing rails key on two prefixes — so we would be the only traffic needing a special case, which is the shape that rots |
| **3** | No flag day; either side can migrate independently | Two live representations of one address space. This repo spent 2026-09-26 removing exactly that from arc membership (five readers, three verdicts) and the whole day's lesson was that duplicate representations diverge silently |
| **4** | Honest about ordering — addressing a message nobody consumes is premature | Leaves a peer's direct question unanswered indefinitely; they are blocked on our word, not on our code. 832 already has an open state waiting on an AEF verdict from a different thread |

### Scored against the directives (priority order)

| | 1 Antifragility | 2 Reliability | 3 Usability | 4 Portability |
|---|---|---|---|---|
| **1** | **Strong** — converges two projects on one address space, so the next integration inherits it | **Strong** — the rails are built and exercised; fewer untested paths | Partial — one-off migration cost on our side | **Strong** — no AEF-specific special case anywhere |
| **2** | Partial — preserves our design, adds a per-consumer special case to theirs | Partial — depends on unshipped work on another project's schedule | **Strong** — nothing for us to change | Weak — a generalisation that exists for one caller |
| **3** | **Weak** — a second representation of one address space, the exact defect class this repo just spent a day removing | Weak — two paths, one tested | Strong short-term | Partial |
| **4** | Partial — correct ordering, no new debt | Partial — accurate about today, silent about the peer waiting | Weak — a peer stays blocked on a sentence | Neutral |

### Advisory

**Option 1**, and it is not close on the priority ordering: it wins Antifragility and
Reliability, which outrank the Usability cost of migrating our own strings. Option 3
is the tempting one and should be refused for the reason this repo learned the hard
way yesterday — two representations of one identity space diverge, and the guard
against that divergence is always narrower than the divergence.

Option 4 is worth one sentence of respect: the ordering argument is real, and if the
answer to Finding 2 is "we are not wiring WAKE soon", then 4 becomes the honest
answer and 010-termlink should be told that rather than left waiting.

**Not decided here.** Whichever way this goes, someone should reply to 010-termlink —
they answered a direct ask in detail and have had no response since 2026-09-22.

## Context (original)

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
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
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
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

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-27T12:32:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3518-sovereign-sidecar-addressing--change-aef.md
- **Context:** Initial task creation

### 2026-09-27T12:59:22Z — Sovereign question ruled, and the peer told

- **Ruling:** operator chose **option 1** — AEF adopts `dm:<fp>:<fp>` /
  `inbox:<agent-id>`, drops `sidecar:<agent-id>`. Recorded as **D-660**.
- **Reply sent** to 010-termlink on `dm:8e6fd77ec6f74b37:d1993c2c3ec44c94`,
  **offset 10**, ts `1790513962143`. Four points: (1) we adopt their prefixes and
  they should NOT file the `--await-ack-from` generalisation; (2) the T-967 disproof
  is recorded as OBS-555 and we will design onto supervision not exemption; (3)
  "WAKE = NOT-WIRED" is ours, recorded, and explicitly NOT scheduled — stated so it
  cannot read as in-flight; (4) their E2E ack request is stale (our harness window
  closed ~10:54Z) and nothing of theirs is blocked on it.
- **Gate that refused, and what was done:** the first post attempt was BLOCKED by
  `check-rail-mcp-label` — the MCP surface is a second producer to the same rail
  and skips the `from_project` label that `fw rail post` auto-attaches (T-2905,
  measured T-2908). Took the gate's **option 1** (retry with
  `metadata.from_project=999-agentic-engineering-framework`), not its option 2
  (`fw rail allow-unlabeled-mcp`, logged Tier-2). No bypass used.
  - Worth carrying forward: the hook's own note says it enforces the **label only**,
    and that the MCP surface's signing identity is not re-verified per call. So the
    attribution on this reply is label-true and key-unverified. `fw rail identity`
    is the check if that ever matters.
- **Also surfaced:** `fw write-set check` would have called this task's paths
  undecidable — T-3518 declares no `write_set:` because the ruling's implementation
  is deliberately unscheduled. Left undeclared on purpose rather than guessed.
