---
id: T-3544
name: "sidecar inbound-consult backlog is invisible — unread consults have no count
  in status, no doctor WARN, no audit check (the six-day 832 blockage)"
description: >
  sidecar inbound-consult backlog is invisible — unread consults have no count in
  status, no doctor WARN, no audit check (the six-day 832 blockage)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [agents/audit/audit.sh, bin/fw, lib/config.sh, lib/sidecar-audit.sh, lib/sidecar_cli.py, lib/sidecar/inbox.py, tests/unit/sidecar_audit_rail.bats, tests/unit/t3544_inbox_backlog_rail.bats, tests/unit/test_sidecar_unread_summary.py, web/blueprints/config.py]
related_tasks: []
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
created: 2026-09-28T21:57:41Z
last_update: 2026-09-28T22:31:14Z
date_finished: 2026-09-28T22:31:14Z
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
  - ts: '2026-09-28T22:00:13Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=311,acs=11)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-28T22:00:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3544: sidecar inbound-consult backlog is invisible — unread consults have no count in status, no doctor WARN, no audit check (the six-day 832 blockage)

## Context

A peer (832-Workflow-designer) sat blocked for six days on a one-line answer because
their consult arrived, durably, and nothing on this side ever said so. The rail was
never the problem — consumption was, and it still is: an inbound consult is visible
only to someone who chooses to run `fw sidecar inbox` with no reason to think there
is anything to read.

Measured before this task was filed (2026-09-28):

| Surface | Watches | Inbound consults |
|---|---|---|
| `fw audit` `check_sidecar_ledger` (T-3420) | outbound ledger — 49 sent, 0 unknown | no |
| `fw doctor` + audit `dm_stale_facts` (T-3442) | `dm:*` rails only, returned `[]` | no |
| `fw sidecar status` | outbound ledger + dm rails | **no unread count at all** |
| `fw sidecar inbox --peek` | the consults themselves | only on deliberate invocation |

There is a live instance while this is being written: **seven** unread consults from
010-termlink across `inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework` (5) and the
legacy `sidecar:999-Agentic-Engineering-Framework` alias (2), oldest 7.3 hours. Found by
going to look, not by being told — and the first count taken was 1, because the peek output
was read through `head -40` and the rest was off the end of the screen.

This is deliberately the same shape as a gap already closed. T-3442 gave `dm:*` rails a
staleness fact function, a `fw doctor` WARN and an audit WARN; the consult inbox — the
rail peers are actually told to use — never got one. The fix mirrors T-3442 rather than
inventing a second idiom.

**The load-bearing constraint:** the check must not drain what it measures. `pending()`
advances cursors and the shared seen-set by default, so a naive unread count would
consume the consult it was reporting — the exact class as T-3539, where the diagnostic
destroyed the thing it was diagnosing. Every read added here goes through
`advance=False`, and a test asserts the cursor is unmoved after the check runs.

## Acceptance Criteria

### Agent
- [x] `lib/sidecar/inbox.py` gains an unread-summary function that reports count, oldest
      timestamp, age in hours and per-topic breakdown, built on a non-advancing read
- [x] A test asserts the summary leaves `inbox-state.json` cursors and seen-set byte-identical,
      with a control leg proving the same test fails against an advancing read
- [x] `fw sidecar status` reports the inbound unread count on its own line, and carries it
      in `--json`, merged at the CLI boundary so `status.snapshot()` stays hub-free
- [x] `fw sidecar inbox-stale [--threshold-hours N] [--json]` exists and mirrors `dm-stale`'s
      output contract
- [x] `lib/sidecar-audit.sh` gains a fact function with the same rc contract as its siblings:
      rc 0 facts printed, rc 1 nothing to check so the caller stays silent, rc 2 the check
      could not run so the caller says so rather than reporting zeros
- [x] `fw doctor` emits a WARN naming the unread count, the age and the peer, next to the
      existing DM-rail WARN, and says which command reads the backlog
- [x] `fw audit` `check_sidecar_ledger` emits the same WARN, so the cron'd sweep sees it too
- [x] Bats coverage for the fact function includes both degradation paths and a negative
      control that the check can go red
- [x] `bin/fw vendor self --check` clean before close (OBS-250 — vendored paths touched)
- [x] The threshold is a config key, present in BOTH registries (`lib/config.sh` and
      `web/blueprints/config.py`), and both consumers read it rather than hard-coding
- [x] `fw sidecar status` degrades to `unknown` with a reason, never to `0`, when no
      address can be derived — and `inbox-stale` exits 2 in that case rather than 0

### Human
- [ ] [REVIEW] The new `SIDECAR_CONSULT_WARN_HOURS` row reads correctly on the /config page

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower restart && sleep 3 && bin/fw watchtower url`
  2. Open `<that url>/config` in a browser and find `SIDECAR_CONSULT_WARN_HOURS`
  3. Read its description alongside the rows above and below it

  **Expected:** the row renders in the same style as its neighbours, the default shows `4`,
  and the description explains why it is lower than the dm rail's 24 without needing the task
  file open beside it.

  **If not:** note which part reads wrong (wrapping, truncation, or the description itself)
  and leave the AC unticked — the description text is in `web/blueprints/config.py` and
  `lib/config.sh`, and both must be changed together or the parity lint goes red.

## Verification

# The unit suite: counting, dedupe, alias topics, threshold, and the load-bearing
# non-drain pair (the check must not consume the consult it reports).
timeout 300 python3 -m pytest tests/unit/test_sidecar_unread_summary.py -q > /tmp/.t3544-pt.out 2>&1 && grep -q "passed" /tmp/.t3544-pt.out
! grep -q "failed" /tmp/.t3544-pt.out

# The shell rail: rc 0/1/2 contract, both degradation paths, and a negative control.
timeout 600 bats tests/unit/t3544_inbox_backlog_rail.bats > /tmp/.t3544-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t3544-bats.out
test "$(grep -c '# skip' /tmp/.t3544-bats.out)" -eq 0

# The sibling suite this task modified — its no-termlink-token test now measures
# invocation rather than prose, so it must still be green AND still able to fail.
timeout 300 bats tests/unit/sidecar_audit_rail.bats > /tmp/.t3544-sib.out 2>&1 && ! grep -q "^not ok" /tmp/.t3544-sib.out
test "$(grep -c '# skip' /tmp/.t3544-sib.out)" -eq 0

# The verb exists, exits 0, and moves no cursor. Compared byte-for-byte rather than
# by count: a check that drains its own subject is the failure this task is about.
cp .context/sidecar/inbox-state.json /tmp/.t3544-state.before 2>/dev/null || touch /tmp/.t3544-state.before
timeout 180 bin/fw sidecar inbox-stale --json > /tmp/.t3544-stale.out 2>&1
cp .context/sidecar/inbox-state.json /tmp/.t3544-state.after 2>/dev/null || touch /tmp/.t3544-state.after
cmp -s /tmp/.t3544-state.before /tmp/.t3544-state.after

# status carries the inbound count in --json.
timeout 180 bin/fw sidecar status --json > /tmp/.t3544-status.out 2>&1 && python3 -c "import json;d=json.load(open('/tmp/.t3544-status.out'));assert 'inbound' in d and 'unread' in d['inbound']"

# Both consumers read the config key rather than hard-coding a number, and the key
# is in BOTH registries (the parity lint is the reason the second one exists).
grep -q 'fw_sidecar_inbox_stale_facts "$PROJECT_ROOT" "$(fw_config SIDECAR_CONSULT_WARN_HOURS)"' bin/fw
grep -q 'fw_sidecar_inbox_stale_facts "$PROJECT_ROOT" "$(fw_config SIDECAR_CONSULT_WARN_HOURS)"' agents/audit/audit.sh
grep -q 'SIDECAR_CONSULT_WARN_HOURS' lib/config.sh
grep -q 'SIDECAR_CONSULT_WARN_HOURS' web/blueprints/config.py

# Structural invariants — config-key parity across the two registries lives here.
timeout 900 bats tests/lint/ > /tmp/.t3544-lint.out 2>&1 && ! grep -q "^not ok" /tmp/.t3544-lint.out

# Render surface touched (web/blueprints/config.py) — the running server must not
# be serving pre-change bytes when the operator opens /config to review it.
bin/fw watchtower current

# Vendored paths touched (bin/fw, lib/, agents/) — sync BEFORE close, per OBS-250.
bin/fw vendor self --check

## RCA

**Symptom:** 832-Workflow-designer was blocked for six days on a one-line question. Their
consult had arrived, durably, on time. Independently, 010-termlink found 49 unread consults
on their own inbox — ours among them — and wrote back: *"delivery was never the problem...
consumption is the gap and it is ours."* At the moment this task was filed, seven unread
consults were sitting on our own inbox, oldest 7.3 hours, and nothing had said so.

**Root cause:** the sidecar was built send-first, and every observability rail was added to
the half being exercised at the time. T-3420 gave the OUTBOUND ledger an audit fact function
with a careful rc-1/rc-2 degradation contract. T-3442 gave `dm:*` rails a staleness function,
a doctor WARN and an audit WARN, after 832's clause-2 answer sat three weeks unread. The
consult inbox — the rail peers are told to use, and the one both of those incidents arrived
on — never got the equivalent.

**Why structurally allowed:** the outbound check emits a PASS line that reads like a verdict
on the sidecar as a whole — *"Sidecar ledger: 49 consult(s), 49 delivered, 0 in flight, 0
UNKNOWN, 0 dead-lettered, 0 expired-unswept"*. Six green counters, all about messages we
sent. Nothing in that line says it is silent on everything arriving, so a reader who sees it
has no prompt to ask what is missing. Same family as the port-3000 false green in CLAUDE.md:
a check that asserts nothing is indistinguishable from a check that asserts everything, and
a green line is never the one anybody goes to look at.

**Prevention:** the fix is the third instance of one idiom rather than a third idiom — same
fact-function rc contract, same WARN shape, same two consumers — so a reader comparing the
rails can see at a glance that all three are watched. Two further things are pinned rather
than trusted: `test_summary_does_not_drain_what_it_measures` plus its control leg, because a
backlog check built on the default `advance=True` would consume the consult it reported and
go quiet on the second run with the peer still waiting (OBS-566/T-3539's shape); and the
`unknown`-not-`0` degradation, because "I could not look" reading as "nothing is waiting" is
the precise defect being fixed, and it would have been trivial to reintroduce in the fix
itself — the first draft of `cmd_status` did exactly that by crashing instead.

**Not prevented — the class.** Three rails now each have a hand-written check, and nothing
enumerates the rails, so a fourth starts unwatched by default and nobody finds out until a
peer waits. That is recorded in OBS-567 as the open residue; the general fix is a registry
the audit iterates, which is its own unit of work.

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

**Recommendation:** GO

**Rationale:** Every Agent criterion is green and verified on live data, not only on
fixtures — the WARN fired in both `fw doctor` and `fw audit` naming seven real unread
consults from 010-termlink, and the state file was byte-identical afterwards. The one
thing left is a render check: adding the threshold as a config key put a new row on
/config, which makes this render-touching under P-013. That is a small, genuine ask and
not a hedge — the row is the only part of this change an operator can see.

**Evidence:**
- Live, before the fix: `fw sidecar status` reported the outbound ledger six ways and the
  inbound backlog in none; `fw audit` said `Sidecar ledger: 49 consult(s), 49 delivered,
  0 in flight` and PASSED while seven consults sat unread.
- Live, after: `fw doctor` and `fw audit` each emit two WARNs naming the count (5 and 2),
  the age (7h) and the peer (010-termlink), with the remedy command.
- `fw sidecar status` now prints `inbound unread: 7` with a per-topic breakdown.
- Non-drain proven twice — by byte-comparing `inbox-state.json` across a live
  `fw sidecar inbox-stale` run, and by unit test with a control leg that fails against
  an advancing read.
- 11/11 bats and 10/10 pytest, zero skips; the sibling suite `sidecar_audit_rail.bats`
  still 10/10 after its no-termlink-token test was repaired to measure invocation rather
  than prose, with a control run proving it still catches a real `termlink` call.
- Two defects found and fixed inside the fix: `fw sidecar status` crashed on a host with
  no readable hub anchor (a regression this change introduced), and `inbox-stale` exited
  non-zero only incidentally via traceback. Both now degrade to an explicit `unknown` /
  rc 2 — never to `0`, which would be the same false green the task exists to remove.
- `bin/fw vendor self --check` clean; Watchtower restarted and `watchtower current` green.

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

### 2026-09-28T21:57:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3544-sidecar-inbound-consult-backlog-is-invis.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b34e5147
- **Timestamp:** 2026-09-28T22:34:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-28T22:31:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
