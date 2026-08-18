---
id: T-3043
name: "RCA: non-root agent cannot use TermLink hub — socket mode, connect sequence,
  permission model"
description: >
  RCA: non-root agent cannot use TermLink hub — socket mode, connect sequence, permission
  model

status: started-work
workflow_type: build
owner: agent
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
created: 2026-08-16T17:27:15Z
last_update: '2026-08-17T12:36:10Z'
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
  - ts: '2026-08-16T17:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=305,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T17:30:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3043: RCA: non-root agent cannot use TermLink hub — socket mode, connect sequence, permission model

## Context

A Codex agent running as uid 1000 cannot perform channel RPC against the TermLink
hub on its own host. RCA: `docs/reports/T-3043-termlink-nonroot-rca.md`.

Two stacked defects. Fixing the first exposed the second — which is why the
symptom changed from `EACCES (13)` to `ECONNRESET (104)` rather than clearing.

## RCA

**Symptom.** `channel.list` / `agent.presence` from uid 1000 fail against
`/var/lib/termlink/hub.sock`. Same calls from uid 0, same socket, same hub, same
minute, succeed (`termlink channel list` → 5 channels, exit 0).

**Defect A — `connect()` refused (EACCES 13).** The socket is created
`0755 root:root`. `connect(2)` on AF_UNIX requires the **write** bit; read and
execute are irrelevant. So `0755` on a socket is *owner-only* while reading as
permissive — the mode's appearance and its grant disagree. Every non-root uid is
refused before a byte of protocol, which is why the failure surfaced through an
RPC call and was first misdiagnosed as a channel-authorization problem.

**Defect B — peer dropped after accept (ECONNRESET 104).** At mode `0770` with the
group set, `connect()` succeeds and the hub then closes the peer. uid 0 completes
the identical RPC. So local authorization is uid-coupled *inside* the hub, not
just in the filesystem. `rpc-audit.jsonl` contains no record of the rejected peer —
only successes from root senders — so the hub's own log reports health during the
outage.

**Root cause.** TermLink carries two authorization models and reconciles neither:
TCP `:9100` admits on the HMAC fleet secret (identity-based, uid-agnostic); the
Unix socket admits on whether your uid can write the socket inode (POSIX mode,
uid-coupled). The answer to "who may talk to this hub locally" is therefore decided
by whichever uid ran `hub start` and its umask. The tell is the inversion: a
machine across the network authenticates in while a local process owned by the
operator cannot.

Consequence: a client that cannot reach a hub does not fail loudly — it starts its
own. Three hubs now run on this host (fleet/TCP `3093442`, session-started
`3869961` which took over the runtime dir, Codex's `4086784` on `/tmp/termlink`).
**Fragmentation is the default outcome with two uids, not bad luck.**

**Why the framework allowed it (G-019).** Three structural omissions, all ours:

1. **`fw doctor` has no probe for the substrate the framework dispatches
   through.** It checks the `termlink` binary exists; it does not check the hub is
   reachable, that exactly one hub owns the runtime dir, or that the socket is
   connectable by the uids expected to use it. The three-hub state persisted 4+
   hours with no signal — every fact in this RCA came from ad-hoc `stat`/`ps`/`ss`.
2. **A compound privileged one-liner was handed off and its result never read
   back.** `chgrp … && chmod …` — the first half applied, the second did not, and
   the agent reported the socket fixed without re-reading the mode. A handed-off
   command is not done until its post-state is verified.
3. **A changed error was treated as a cleared error.** `EACCES` → `ECONNRESET` is
   progress, not resolution. The positive assertion (run the failing operation as
   the failing principal) was never made.

**Gate B narrowed after the operator applied 0770 (2026-08-16 19:37).** The chmod
made the failure reproducible locally via `sudo -u`, which let the hypotheses be
tested against each other instead of argued. Eliminated: secret-handshake (no
`hub.secret`, no secret in root's env — root holds no credential either yet
succeeds); group-based (uid 1000 is a member of gid 0 and is still reset);
channel-specific (`topics` fails too, and neither call reaches the audit log).
Surviving explanation: a peer-credential check on **uid equality** with the hub
owner. Inference from behaviour, not from source — the closing read is TermLink's
accept path, out of scope per T-1333.

**And the client masks it (OBS-302).** As uid 1000, `termlink topics` printed
`No event topics found.` and exited 0 while producing zero audit lines — a failed
RPC rendered as a legitimate empty result. `hub status`, `list`, `doctor` and
`whoami` are all filesystem reads, so a non-root agent sees a fully working
TermLink while its hub communication is uniformly zero. That is exactly how the
peer concluded "permissions are correct, the fault is in channel RPC handling":
its entire evidence base was filesystem reads. Reasonable diagnosis, misleading
evidence.

**Prevention.** #1 is the structural fix and the only one that generalises: a
doctor probe asserting single-hub ownership + socket connectability would have
surfaced this at 14:47 instead of 19:25. Filed separately — this task's deliverable
is the RCA, and per one-bug-one-task the probe is its own build task.

The socket/auth fix itself is **not ours**: gap-homing (T-1333) homes it to the
TermLink repo (`SO_PEERCRED` at accept, or loopback TCP with the same HMAC). It is
Candidate C in T-3041.

**Corrections recorded.** Three confident diagnoses in this incident were wrong —
the missing-topic theory (actually split-brain), the peer's channel-authorization
theory (actually a socket inode permission), and this agent's "chgrp+chmod
unblocks it" (necessary, not sufficient). Common thread: each explained the error
text and none tested the layer below it.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] RCA document exists at `docs/reports/T-3043-termlink-nonroot-rca.md` with a
      connection-sequence walkthrough naming the gate each observed error maps to
      (EACCES 13 → `connect()`; ECONNRESET 104 → post-accept admission).
- [x] The permission model is stated with the POSIX rule that explains it:
      `connect(2)` on AF_UNIX requires the **write** bit, so mode `0755` on a
      socket is owner-only despite reading as permissive.
- [x] Root-vs-non-root asymmetry is demonstrated against the **same socket and
      hub**, not asserted — `termlink channel list` captured as uid 0 while uid
      1000 was being reset.
- [x] The three-hub split-brain state is documented with `ps`/`ss` evidence showing
      which hub owns the TCP listener and which owns the Unix socket.
- [x] Unresolved links are listed as OPEN with what would resolve each, not filled
      with a plausible story: (a) which root process reset the socket mode at
      ctime 19:24:19, (b) what the hub checks post-accept.
- [x] G-019 section answers "why did the framework allow this" structurally — not
      "why did the code break" — and names the missing `fw doctor` probe.
- [x] Every factual claim is traceable to a command in the evidence index.
- [x] Upstream vs local recommendations are separated per gap-homing (T-1333): the
      socket/auth fix is homed to the TermLink repo, not filed here.

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

test -f docs/reports/T-3043-termlink-nonroot-rca.md
test -f docs/reports/T-3043-reply-to-0503-transport-request.md
# The OPEN item this RCA committed to leaving open (§4.2 "what the hub checks post-accept")
# is now closed from source. Assert the resolution AND its citation, not just the heading.
grep -q '4.2a RESOLVED' docs/reports/T-3043-termlink-nonroot-rca.md
grep -q 'server.rs:766' docs/reports/T-3043-termlink-nonroot-rca.md
# The reply we sent a peer was corrected, not silently patched: rev 2 must be declared.
grep -q 'Revision 2' docs/reports/T-3043-reply-to-0503-transport-request.md
grep -q 'withdrawn' docs/reports/T-3043-reply-to-0503-transport-request.md
# U-011 is resolved. Positive control on the same file first (L-616): an empty or
# unreadable listing would satisfy the absence check while asserting nothing.
bin/fw pending list > /tmp/.t3043-pending 2>&1 && grep -q 'U-0' /tmp/.t3043-pending
! grep -q 'U-011 \[pending\]' /tmp/.t3043-pending

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

### 2026-08-16T17:27:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3043-rca-non-root-agent-cannot-use-termlink-h.md
- **Context:** Initial task creation
