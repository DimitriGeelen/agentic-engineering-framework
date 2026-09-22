---
id: T-3423
name: "arc-011 sidecar slice 9: fw sidecar e2e — live TermLink end-to-end harness
  (send → hub → dispatched worker → reply → hub → inbox), every hop checked, repeatable
  verdict"
description: >
  arc-011 sidecar slice 9: fw sidecar e2e — live TermLink end-to-end harness (send
  → hub → dispatched worker → reply → hub → inbox), every hop checked, repeatable
  verdict

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [termlink, peer-consult, sidecar, e2e, test]
components: []
related_tasks: [T-3406, T-3407, T-3417, T-3420]
arc_id: parallel-execution-aef
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
created: 2026-09-22T08:41:14Z
last_update: '2026-09-22T08:45:21Z'
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
  - ts: '2026-09-22T08:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=321,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T08:45:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3423: arc-011 sidecar slice 9: fw sidecar e2e — live TermLink end-to-end harness (send → hub → dispatched worker → reply → hub → inbox), every hop checked, repeatable verdict

## Context

Slices 1–8 of the arc-011 sidecar each proved one hop in isolation (unit
tests with fixture ledgers and fake transports) plus one hand-driven live
round trip (T-3406) and one un-instructed live answer (T-3407). What does
not exist is a **repeatable, mechanical, end-to-end verdict** over the real
thing: real TermLink hub, real `fw termlink dispatch` worker, real `claude`
process reading its inbox, real reply travelling back. Without it, "the
sidecar works" is a recollection of two demos, not a check anyone can run.

**`fw sidecar e2e`** is that check. One run:

1. Preflight — `termlink` present, local hub probe ok, `fw termlink check`.
2. A unique run id; a throwaway **sender** id (`e2e-<run>-sender`) and a
   **responder** worker name (`e2e-<run>-responder`), so nothing touches the
   parent session's own inbox or ledger state.
3. **Send** a consult (body carries the nonce `SIDECAR-E2E <run>`) from the
   sender to the responder through the real transport (slices 1–3, in-process
   API, no shelling out to our own CLI).
4. **Dispatch** the responder via `fw termlink dispatch --name … --task …`
   with a prompt that says: read your inbox, answer every SIDECAR-E2E consult
   with `SIDECAR-E2E-ACK <run>` on the same conversation, print DONE.
   `--ambient` swaps in a neutral prompt that never mentions consults, so the
   T-3407 stanza alone has to carry it — that measures the ambient property,
   reported separately from the transport verdict.
5. **Wait** for the reply on the sender's inbox topic, polling with the real
   `termlink channel subscribe`, up to `--timeout`.
6. **Check every hop from two sides** — our ledger and the hub's own topic:
   - H1 ledger: our row for the consult is `INJECTED_*` (slice 2 semantics);
   - H2 hub: `sidecar:<responder>` holds a message whose
     `metadata.client_msg_id` is ours (delivery proven by the hub, not by us);
   - H3 worker read: the shared inbox-state cursor for `sidecar:<responder>`
     advanced past 0 (the worker ran `fw sidecar inbox`);
   - H4 hub: `sidecar:<sender>` holds a message from the responder on our
     conversation id containing the ACK nonce;
   - H5 inbox: `inbox.pending(sender)` surfaces that reply with the right
     conversation id and body;
   - H6 worker exit: `fw termlink wait` returned and the result carries DONE.
7. **Report** — a JSON record under `.context/sidecar/e2e/<run>.json` and a
   text verdict; exit 0 only when H1–H6 all pass; `--ambient` adds an `A1`
   line that is informative, never blocking.

The orchestration lives in `lib/sidecar/e2e.py` with every collaborator
(send, dispatch, wait, hub read, inbox read, clock, sleep) injectable, so
the state machine is unit-tested offline with fakes — including the failure
shapes (no reply, hub never shows our message, worker exits without DONE) —
and the live run is the same code with the real collaborators plugged in.

**Not in scope.** Cross-host (remote hub); retry policy (OBS-447); making the
run a cron (its cost is a real `claude` worker — an operator-invoked check,
and a candidate `fw doctor --deep` leg later).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/sidecar/e2e.py:run(cfg, *, send, dispatch, wait, result, hub_messages, read_inbox, cursor, sleep, now)` drives steps 2–7; report dict carries `hops[H1..H6]{ok,title,detail}` (+`A1` under ambient), `verdict`, `run_id`, `client_msg_id`, `timings{sent,dispatched,reply_seen,worker_exit,total}`, `dispatch`/`worker` tails; a raised send or a non-zero dispatch marks the remaining hops "not attempted" and still returns — `_finish()` fills any hop never reached
- [x] `fw sidecar e2e [--task] [--timeout 300] [--worker-timeout 600] [--ambient] [--keep] [--json]` — `cmd_e2e` in `lib/sidecar_cli.py`: `e2e.preflight()` (termlink on PATH + `probe_hub(None)`) before any dispatch, exit 2 on refusal; task from `--task` or `focus.yaml`; JSON record via `write_report` (atomic) under `.context/sidecar/e2e/<run>.json`; throwaway inbox cursors dropped unless `--keep`; exit 0 iff verdict PASS; `bin/fw help` sidecar line lists all six verbs — `tests/lint/help-router-parity.bats` 2/2
- [x] `tests/unit/test_sidecar_e2e.py` — 8 tests with a scripted `Fakes` hub+worker: full pass (6/6 hops, prompt carries nonce+ACK, no A1); reply never arrives (H4/H5 FAIL, window spent, ≥12 polls, no exception); hub never shows our consult (H2 FAIL alone); no DONE (H6 FAIL); dispatch rc≠0 (H3–H6 "not attempted", H2 still asked); send raises (H1 FAIL, nothing dispatched); ambient folds H3–H5 into A1 without changing the verdict, and its prompt has no "inbox"/"consult"; report round-trips + renders. **8/8; all seven sidecar suites 43/43**
- [x] **Live, explicit mode, twice:** run `1d953701` — PASS 6/6, 19.17s total (send 0.28s, dispatch 1.81s, reply seen 16.94s, worker exit 19.07s); run `94fc8390` — PASS 6/6, 21.93s (reply seen 21.7s). Both records committed under `.context/sidecar/e2e/`. Hub-side evidence in each: our `client_msg_id` on `sidecar:<responder>` @0, the responder's ACK on `sidecar:<sender>` with `from_agent=<responder>` and our conversation id; responder cursor 0→1; `fw termlink wait` rc 0 with DONE
- [x] **Live, ambient mode:** run `0153e35a` — transport verdict PASS (H1, H2 @0 on `sidecar:e2e-0153e35a-responder`, H6 rc 0 + DONE), 242.7s (the worker's own `sleep 45` plus a full 240s ACK window). **A1 as first scored: FAIL — a harness false negative.** The un-instructed worker (prompt: "run sleep 45, print DONE", nothing about consults) read its inbox, sent `bin/fw sidecar send --to e2e-0153e35a-sender --conversation e2e-0153e35a --body 'ack SIDECAR-E2E 0153e35a'`, then slept and printed DONE; the reply sits on the hub at `sidecar:e2e-0153e35a-sender` @0 with `from_agent=e2e-0153e35a-responder` and our conversation id. The matcher demanded the literal `SIDECAR-E2E-ACK` token and missed it. Fixed: `is_ack()` = same conversation + from the responder + body carries the run id (unit test 9). **Actual value: the ambient headline mechanic fired live, un-instructed, through the hub.** Second ambient run `7e013402` with the corrected matcher: **A1 PASS** — reply seen 16.72s after send, H1–H5 all PASS; overall verdict FAIL on H6 alone: the worker backgrounded its `sleep 45`, ended the headless turn "waiting to be notified", and never printed DONE (`wait rc=0 DONE=no`). Model quirk of a sleep-shaped job, not a channel property; the ambient job now runs `date -u` instead. Ambient tally so far: un-instructed answers **2/2**, both verified on the hub
- [x] Vendored copies of `lib/sidecar/e2e.py`, `lib/sidecar_cli.py`, `bin/fw` synced (`FW_VENDOR_ONLY`, VERSION 1.6.768); `bin/fw vendor self --check` → "in sync with source"; fabric cards `lib-sidecar-e2e.yaml` + the test's card registered; `.gitignore` now ignores sidecar runtime state and tracks only `e2e/<run>.json` verdict records (Decision below)

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

python3 -m pytest tests/unit/test_sidecar_e2e.py tests/unit/test_sidecar_sweep.py tests/unit/test_sidecar_status.py tests/unit/test_sidecar_inbox.py tests/unit/test_sidecar_termlink_transport.py tests/unit/test_sidecar_delivery.py tests/unit/test_sidecar_outbox.py -q > /tmp/.t3423-py 2>&1 && grep -q passed /tmp/.t3423-py
timeout 120 bats tests/lint/help-router-parity.bats > /tmp/.t3423-help 2>&1 && ! grep -q "^not ok" /tmp/.t3423-help
bin/fw sidecar e2e --help > /tmp/.t3423-h 2>&1 && grep -q -- "--ambient" /tmp/.t3423-h
# Live evidence pinned as an invariant (T-3326): at least two PASS records exist for this host, each with all six blocking hops ok.
python3 -c "import json,glob,sys; rs=[json.load(open(p)) for p in glob.glob('.context/sidecar/e2e/*.json')]; ok=[r for r in rs if r.get('mode')=='explicit' and r.get('verdict')=='PASS' and all(r['hops'][h]['ok'] for h in ('H1','H2','H3','H4','H5','H6'))]; sys.exit(0 if len(ok)>=2 else 1)"
test -f .fabric/components/lib-sidecar-e2e.yaml
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

### 2026-09-22 — the check the arc was missing, and what it measured
- **What changed:** two things we did not know at filing. (1) The whole
  round trip is ~20 s wall-clock, of which the hub legs are sub-second both
  ways; the rest is `claude -p` boot plus one inbox read and one send. So
  "the sidecar is slow" would be a model-boot statement, never a transport
  one. (2) The first two live runs passed on the first try — no harness
  fix-ups were needed against the real hub, which says slices 1–8's unit
  fakes matched the real envelope shapes (the T-3405 measurement work paid
  off here).
- **Plan impact:** none on the transport. The ambient measurement (`A1`)
  becomes the arc's recurring number rather than a one-off demo.
- **Triggered:** nothing new on our side. Open toward TermLink, posted on
  agent-chat-arc @1633/@1634 and injected into their live master session:
  @1611 (do they ship the receiving half), a cheaper hub-side "does topic T
  hold client_msg_id X" primitive than a full `subscribe --cursor 0` scan,
  and whether they are building anything we would duplicate. No reply yet
  from TermLink on any channel today; their DM thread @3 (T-3397) is also
  unanswered since 2026-09-21.

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

### 2026-09-22 — what of `.context/sidecar/` is tracked
- **Chose:** ignore the runtime state (outbox message files, the append-only
  ack ledger, inbox cursors, worker prompts); track only the e2e verdict
  records `.context/sidecar/e2e/<run>.json`.
- **Why:** the runtime files are per-host, grow on every consult, and would
  turn every `fw sidecar send` into an uncommitted change; the verdict
  records are the evidence that the channel worked on a given day, and the
  close gate of this task reads them (≥2 PASS records, all six hops).
- **Rejected:** tracking everything (noise on every send; the ledger is
  append-only and would conflict across sessions); tracking nothing (the
  live proof would live only in scrollback — the exact state this slice
  exists to end).

### 2026-09-22 — ambient hops are informative, not blocking
- **Chose:** under `--ambient`, only H1 (ledger), H2 (hub has our message)
  and H6 (worker exited with DONE) decide the verdict; H3–H5 fold into `A1`.
- **Why:** whether an un-instructed model reads its inbox is a property of
  the model and the stanza, not of the transport. Letting it fail the
  transport verdict would make the check flap on model behaviour and hide
  real transport regressions behind it.
- **Rejected:** one blocking rule for both modes (conflates two questions);
  no ambient mode at all (the un-instructed answer is the arc's headline
  mechanic — it must be measurable, just separately).

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

### 2026-09-22T08:41:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3423-arc-011-sidecar-slice-9-fw-sidecar-e2e--.md
- **Context:** Initial task creation
