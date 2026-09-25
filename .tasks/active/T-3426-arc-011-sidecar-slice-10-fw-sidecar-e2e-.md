---
id: T-3426
name: "arc-011 sidecar slice 10: fw sidecar e2e --peer <agent-id> — two-party live
  check against a real peer agent (TermLink), hub-verified both ways"
description: >
  arc-011 sidecar slice 10: fw sidecar e2e --peer <agent-id> — two-party live check
  against a real peer agent (TermLink), hub-verified both ways

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
created: 2026-09-22T10:11:39Z
last_update: 2026-09-25T11:08:36Z
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
  - ts: '2026-09-22T10:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=295,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T10:15:19Z'
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

# T-3426: arc-011 sidecar slice 10: fw sidecar e2e --peer <agent-id> — two-party live check against a real peer agent (TermLink), hub-verified both ways

## Context

Slice 9 (T-3423) proved the sidecar end to end against a worker WE
dispatch. The operator's ask now is the other half: prove it against a
real peer agent we do not control — TermLink's own session — so both
sides of the seam are exercised by one mechanical check, and TermLink can
run the mirror image against us.

**`fw sidecar e2e --peer <agent-id>`.** Same harness, three differences:
the consult goes to the named peer's topic instead of a dispatched
responder; nothing is dispatched, so H3 (worker read its inbox) and H6
(worker exit) are peer-owned and reported as not applicable; the consult
body is a human-readable request ("reply on this conversation to <sender>
with SIDECAR-E2E-ACK <run>") because the reader is an agent following its
own inbox discipline, not a prompt we wrote. Blocking hops become H1 (our
ledger), H2 (the peer's topic holds our client_msg_id), H4 (the sender
topic holds the peer's answer on our conversation) and H5 (our inbox
surfaces it). The sender stays a throwaway id so the run never consumes
the session's real inbox. Timeouts are long by default (30 min, 15 s
polls): a peer answers when it next reads, not when we poll.

**Joint protocol with TermLink**, posted on agent-chat-arc: we run
`--peer 010-termlink`; they answer the consult; we post the hop table with
their topic offsets; they run their notify-rail prover (T-3061) or a
consult of their own against `sidecar:999-Agentic-Engineering-Framework`,
and we answer it through the same path. Two-party, both directions.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/sidecar/e2e.py`: `Config.peer`; `responder` = peer; `mode` = peer; `consult_body()` is the readable request (run id, ACK token, sender id, conversation id, both reply forms); in `run()` the dispatch block is skipped, H3/H6 recorded `not applicable: <peer> owns …`, `blocking_hops()` = H1,H2,H4,H5; `render()` prints `n/a` for those rows. Also (TermLink @1640 meet-point 2) every consult now carries `metadata.cv_key=<client_msg_id>` so `channel cv-keys` is an O(1) H2 path — transport test pins it
- [x] `fw sidecar e2e --peer <id> [--timeout] [--poll]`: defaults 1800 s / 15 s with `--peer`, 300 s / 5 s otherwise; `--ambient --peer` → exit 2 before any send; report carries `mode: peer`, `peer: <id>`
- [x] `tests/unit/test_sidecar_e2e.py` +3: peer full pass (no dispatch, H3/H6 n/a, PASS on H1/H2/H4/H5, `n/a` in render); peer never answers (H4/H5 FAIL only, verdict FAIL, nothing dispatched); CLI refuses `--ambient --peer`. **12/12; sidecar suites 47/47**
- [ ] **Live, two-party — first window closed FAIL, record kept:** run `ab947312` (`.context/sidecar/e2e/ab947312.json`, committed): H1 PASS, H2 PASS (our consult on `sidecar:010-termlink` @1), H4/H5 FAIL — no answer from 010-termlink within 1802 s (their session had not read the topic in the window; not a transport fault: H2 proves the hub holds it). Re-run on their signal per the resume note below. Originally: sent 10:20Z — H1 our ledger INJECTED_NOW; H2 the consult is on `sidecar:010-termlink` @1 (client_msg_id in RPC param + metadata + cv_key, conversation `e2e-ab947312`, from `e2e-ab947312-sender`); the request with the one-line reply command posted to TermLink on agent-chat-arc @1651 and on their DM thread @8. Harness window closes ~10:50Z. **Outcome to record on resume:** read `.context/sidecar/e2e/ab947312.json` — if H4/H5 PASS, tick with their offsets; if FAIL (no answer in the window), keep the record, and when TermLink signals they read it re-run `bin/fw sidecar e2e --peer 010-termlink --task T-3426` and record that run. Their mirror (a consult to `sidecar:999-Agentic-Engineering-Framework`) answers itself through the T-3407 hook
- [x] Vendored `lib/sidecar/e2e.py`, `lib/sidecar_cli.py`, `lib/sidecar/termlink_transport.py` synced (VERSION 1.6.783); `bin/fw vendor self --check` → "in sync with source"; all seven sidecar suites **47/47**

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

python3 -m pytest tests/unit/test_sidecar_e2e.py tests/unit/test_sidecar_termlink_transport.py tests/unit/test_sidecar_sweep.py tests/unit/test_sidecar_status.py tests/unit/test_sidecar_inbox.py tests/unit/test_sidecar_delivery.py tests/unit/test_sidecar_outbox.py -q > /tmp/.t3426-py 2>&1 && grep -q passed /tmp/.t3426-py && ! grep -q failed /tmp/.t3426-py
bin/fw sidecar e2e --help > /tmp/.t3426-h 2>&1 && grep -q -- "--peer" /tmp/.t3426-h
# --ambient with --peer is refused before any send (exit 2).
bin/fw sidecar e2e --peer x --ambient --task T-0 > /tmp/.t3426-amb 2>&1; test $? -eq 2
# A peer-mode record exists for 010-termlink with H1 and H2 both ok (our send landed on their topic) — the invariant this slice owns; H4/H5 are the peer's answer.
python3 -c "import json,glob,sys; rs=[json.load(open(p)) for p in glob.glob('.context/sidecar/e2e/*.json')]; ok=[r for r in rs if r.get('mode')=='peer' and r.get('peer')=='010-termlink' and r['hops']['H1']['ok'] and r['hops']['H2']['ok']]; sys.exit(0 if ok else 1)"
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

### 2026-09-22T10:11:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3426-arc-011-sidecar-slice-10-fw-sidecar-e2e-.md
- **Context:** Initial task creation

### 2026-09-22 17:05Z — second and third two-party windows (parent session, autonomous run)
- **Run `8dbad116`** (issued by T-3433's worker on the NEW `inbox:cacc73ea32b121dd/010-termlink`
  address, committed under T-3433): H1 PASS, H2 PASS (3 envelopes carrying our client_msg_id on
  their inbox — the T-3434 ladder re-posted twice inside the window), H4/H5 FAIL — no ACK on our
  conversation within 30 min. Same shape as `ab947312` on the old address: our hops close, theirs
  stay open.
- **Re-run for this task at 16:47Z** on the new address: killed at ~17:03Z by the session
  harness's low-memory guard before any record was written (host had 25 GB available of 64 GB;
  the guard fired on its own threshold). No record file, nothing to commit. The consult it posted
  will be re-posted by the ladder until acked, which TermLink will see as a repeated e2e question.
- **Asks outstanding to TermLink:** agent-chat-arc @1671 and a real sidecar consult on the new
  address (client_msg_id a8717ecc, INJECTED_NOW): confirm their subscriber wakes on `inbox.queued`
  for `inbox:cacc73ea32b121dd/010-termlink`, then answer the next `--peer` run. No reply as of
  17:05Z on our inbox or the chat.
- **Status of the last AC:** blocked on the peer, not on this repo. Nothing more can be done from
  this side except re-issuing the run once they signal; not re-issued blind again this run.
