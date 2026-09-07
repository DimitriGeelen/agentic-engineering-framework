---
id: T-3335
name: "arc-020 S8: termlink wiring — connect aef identity substrate seams (probe,
  claim, peer-query, provisioners) to live termlink verbs + capture the headline-mechanic
  demo"
description: >
  S1-S7 landed as libs with injectable seams (endpoint-probe, claim backend, peer-query,
  materializers, notice-sink). The headline mechanic (durable-name addressing, no
  fingerprint collapse, circuit self-heal with the message still landing) is only
  demonstrable once those seams bind to live termlink. Wire-level demo artifact is
  the arc close gate (§ACD).

status: started-work
workflow_type: build
owner: human
horizon: now
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
created: 2026-09-07T07:29:59Z
last_update: 2026-09-07T10:09:02Z
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
  - ts: '2026-09-07T07:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=258,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-07T07:45:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3335: arc-020 S8: termlink wiring — connect aef identity substrate seams (probe, claim, peer-query, provisioners) to live termlink verbs + capture the headline-mechanic demo

## Context

arc-020 S1–S7 landed the identity substrate as libs with injectable seams (design:
`docs/reports/T-3287-identity-taxonomy-circuit-model.md`). This task wires the **claim
backend** seam (`lib/aef_election.py` `TermlinkChannelClaimBackend`, until now a
`NotImplementedError` shape-only stub) to the live `termlink channel claim|claims|release`
verbs — operationalizing D5 bound 1 / F5 (exactly-one provisioning, first-claim-wins),
which serves **G4** and is the mutex the origin-bug fix (G1: distinct co-resident agents =
distinct correspondents) rests on.

**Integration reality surfaced while wiring (the reason this is a real adapter, not a
rename):** the election.py docstring assumed `termlink channel claim <channel> <key>` with
`key` = the target address. The *actual* verb is `channel claim --claimer <ID> <TOPIC>
<OFFSET>` — an offset-lease within a topic (30s TTL, hub-clamped 1h, returns `claim_id`).
So an AEF election target maps onto a `(topic, offset)` coordinate, and the claim is a
renew-or-lapse *lease*, not a permanent mutex. Both facts are captured in ## Decisions.

**Remaining S8 scope (NOT in this task — file as follow-ons after this lands):**
- probe seam (5-rung dispatcher: host→ping, hub→hub_probe, session→list_sessions) + provisioners (spawn / hub_start) → live wiring.
- peer-query + materialize (`termlink discover` / `file_receive`) for fleet repo-sourcing.
- notice-sink → `termlink agent post` / operator DM.
- The full headline-mechanic demo: two live co-resident agents stay distinct correspondents (G1) AND a dropped circuit self-heals with the message still landing (G3) — the wire-level artifact that is the arc-close gate (§ACD). This task delivers the claim-mutex foundation that demo stands on (see the [REVIEW] Human AC).

## Acceptance Criteria

### Agent
<!-- Scope note (task-sizing, one-deliverable): S8-as-filed bundled five seam wirings
     (probe, claim, peer-query, provisioners, notice-sink) + a live demo — too big for
     one task. This task delivers the CLAIM-BACKEND seam (the only hard NotImplementedError
     stub in the arc substrate, and the seam that operationalizes G4 exactly-once). The
     other four seams + the full G1+G3 co-resident/self-heal demo are the remaining S8
     scope, tracked in ## Context. -->
- [x] `TermlinkChannelClaimBackend.try_claim` / `holder` and its ticket's `release` implement the `ClaimBackend`/`ClaimTicket` protocols against the live `termlink channel claim|claims|release` verbs — no `NotImplementedError` / "wiring is deferred" stub remains in `lib/aef_election.py`.
- [x] Each AEF election target (a serialized V9 address) maps deterministically to a `(topic, offset)` termlink claim coordinate; the mapping is stable (same address → same coordinate) and collision-resistant (sha256-derived).
- [x] The `invoke` seam is injectable — default is a subprocess invoker over the `termlink` binary; tests inject a fake so won / lost / holder / release / release-idempotent paths verify with **no live hub required**.
- [x] A contested claim returns `None` (not an exception) so `elect()` yields role=LOST naming the holder; `release` reopens the coordinate for the next claimant and is idempotent.
- [x] `tests/unit/test_aef_election_termlink.py` covers those paths with a fake invoke, and the existing `tests/unit/test_aef_election.py` stays green.

### Human
- [ ] [REVIEW] Live wire-level smoke of the claim mutex (the arc-close demo's foundation). Against a running local hub, two distinct `candidate_id`s race one AEF target: exactly one gets role=WON, the other gets role=LOST naming the holder, and the winner's `release` returns the target to electable. This proves the F5 first-claim-wins mutex fires on real termlink — the substrate the full G1 (distinct co-resident correspondents) + G3 (self-heal, message still lands) demo builds on.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && termlink hub status 2>&1 | head` — confirm a hub is running (if not: `termlink hub start`).
  2. `cd /opt/999-Agentic-Engineering-Framework && python3 tests/manual/s8_claim_smoke.py` (the smoke script committed with this task).
  **Expected:** Output shows one `WON` and one `LOST` for the same target, the LOST row names the winner as holder, and a final `released → re-electable` line.
  **If not:** Capture the script output + `termlink channel claims <topic> --json` for the target's topic; the offset-lease TTL (30s default) may have lapsed mid-run — re-run, or note the hub error code.

## Verification

timeout 120 python3 -m pytest tests/unit/test_aef_election_termlink.py tests/unit/test_aef_election.py -q > /tmp/.s8-claim.out 2>&1 && grep -q passed /tmp/.s8-claim.out && ! grep -q failed /tmp/.s8-claim.out
! grep -q "channel-claim wiring is deferred" lib/aef_election.py
bin/fw vendor self --check

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

### 2026-09-07 — termlink claim is a work-queue offset lease, not a named mutex
- **Chose:** Map each AEF election target to a `(topic, offset=0)` coordinate — one
  topic per target (`election_topic(channel, target_wire)` = channel + sha256[:16]),
  offset 0 as the single mutex slot, seeded with one sentinel message.
- **Why:** The `lib/aef_election.py` docstring assumed `termlink channel claim <channel>
  <key>` — a named mutex keyed on the address. The real verb (verified live, T-3335 probe)
  is `channel claim --claimer <id> <topic> <offset>`: an **offset lease within a topic**
  (T-2032 work-queue semantics), 30s default TTL, hub-clamped 1h, returns `claim_id`.
  A target has no natural offset, so it maps onto a dedicated topic and a fixed offset.
- **Rejected:** (a) single shared topic + `offset = hash(target) mod N` — collision risk
  and semantic abuse of the offset space. (b) KV compare-and-set as the mutex — would
  abandon the F5 `channel claim` substrate the design explicitly chose, and lose the
  TTL-lease crash-recovery that matches S2 stale-pid semantics for free.

### 2026-09-07 — an offset cannot be claimed at/beyond the frontier (seed a sentinel)
- **Chose:** `_ensure_seeded()` posts exactly one sentinel message when `channel info`
  reports `count == 0`, so offset 0 exists before any candidate races it.
- **Why:** The hub rejects claiming an unposted offset (`code=-32022: offset 0 ... is
  at/beyond the frontier 0 (cannot claim unposted work)`). The mutex slot must be a real
  message position. A concurrent first-post can seat two sentinels (offsets 0 and 1);
  that is **harmless** — every candidate still races offset 0, so exactly-one-wins holds.
- **Consequence (renew-or-lapse):** the claim is a *lease*, not a permanent mutex. A
  crashed winner's slot reopens on TTL expiry (good — matches S2 crash recovery), but a
  winner whose provision outlives `ttl_ms` (default 60s) MUST renew (`channel renew`) or
  lose the slot mid-provision. Renewal is out of scope for this seam and belongs with the
  provisioner-wiring follow-on; noted here so the next slice inherits the constraint.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-07T07:29:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3335-arc-020-s8-termlink-wiring--connect-aef-.md
- **Context:** Initial task creation

### 2026-09-07T10:09:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
