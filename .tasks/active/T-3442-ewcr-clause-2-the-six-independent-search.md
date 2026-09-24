---
id: T-3442
name: "DM rails addressed to our agent key have no reader and no search covers them:
  sidecar lists and drains dm:* rails, doctor/audit WARN on unread, TermLink asked
  to cover DM in agent search (OBS-482)"
description: >
  Promoted from observation OBS-482

status: started-work
workflow_type: build
owner: agent   # operator assignment 2026-09-23 ("On two, okay that's fine"); no fw verb sets owner — edit recorded on the task
horizon: now
tags: []
components: []
related_tasks: []
arc_id: arc-011
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
created: 2026-09-22T21:30:00Z
last_update: 2026-09-24T15:41:40Z
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
bvp_scores_proposed:
  - ts: '2026-09-22T21:34:25Z'
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
cost_estimate_proposed:
  - ts: '2026-09-22T21:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=292,acs=7)
    rubric_sha: e4a00f38e801
---

# T-3442: EWCR clause-2: the six 'independent' searches in drive 6 §3 shared one blind spot — termlink agent search does not cover DM channels, and 832's substantive clause-2 response was sitting in one. Measured control: the phrase 'consolidated AEF-owned per-finding' is verbatim in dm:3bba15e681b3a078:d1993c2c3ec44c94 offset [2] and 'termlink agent search \"consolidated AEF-owned per-finding\"' returns 0 posts of 1002 envelopes scanned. That DM states DeepSeek and Mistral raw reviews DO exist in the governed 0503 dossier at named paths with verified sha256 (T-032-deepseek-review-response.md = 4dae4098...; T-032-mistral-review-response.md = 0eecb8af...), and that what is missing is AEF's consolidated per-finding disposition tables, not the artefacts. Drives 2-6 all reported clause 2 as 'artefacts absent' on a search method that structurally could not see the reply. 832 offset [7] independently diagnosed the mailbox as having no reader. Sovereign question S1 changes shape as a result; surfaced in docs/reports/EWCR/drive-7-procasfit-handback.md, not decided here.

## Context

Promoted from OBS-482. 832's substantive clause-2 answer sat for weeks on the DM rail
`dm:3bba15e681b3a078:d1993c2c3ec44c94` (offset 2) while five EWCR drives reported the artefacts
absent, because every search they ran (`termlink agent search`, five terms, 1002 envelopes)
structurally excludes DM channels, and nothing on our side reads that rail: its consumer
`framework-agent-systemd` (3bba15e681b3a078) has no reader (832 diagnosed it at offset 7).
Two defects, homed separately: (1) TermLink's `agent search` not covering DM channels is
theirs (gap-homing rule) — ask, do not build; (2) an AEF agent key can be the addressee of a
DM rail nobody drains, and no rail of ours reports that — ours. The sidecar (arc-011) already
owns "what is addressed to us and unread"; this extends it to DM rails.

## Acceptance Criteria

### Agent
- [x] `fw sidecar inbox --peek` and `fw sidecar status` list every `dm:*:<our-key>` and
      `dm:<our-key>:*` rail on the hub with its post count and the number of posts newer than our
      recorded read cursor for that rail (cursor per rail, in `.context/sidecar/inbox-state.json`
      alongside the topic cursors); `fw sidecar inbox` (non-peek) advances the cursor after
      printing the unread posts. Our key = the signing key `fw sidecar whoami` reports.
      **Evidence:** `lib/sidecar/dm.py` (new) + `sidecar_cli.py` `cmd_inbox`/`cmd_status`/
      `cmd_whoami`. Live run against the real hub, both peek shapes: `fw sidecar inbox --peek`
      and `fw sidecar status` both listed all 11 `dm:*` rails addressed to identity
      `d1993c2c3ec44c94`, each with count/cursor/unread; `fw sidecar whoami` prints
      `identity fp: d1993c2c3ec44c94`. Non-peek `fw sidecar inbox` drained real content and
      advanced cursors (`.context/sidecar/inbox-state.json` `topics["dm:..."]` now recorded).
- [x] `fw doctor` WARNs `DM rail <id> has N unread post(s), oldest <age>` when any such rail has
      unread posts older than 24 h; silent when none; mirrored in `fw audit` as a WARN line in
      `check_sidecar_ledger`'s section.
      **Evidence:** `lib/sidecar-audit.sh:fw_sidecar_dm_stale_facts` is the shared fact source
      for both. Live `bin/fw doctor` (no `--quick`) printed 11 `WARN DM rail ... has N unread
      post(s), oldest ...` lines (e.g. `dm:3bba15e681b3a078:d1993c2c3ec44c94 has 123 unread
      post(s), oldest 26.3d`); `--quick` prints `SKIP DM rail staleness check (--quick)` instead.
      `fw audit`'s `check_sidecar_ledger` runs the same fact function, checked before its
      outbox-existence early return so a never-sent project is still checked.
- [x] A consult is sent to `010-termlink` on the sidecar (recorded client_msg_id in this task)
      asking that `termlink agent search` cover DM channels or document that it never will; the
      gap is registered in `.context/project/concerns.yaml` homed to TermLink with that consult
      id, per the gap-homing rule.
      **Evidence:** `fw sidecar send --to 010-termlink` → `client_msg_id:
      d2360e35-1b28-491e-86d3-8a82547a8669`, `state: INJECTED_NOW`, `delivered: true`. G-106 in
      `.context/project/concerns.yaml`, `homed_to: 010-termlink`, `consult.client_msg_id` set to
      the same id.
- [x] pytest: fixture hub state with one DM rail addressed to our key carrying 3 posts and a
      cursor at 1 → peek reports 2 unread; cursor advance after a non-peek read → 0; a rail not
      addressed to our key is ignored. Existing sidecar suites stay green.
      **Evidence:** `tests/unit/test_sidecar_dm.py` (15 tests, new) —
      `test_summary_reports_unread_against_recorded_cursor` (3 posts, cursor 1 → unread 2),
      `test_pending_advances_cursor_past_meta_and_content_alike` (drain → cursor 3 → unread 0),
      `test_a_rail_not_addressed_to_our_key_is_ignored`. `python3 -m pytest
      tests/unit/test_sidecar_*.py -q` → 128 passed (113 pre-existing + 15 new), 0 failed.
- [x] Live: run on this host lists `dm:3bba15e681b3a078:d1993c2c3ec44c94` with its unread count
      before the cursor is set; recorded in this task. Vendored sidecar files synced; `bin/fw
      vendor self --check` clean; `arc_id: arc-011` set in this task's frontmatter.
      **Evidence:** before any cursor existed for the rail (confirmed via
      `.context/sidecar/inbox-state.json` containing no `dm:*` keys), `fw sidecar inbox --peek`
      and `fw sidecar dm-stale --json` both reported
      `dm:3bba15e681b3a078:d1993c2c3ec44c94`: count=123, cursor=0, unread=123, oldest unread
      ~631.1h (~26.3d). `bin/fw vendor self --check` → "vendored .agentic-framework/ in sync
      with source." `arc_id: arc-011` set below.

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

bash -n bin/fw
bash -n agents/audit/audit.sh
bash -n lib/sidecar-audit.sh
python3 -c "import ast; ast.parse(open('lib/sidecar/dm.py').read())"
python3 -c "import ast; ast.parse(open('lib/sidecar_cli.py').read())"
out=$(python3 -m pytest tests/unit/test_sidecar_dm.py -q 2>&1); echo "$out" | grep -qE "[0-9]+ passed" && ! echo "$out" | grep -q failed
out=$(python3 -m pytest tests/unit/test_sidecar_*.py -q 2>&1); echo "$out" | grep -qE "[0-9]+ passed" && ! echo "$out" | grep -q failed
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

### 2026-09-24 — status.py's "never asks the hub" invariant meets a feature that must
- **What changed:** `lib/sidecar/status.py`'s module docstring states its one design
  rule is reading only durable local state, never the hub. AC1 requires `fw sidecar
  status` to list DM rails, which only the hub can answer (no durable local record of
  which `dm:*` rails exist). Resolved by keeping `status_mod.snapshot()` literally
  hub-free and querying `lib/sidecar/dm.py` separately in `sidecar_cli.py:cmd_status`,
  merging at the CLI boundary rather than inside the function whose docstring makes the
  stronger claim.
- **Plan impact:** none to scope — this was a design decision made during implementation,
  not a change to what ships.
- **Triggered:** no new task; documented as a design-decision comment in both
  `lib/sidecar/dm.py`'s module docstring and inline in `cmd_status`.

### 2026-09-24 — routine consult check-in now drains real DM content as a side effect
- **What changed:** the standing peer-consult protocol ("at each yield point, run `fw
  sidecar inbox`") was written before this task existed and assumed that command only
  touches the arc-011 consult channel. Building AC1's non-peek drain means that same
  routine call now also drains every `dm:*` rail addressed to this host's identity and
  prints the content — discovered live when a routine check-in mid-build dumped real
  DM history (advancing `dm:3bba15e681b3a078:d1993c2c3ec44c94`'s cursor from 0 to 100).
  Not a bug — it is exactly what AC1 specifies — but it is a behavioural change to a
  command every future session on this host will run reflexively, with real cost
  (potentially large peer chat history entering context) and a real consequence (rails
  read as a side effect of the habitual check-in, not a deliberate "go read this now").
- **Plan impact:** none to this task's scope (draining on non-peek `inbox` is AC1,
  verbatim). Flagged here rather than silently absorbed, per §Post-Fix Root Cause
  Escalation — worth the operator's attention even though nothing here is broken.
- **Triggered:** no new task filed; left as a documented observation for whoever next
  touches the peer-consult check-in protocol text to weigh peek-by-default there.

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

### 2026-09-24 — "our key" for DM rails = TermLink identity fingerprint, not a circuit id
- **Chose:** `dm.identity_fingerprint()` reads `termlink whoami --json`'s
  `session.identity_fingerprint` (machine-wide, T-3405) as the key `dm:<a>:<b>` rails
  are matched against, and surfaces it on `fw sidecar whoami` as `identity_fingerprint`
  (the AC's "signing key `fw sidecar whoami` reports").
- **Why:** DM rail names are TermLink's own convention, not ours to choose (unlike
  `inbox:<circuit-id>` topics, T-3433) — the two segments are literally the two
  identities `termlink agent contact`/`channel dm` used. Confirmed live: this session's
  `identity_fingerprint` is `d1993c2c3ec44c94`, which matches the second segment of the
  target rail `dm:3bba15e681b3a078:d1993c2c3ec44c94`.
- **Rejected:** `circuit.hub_id()` (that is the HUB's fingerprint, a different value);
  a project- or agent-scoped circuit id (DM rails are not addressed that way — TermLink
  does not know our circuit convention).

### 2026-09-24 — unread count for `summary()`/`stale()` is a live hub call, not derived from `status.snapshot()`
- **Chose:** `dm.summary()` and `dm.stale()` call `termlink channel list --prefix dm:`
  directly; `sidecar_cli.py:cmd_status` merges the result into the printed/JSON output
  alongside (not inside) `status_mod.snapshot()`.
- **Why:** see Evolution entry above — `status.snapshot()`'s documented invariant is
  hub-free, and DM rail existence/counts have no durable local record to read instead.
- **Rejected:** folding `dm_rails` into `snapshot()` itself (would silently break the
  documented "never asks the hub" claim for every other caller of `snapshot()`,
  including `fw_sidecar_ledger_facts`'s ack-ledger read).

### 2026-09-24 — meta envelopes (topic_metadata/receipt/reaction/redaction/edit) advance the cursor but are not counted as "posts"
- **Chose:** `dm.pending()` reads every envelope from the cursor (so the cursor advances
  past them, matching what a real drain saw) but excludes meta `msg_type`s from the
  returned list; `dm._unread_count()`/`dm.stale()` treat the DM rail's `count`/
  `latest_offset` as the ground truth for "how many posts exist" (which includes meta
  envelopes, since TermLink's own counters do) but hunt specifically for CONTENT when
  reporting an age.
- **Why:** matches what `termlink channel unread --help` itself documents excluding, and
  avoids `fw sidecar inbox` printing an empty "post" for a `topic_metadata` banner
  (every DM rail's offset 0, observed live on every one of the 11 real rails checked).
- **Rejected:** treating every envelope as content (would print junk `topic_metadata`
  banners as if they were peer messages); excluding meta from the cursor advance too
  (would leave meta envelopes permanently "unread" and understate `count`-derived
  totals in `summary()`).

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

### 2026-09-22T21:30:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3442-ewcr-clause-2-the-six-independent-search.md
- **Context:** Initial task creation

### 2026-09-24T15:40:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
