---
id: T-3684
name: "arc-011 sidecar S3: 30s inject tick (configurable) + harness-asserted ready
  flag (Stop hook sets ready-for-input, UserPromptSubmit clears) + urgent hard bypass
  + idle-session wake"
description: >
  Design of record: T-3397 §Consumption (cron tick default 30s configurable = guaranteed-delivery
  fallback; write-time fast path; Stop hook writes ready-for-input:true when the turn
  ends, UserPromptSubmit clears it instantly; store-then-maybe-inject), operator ruling
  2026-09-21 (urgent = hard bypass, inject immediately regardless of state), operator
  2026-10-02 (30s, deliver as designed), target-architecture §2 steps 7-8. Inject
  = one line into the project's TermLink-registered Claude session so the prompt hook
  surfaces the messages. Gap rows R2-R5 in docs/reports/T-3682-sidecar-design-conformance-audit.md.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [sidecar, arc-011, design-conformance, T-3682]
arc_id: arc-011
components: [agents/audit/audit.sh, agents/context/sidecar-autostart.sh, agents/context/sidecar-inbox.sh, agents/task-create/update-task.sh, bin/claude-fw, bin/fw, C-009, lib/config.sh, lib/design_register.py, lib/init.sh, lib/sidecar/adapter.py, lib/sidecar-audit.sh, lib/sidecar_cli.py, lib/sidecar/direct.py, lib/sidecar/hooks.py, lib/sidecar/http_server.py, lib/sidecar/inbox.py, lib/sidecar/inject.py, lib/sidecar/latency.py, lib/sidecar/lifecycle.py, lib/sidecar/receipts.py, lib/sidecar/receiver.py, lib/sidecar/termlink_transport.py, lib/sidecar/watcher.py, tests/integration/t3684_sidecar_watcher_e2e_test.py, tests/unit/sidecar_inbox_hook.bats, tests/unit/t3561_adapter.py, tests/unit/t3561_e2e_nonce.py, tests/unit/t3561_receiver_storage.py, web/blueprints/approvals.py, web/templates/_approvals_content.html]
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
created: 2026-10-01T22:58:50Z
last_update: 2026-10-03T14:48:27Z
date_finished: 2026-10-03T14:48:27Z
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
  - ts: '2026-10-01T23:00:23Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-01T23:00:41Z'
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
  - ts: '2026-10-02T23:04:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3684: arc-011 sidecar S3: 30s inject tick (configurable) + harness-asserted ready flag (Stop hook sets ready-for-input, UserPromptSubmit clears) + urgent hard bypass + idle-session wake

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

**Status 2026-10-03 (finisher w-t3684b-finish) — NOT closed: no passing independent review yet.**
- Round 2 (docs/reports/T-3684-review-codex.md, FAIL): all 4 findings fixed in bb823a983; round 3 confirmed each fixed.
- Round 3 (docs/reports/T-3684-review-codex-round3.md, FAIL): one blocking finding — the urgent "only registered session, no record yet" fallback could type into a headless worker's PTY, and that worker's prompt hook would surface the PTY-only claim; plus the peek hook in a `claude -p` with no own agent id peeked the project's inbox. Fixed in f7c7f1d2c + bf07a0255, with tests that fail on the old code; live e2e run 10 on bf07a0255: 8/8 (docs/reports/T-3684-e2e-run10.log). Brief updated for round 4 (§00).
- Round 4: codex hit its usage limit mid-review (resets 18:11 local, 2026-10-03); no verdict (docs/reports/T-3684-review-codex-round4-aborted.log). The round-4 command is the round-3 command with the round-3 review added to the inputs and `-o docs/reports/T-3684-review-codex-round4.md`.
- Still open: the review-verdict AC (and its Verification line, which greps docs/reports/T-3684-review-codex.md — point it at the passing round's file when one exists). T-3685 and T-3745 are not closed because they close with T-3684.

## Acceptance Criteria

### Agent
- [x] Design register rows R3 (30 s configurable tick) and R5 (urgent bypass) in docs/architecture/sidecar-target-architecture.md §7 are built and set to `status: built` with evidence (owner assigned by T-3694)
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A supervised watcher loop ticks every SIDECAR_TICK seconds (config key in lib/config.sh FW_CONFIG_REGISTRY, default 30); each tick checks the receiver's flagged messages AND the agent's hub inbox topic(s) (legacy topic covered until T-3690)
- [x] Urgent consults inject immediately regardless of the ready flag; non-urgent inject only when the target session is ready; HANDED_OVER only on transcript evidence; the sender is informed (CONFIRM-2)
- [x] Live e2e (not mocked): an idle real session receives a non-urgent consult within 60 s with nobody typing; a busy session only after its turn ends; urgent while busy; a legacy-topic post within 60 s; watcher disabled → no pickup and the sender sees ESCALATED
- [x] `fw sidecar latency` reports send→RECEIVED and send→HANDED_OVER per message (median, p95, max), and the measured figures are in docs/reports/T-3684-review-brief.md
- [x] Receipt telemetry on EVERY path (operator 2026-10-03): a message taken off the hub topic (watcher, prompt hook, `fw sidecar inbox`) sends RECEIVED back at once, HANDED_OVER on injection, REPLIED on an --in-reply-to answer; all three timestamps stored and in `fw sidecar latency`; live test: legacy-topic consult → RECEIVED at the sender within 60 s (gap verified: lib/sidecar/inbox.py sends no receipt today)
- [x] Independent different-vendor review ends VERDICT: PASS — codex rounds 1–3 FAIL (all findings fixed), round 4 run on Z.ai GLM-5.2 because codex hit its usage limit (parent session, 2026-10-03): docs/reports/T-3684-review-zai-round4.md, VERDICT: PASS

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

python3 -m pytest tests/unit/test_sidecar_watcher_t3684.py tests/unit/test_sidecar_session_ready_t3745.py tests/unit/test_sidecar_receiver_t3693.py -q -p no:cacheprovider > /tmp/.t3684-unit.out 2>&1 && grep -q passed /tmp/.t3684-unit.out && ! grep -q failed /tmp/.t3684-unit.out
python3 -c "import json; d=json.load(open('docs/reports/T-3684-e2e-1-idle.json')); assert d['send_to_handed_over_s'] <= 60 and d['transcript']"
python3 -c "import json; d=json.load(open('docs/reports/T-3684-e2e-2-legacy-topic.json')); assert d['via']=='hub-topic' and d['inject_triggers'][0]=='tick' and d['send_to_handed_over_s'] <= 60"
python3 -c "import json; d=json.load(open('docs/reports/T-3684-e2e-3-busy-urgent.json')); u=d['urgent']; n=d['non_urgent']; assert u['busy_at_inject'] and u['pty_has_line_while_busy'] and n['inject']['trigger']=='tick' and n['turn_end_to_inject_s'] >= -1.5"
python3 -c "import json; d=json.load(open('docs/reports/T-3684-e2e-5-negative-control.json')); assert d['escalated_row']['by']=='infrastructure' and 'HANDED_OVER' not in d['sender_states'] and d['legacy_ingested'] is None"
python3 -c "import json; d=json.load(open('docs/reports/T-3684-e2e-2-legacy-topic.json')); assert d['sender_receipt_received'] and d['sender_send_to_received_s'] <= 60 and d['sender_receipt_handed_over']"
python3 -c "import json; d=json.load(open('docs/reports/T-3684-e2e-2b-replied.json')); assert all(d['receipts'].values()) and d['latency_row'][0]['send_to_replied_s'] is not None"
python3 -m pytest tests/unit/test_sidecar_receipts_t3684.py -q -p no:cacheprovider > /tmp/.t3684-rcpt.out 2>&1 && grep -q passed /tmp/.t3684-rcpt.out && ! grep -q failed /tmp/.t3684-rcpt.out
python3 lib/sidecar_cli.py latency --json > /tmp/.t3684-lat.out 2>&1 && grep -q send_to_replied /tmp/.t3684-lat.out
python3 -c "import yaml,re; f=chr(96)*3; t=open('docs/architecture/sidecar-target-architecture.md').read(); r=yaml.safe_load(re.search(f+'yaml\n(register:.*?)'+f, t, re.S).group(1))['register']; assert all(x['status']=='built' for x in r if x['id'] in ('R3','R5'))"
grep -q "VERDICT: PASS" docs/reports/T-3684-review-zai-round4.md
bin/fw vendor self --check

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

### 2026-10-03 — readiness had to become per-session first (T-3745)
- **What changed:** The per-project ready flag T-3693 built could not carry a watcher: with a fleet agent and the operator's terminal in one project, the tick would have typed into whichever session's sibling had stopped. T-3745 was built first: per-session records keyed on the hook's `session_id`, carrying `TERMLINK_SESSION_ID` (set by `termlink spawn` in the PTY claude-fw launches claude from — verified for backends `background` and `auto`) and the claude pid; claims name the target session and are written before typing.
- **Plan impact:** The legacy hub topic is not a second inject path: each tick drains it into the receiver store (cursor advanced, so the peeking sidecar-inbox hook does not show it twice), from where it follows the same flag → inject → transcript-evidence route. A legacy sender has no direct ledger, so CONFIRM-2 is recorded as CONFIRM_SKIPPED for it, explicitly.
- **Triggered:** none new. Live run 1 showed haiku running a requested `sleep` with run_in_background, ending the "busy" turn in 6 s; the e2e now asserts the session is still busy 8 s after the prompt, so a weak precondition fails loudly instead of passing or failing for the wrong reason.

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

### 2026-10-01T22:58:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3684-arc-011-sidecar-s3-30s-inject-tick-confi.md
- **Context:** Initial task creation

### 2026-10-02T03:05:00Z — handoff from T-3693 [w-t-3693b]
- **Inherited:** T-3693 built the receiver's injection step but no tick. The tick this task builds should call `fw sidecar deliver-pending --trigger tick` (lib/sidecar_cli.py `cmd_deliver_pending` → lib/sidecar/inject.py `deliver_pending`, flock-guarded and idempotent within 120 s) on its cadence. Register rows R3 (tick) and R5 (urgent bypass) point here. inject.py already injects an `urgent` message regardless of readiness (`urgent_bypass` in the INJECT_ATTEMPT event), so R5's remaining scope is the operator-ruled priority semantics. The live e2e (tests/integration/t3693_sidecar_e2e_test.py) runs deliver-pending every 5 s as a stand-in.

### 2026-10-02T23:04:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9f89a59a
- **Timestamp:** 2026-10-03T14:50:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-10-03T14:48:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
