---
id: T-3407
name: "arc-011 sidecar slice 5: ambient consults — dispatch preamble + UserPromptSubmit
  hook surface a pending consult unasked"
description: >
  arc-011 sidecar slice 5: ambient consults — dispatch preamble + UserPromptSubmit
  hook surface a pending consult unasked

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [termlink, peer-consult, sidecar, cross-repo, hooks]
components: []
related_tasks: [T-3406, T-3405, T-3404, T-3402]
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
created: 2026-09-21T22:35:06Z
last_update: 2026-09-21T22:41:49Z
date_finished: 2026-09-21T22:41:49Z
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
  - ts: '2026-09-21T22:37:33Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=305,acs=11)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-21T22:37:33Z'
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

# T-3407: arc-011 sidecar slice 5: ambient consults — dispatch preamble + UserPromptSubmit hook surface a pending consult unasked

## Context

Slice 5 of the arc-011 peer-consult sidecar. Spec: `docs/reports/T-3396-peer-consult-sidecar-inception.md`.

**The gap this closes.** T-3406 proved the two-agent round trip — but the
responder had to be *told* `run fw sidecar inbox` in its prompt. A consult
that only reaches an agent who was instructed to look is not ambient, and
ambient is the difference between "a mechanism exists" and agents actually
consulting each other mid-work. This slice makes a pending consult surface
unasked, on both kinds of session.

**Two surfaces, because discovery showed they cannot share one.** Dispatched
workers spawn `--bare` — no CLAUDE.md, no hooks (`lib/resolver.py:143`). So a
hook is worthless to a worker; the only channel a worker sees is the prompt
`fw termlink dispatch` assembles. Interactive sessions do run hooks, and
`UserPromptSubmit` fires at the one moment a human is already waiting for a
turn — cheap, cannot loop, and naturally rate-limited. `Stop` was ruled out
in T-3406: it routes to arc-012's continuous-run driver, which audit flags as
cycling on a stale terminate reason. This slice does not touch it.

**Design constraints carried in, not invented.** The hook must *peek*, never
consume: surfacing is not reading, and a consult consumed by a hook the agent
then ignores would vanish from `fw sidecar inbox`. It must fail open and fast
— a hub that is down must cost the turn nothing and print nothing. The
worker's addressable id must be its dispatch `--name`, so a consult sent to
that name lands in that worker's inbox without a second naming scheme. The
docs home is the preamble's existing arc-011 Yield Point section, which
already says "multi-host arc M2 introduces a sidecar".

**Scope fence.** Out: the `Stop` hook (arc-012 coupling), the liveness
self-probe daemon, and the OBS-447 retry-policy ruling — the peek hook
neither retries nor acks, so it prejudges nothing.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A `fw hook sidecar-inbox` handler exists that runs `fw sidecar inbox --peek --json` and emits `{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": ...}}` when there are pending consults, and emits NOTHING (empty stdout, exit 0) when there are none — `agents/context/sidecar-inbox.sh`; bats 1 (empty → no stdout) and 2 (pending → additionalContext with sender, conversation, body)
- [x] The handler fails open: a hub that is unreachable, a missing `termlink` binary, or a timeout produces empty output and exit 0, never an error the user sees and never a blocked prompt — bats 4 (fw exit 1), 5 (malformed JSON), 6 (hung fw cut by `SIDECAR_INBOX_TIMEOUT`), 7 (no termlink on PATH → fw never even called)
- [x] The handler peeks and does not advance the cursor: after it fires, `fw sidecar inbox` still returns the same consult (surfacing ≠ consuming) — bats 3 asserts every `fw` call carried `--peek`; live: after the hook fired on the T-3407-live probe, `fw sidecar inbox --peek` still returned it at @2
- [x] `UserPromptSubmit` is wired in `.claude/settings.json` to the handler with a short timeout, and `bin/fw enforcement baseline` is refreshed so `fw doctor` does not report a changed baseline (L-398) — wired via the governed verb after B-005 refused a hand-edit (`bin/fw hook-enable --name sidecar-inbox --event UserPromptSubmit --matcher ''` → `registered: UserPromptSubmit/'' -> ${CLAUDE_PROJECT_DIR}/bin/fw hook sidecar-inbox`, timeout 8); `bin/fw enforcement baseline` → hash `aed641a399cf431a…` saved
- [x] `fw termlink dispatch` prepends a short consult-inbox stanza to every worker prompt, and sets `FW_SIDECAR_AGENT_ID` to the worker's `--name` in the worker's environment — `agents/termlink/termlink.sh:cmd_dispatch`, `bash -n` clean. Direct evidence from the live worker's dir: `/tmp/tl-dispatch/ambient-responder/prompt.md` begins `[PEER CONSULTS — arc-011 sidecar, T-3407] You are addressable as agent id 'ambient-responder'…`; `env.sh` contains `export FW_SIDECAR_AGENT_ID=ambient-responder`
- [x] `agents/dispatch/preamble.md`'s Yield Point section documents the worker contract and how a consult surfaces in an interactive session — new subsection "Peer consults at the yield point (T-3407)", placed under the existing M2 note that anticipated the sidecar
- [x] **Live gate, interactive:** queued a consult to this agent (`T-3407-live`, @2); `bin/fw hook sidecar-inbox < /dev/null` emitted the `UserPromptSubmit` `additionalContext` JSON carrying it, exit 0; `fw sidecar inbox --peek` afterward still showed @2. **Then the real thing:** on this session's very next turn, the wired hook fired on its own and injected the *worker's* answer (below) into my context as `UserPromptSubmit hook additional context` — I did not ask for it. That is the ambient property, demonstrated on the live session rather than by calling the script
- [x] **Live gate, worker:** queued a consult to `ambient-responder` (`client_msg_id 1f2a23e7-b86b-4fd5-8f66-0cec6f63f9e2`, conversation `T-3407-worker`), then dispatched a worker whose entire prompt was *"print the current UTC date on one line, then stop"* — no mention of an inbox. It found the consult through the dispatch-prepended stanza alone and answered. Received at **`sidecar:999-Agentic-Engineering-Framework` offset 3, from `ambient-responder`**, ~20s after dispatch. Verbatim: *"In 'ambient consult', 'ambient' means the consult arrives passively in the background of whatever task the agent is already doing, rather than being explicitly requested or blocking its work."*
- [x] Unit tests cover the empty/non-empty/fail-open handler paths and the peek invariant; slices 1-4 suites still pass unchanged — `tests/unit/sidecar_inbox_hook.bats` **7/7** (one test fixed mid-task: it removed the sandbox `termlink` but the real one at `/usr/local/bin` stayed on PATH, so the presence check passed — the test's fault, not the hook's; PATH now excludes it); pytest slices 1-4: **28 passed**

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

out=$(python3 -m pytest tests/unit/test_sidecar_inbox.py tests/unit/test_sidecar_termlink_transport.py tests/unit/test_sidecar_delivery.py tests/unit/test_sidecar_outbox.py -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
timeout 300 bats tests/unit/sidecar_inbox_hook.bats > /tmp/.t3407-bats 2>&1 && ! grep -q "^not ok" /tmp/.t3407-bats
test "$(grep -c '# skip' /tmp/.t3407-bats)" -eq 0
jq -e '.hooks.UserPromptSubmit[0].hooks[0].command | test("sidecar-inbox")' .claude/settings.json
bin/fw vendor self --check
bash -n agents/termlink/termlink.sh
# Worker live-gate evidence pinned to a fixed envelope, not a live count (T-3326): offset 3 of this agent's inbox topic is the un-instructed worker's reply.
termlink channel state sidecar:999-Agentic-Engineering-Framework --json > /tmp/.t3407-topic 2>&1 && grep -q '"offset": 3' /tmp/.t3407-topic && grep -q "passively in the background" /tmp/.t3407-topic

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

### 2026-09-21 — two gates refused me, both correctly, and the second one improved the design
- **What changed (B-005):** I hand-edited `.claude/settings.json` to add the `UserPromptSubmit` block and the enforcement-config gate refused it, naming `fw hook-enable`. The verb validated the event name, wrote atomically, and the entry survives `fw upgrade` regeneration — none of which my hand edit would have done. The refusal was the better outcome.
- **What changed (G-020 ×2, read-only false positives):** the build-readiness gate blocked a `python3 -c "json.load(...)"` survey and a `grep` whose *pattern* contained `export .*NAME`. Neither wrote anything; the gate said so itself. Recorded as an OBS under this task — the hazard is not the two minutes lost, it is that an agent learns to route around the gate by avoiding words. The fix was the intended one: write real ACs first.
- **What changed (a test lied green-then-red):** bats 7 removed the sandbox `termlink` but the real binary stayed on PATH. The hook was right; the test was. Fixed the test's PATH, with the reason in a comment.
- **What the live gate added that no unit test could:** the ambient property was verified *on this session* — the wired hook fired on my own next turn and injected the worker's reply as context without being invoked. A scripted call of the handler proves the handler; the hook firing on the harness's turn boundary proves the wiring.
- **Plan impact:** none — scope fence held. `Stop` untouched (arc-012 coupling).
- **Surfaced, not fixed here:** every dispatched worker now runs `fw sidecar inbox` at yield points. That is one `termlink channel subscribe` per yield point per worker; at five concurrent workers it is negligible, at fifty it is a hub load question. Not measured; noted so it is a number someone measures rather than an assumption.

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

### 2026-09-21T22:35:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3407-arc-011-sidecar-slice-5-ambient-consults.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-455982a6
- **Timestamp:** 2026-09-21T22:41:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-21T22:41:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
