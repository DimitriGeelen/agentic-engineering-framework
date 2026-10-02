---
id: T-3693
name: "arc-011 sidecar S1 (finish): T-3561 closed falsely — wire Stop/UserPromptSubmit
  ready-flag hooks, fw sidecar receiver start/stop, session injection, and a REAL
  two-session nonce e2e (the closed test writes agent B's reply itself)"
description: >
  Verified 2026-10-02 against T-3561's own ACs: tests/unit/t3561_e2e_nonce.py stores
  the transformed-nonce reply itself (no agent B, no HTTP, no injection); .claude/settings.json
  has no new Stop or UserPromptSubmit handler; lib/sidecar/adapter.py and receiver.py
  contain no injection code; no CLI starts the receiver process. Built and kept: receiver.py
  storage+flag, lifecycle.py triple-file, http_server.py bearer token, HUB_ACCEPTED
  rename. Remaining = T-3561 AC3, AC5 (sender sees each state via the real path),
  AC7, AC8 as written. Close requires an independent different-vendor review (codex)
  confirming the e2e involves two real agent sessions.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [sidecar, arc-011, design-conformance, T-3682, false-completion]
arc_id: arc-011
components: [agents/audit/audit.sh, agents/task-create/update-task.sh, bin/claude-fw, bin/fw, C-009, lib/design_register.py, lib/init.sh, lib/sidecar/adapter.py, lib/sidecar_cli.py, lib/sidecar/direct.py, lib/sidecar/hooks.py, lib/sidecar/http_server.py, lib/sidecar/inject.py, lib/sidecar/lifecycle.py, lib/sidecar/receiver.py, tests/unit/t3561_adapter.py, tests/unit/t3561_e2e_nonce.py, tests/unit/t3561_receiver_storage.py, web/blueprints/approvals.py, web/templates/_approvals_content.html]
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
created: 2026-10-01T23:22:03Z
last_update: 2026-10-02T11:20:57Z
date_finished: 2026-10-02T11:20:57Z
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
  - ts: '2026-10-01T23:24:43Z'
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
  - ts: '2026-10-01T23:30:20Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=279,acs=12)
    rubric_sha: e4a00f38e801
---

# T-3693: arc-011 sidecar S1 (finish): T-3561 closed falsely — wire Stop/UserPromptSubmit ready-flag hooks, fw sidecar receiver start/stop, session injection, and a REAL two-session nonce e2e (the closed test writes agent B's reply itself)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw sidecar receiver start` starts HTTP server, writes triple-file (pid/port/url), and stores auth token (0600) on disk; `status` reports running with correct pid/port; `stop` cleanly terminates and removes triple-file
- [x] Stop hook (agents/context/stop-driver.sh counterpart) sets ready-for-input=true when turn ends; UserPromptSubmit hook clears it FIRST, then surfaces pending messages
- [x] Hook registration in .claude/settings.json: both Stop and UserPromptSubmit handlers exist, call adapter functions, and survive `bin/fw enforcement baseline`
- [x] When a message is pending and agent is ready, receiver process injects ONE line into agent's TermLink session (via `termlink pty inject`); HANDED_OVER is recorded in the receiver ledger only when the prompt hook has actually surfaced the message — never on the queue write or the inject alone
- [x] Real end-to-end test: Agent A (actual Claude session) generates nonce, sends via HTTP API; Agent B (actual Claude session registered in TermLink) never mentions message in prompt, replies with transformed nonce; only assertion is transformed nonce in A's context
- [x] Negative control: with injection disabled, same test FAILS; sender sees ESCALATED not silence/success
- [x] Sender ledger records state transitions (SENT → RECEIVED → HANDED_OVER → REPLIED) via API responses; each state recorded only by party that can know it
- [x] Non-success paths tested: UNDELIVERABLE (receiver down, retry budget spent), REJECTED (bad auth token, never injected), ESCALATED (HANDED_OVER deadline missed)
- [x] All tests pass: `python3 -m pytest tests/integration/t3693_*.py -v` (real e2e and negative control); unit tests `pytest tests/unit -k sidecar -q`
- [x] Vendor self-check clean: `bin/fw vendor self --check` passes; enforcement baseline refreshed; `bats tests/lint/` clean on hook syntax

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

# Unit: receiver CLI, hooks, injection, sender ledger, non-success paths (real receiver processes, real HTTP)
python3 -m pytest tests/unit/test_sidecar_receiver_t3693.py tests/unit/t3561_adapter.py tests/unit/t3561_receiver_storage.py -q > /tmp/.t3693-unit 2>&1 && grep -q " passed" /tmp/.t3693-unit && ! grep -qE "failed|skipped" /tmp/.t3693-unit
python3 -m pytest tests/unit -k sidecar -q > /tmp/.t3693-sidecar 2>&1 && grep -q " passed" /tmp/.t3693-sidecar && ! grep -q "failed" /tmp/.t3693-sidecar
# LIVE: two real claude-fw --termlink sessions + negative control (~6 min). Must RUN, not skip.
timeout 1500 python3 -m pytest tests/integration/t3693_sidecar_e2e_test.py -v > /tmp/.t3693-e2e 2>&1 && grep -q "3 passed" /tmp/.t3693-e2e && ! grep -qE "SKIPPED|skipped|failed" /tmp/.t3693-e2e
# Registration: Stop keeps stop-driver.sh and adds the receiver hook; UserPromptSubmit keeps sidecar-inbox and adds the adapter; consumer template too
python3 -c "import json;h=json.load(open('.claude/settings.json'))['hooks'];c=lambda e:[x['command'] for g in h[e] for x in g['hooks']];s=c('Stop');u=c('UserPromptSubmit');assert any('stop-driver.sh' in x for x in s) and any(x.endswith('hook sidecar-receiver-ready') for x in s);assert any(x.endswith('hook sidecar-inbox') for x in u) and any(x.endswith('hook sidecar-receiver-adapter') for x in u)"
grep -q 'hook sidecar-receiver-ready' lib/init.sh && grep -q 'hook sidecar-receiver-adapter' lib/init.sh
out=$(bin/fw enforcement status 2>&1); echo "$out" | grep -q "Baseline set" && ! echo "$out" | grep -qi "baseline changed"
timeout 600 bats tests/lint/ > /tmp/.t3693-lint 2>&1 && ! grep -q "^not ok" /tmp/.t3693-lint
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

### 2026-10-02 — haiku workers could not build this; the route cache chose them
- **What changed:** The first T-3693 worker ran on haiku (the dispatch route cache's pick, T-3709). It built the CLI and the hooks, then stopped at injection and the real e2e. The T-3561 predecessor, also on haiku, had faked the e2e. Re-dispatched on opus, the slice was built as designed.
- **Plan impact:** None to scope. The design held as written: HTTP receiver, Stop/UserPromptSubmit ready flag, one-line TermLink inject, transcript-evidenced HANDED_OVER.
- **Triggered:** T-3709 (route cache model choice).

### 2026-10-02 — HANDED_OVER needed transcript evidence bound to the surfacing attempt
- **What changed:** The live e2e found a false HANDED_OVER: the hook recorded hand-over before the message was provably in front of the agent. Codex rounds 2 and 3 tightened this. HANDED_OVER is now finalised only against a transcript header for the exact surfacing attempt (53891a246), and the sender ledger is monotonic (dafbca068).
- **Plan impact:** "Surfaced" is a transcript fact, not a hook return value.
- **Triggered:** Nothing new. Codex round 4 PASS. The live e2e re-run by the parent gave 3/3.

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

### 2026-10-02 — AC4 wording corrected to the operator directive
- **Chose:** AC4 now reads "HANDED_OVER is recorded only when the prompt hook has actually surfaced the message — never on the queue write or the inject alone". The previous worker had written "on success [of the inject], records HANDED_OVER".
- **Why:** the operator directive for this task says "HANDED_OVER is recorded only when the hook has actually surfaced the message (never on queue write or inject alone)", and T-3561 AC3 says "a queue write alone never counts as HANDED_OVER". A keystroke reaching a PTY is not a message reaching an agent. The injector records INJECT_ATTEMPT instead.
- **Rejected:** ticking the old wording as written. That would have meant either building the wrong thing or ticking a criterion that is false.

### 2026-10-02 — registered-but-down receiver vs hub fallback
- **Chose:** no receiver registered for the name (never started, or stopped cleanly, which unregisters) → hub topic fallback. A receiver that is registered but unreachable (crashed or restarting) → retry budget, then UNDELIVERABLE.
- **Why:** UNDELIVERABLE ("receiver down, retry budget spent", T-3561 AC6) has to be reachable, and silently rerouting a crashed peer's mail to a hub topic it is not reading would hide the failure.
- **Rejected:** always falling back to the hub when the receiver is down. UNDELIVERABLE could then never be produced.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-01T23:22:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3693-arc-011-sidecar-s1-finish-t-3561-closed-.md
- **Context:** Initial task creation

### 2026-10-01T23:24:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-df9fdb24
- **Timestamp:** 2026-10-02T11:32:16Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — Stop hook (agents/context/stop-driver.sh counterpart) sets ready-for-input=true when turn ends; UserPromptSubmit hook clears it FIRST, then surfaces pending messages
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/context/stop-driver.sh in: Stop hook (agents/context/stop-driver.sh counterpart) sets ready-for-input=true when turn ends; UserPromptSubmit hook clears it FIRST, then surfaces p`

### 2026-10-02T11:20:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
