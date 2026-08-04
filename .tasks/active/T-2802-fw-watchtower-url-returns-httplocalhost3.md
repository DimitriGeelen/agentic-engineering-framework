---
id: T-2802
name: "fw watchtower url returns http://localhost:3000 from a NON-project directory
  (no triple-file, no fw_config) -- the documented last-resort fallback. Hazard: on
  this host :3000 is ANOTHER project's Watchtower (832's), and consumer projects run
  the same Flask app, so an onboarding agent that captures this URL at Step 2 and
  curls it at Step 5 gets 200 from a foreign server -- the exact T-2732/T-2734 false-green
  class (371 verification lines). Observed live 2026-08-04 during fresh-install onboarding
  in /opt/2345-test-install. Question: should 'fw watchtower url' return a URL at
  all when no project is resolved, or refuse with a message naming the ambiguity?
  Silent fallback to a well-known port is a wrong-object answer wearing a valid-looking
  shape."
description: >
  Promoted from observation OBS-158

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
created: 2026-08-04T20:54:48Z
last_update: 2026-08-04T22:07:51Z
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
  - ts: '2026-08-04T21:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-04T21:00:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2802: fw watchtower url returns http://localhost:3000 from a NON-project directory (no triple-file, no fw_config) -- the documented last-resort fallback. Hazard: on this host :3000 is ANOTHER project's Watchtower (832's), and consumer projects run the same Flask app, so an onboarding agent that captures this URL at Step 2 and curls it at Step 5 gets 200 from a foreign server -- the exact T-2732/T-2734 false-green class (371 verification lines). Observed live 2026-08-04 during fresh-install onboarding in /opt/2345-test-install. Question: should 'fw watchtower url' return a URL at all when no project is resolved, or refuse with a message naming the ambiguity? Silent fallback to a well-known port is a wrong-object answer wearing a valid-looking shape.

## Context

`bin/watchtower.sh:do_url` ends in `echo "http://localhost:$(fw_config PORT 3000)"`
— a guess, emitted in the same shape as a verified answer. `lib/watchtower.sh`'s
`_watchtower_url` was hardened against exactly this in T-1803 (Layer 3: "fail
loud, never return a URL to a service we didn't positively identify"); the CLI
accessor `fw watchtower url` was not, and it is the one CLAUDE.md tells agents to
put inside `## Verification` blocks.

On this host `:3000` belongs to **another project's** Watchtower, and consumer
projects run the same Flask app — so the guess returns 200 for almost any path.
That is the T-2732/T-2734 false-green class, which reached 371 verification lines
before anyone noticed, because a green line that asserts nothing looks exactly
like one that asserts everything.

Observed live 2026-08-04 during fresh-install onboarding in
`/opt/2345-test-install` (OBS-158): the agent captured the URL at Step 2 and
curled it at Step 5.

**Correction, made during the work.** This task was filed as "returns
`http://localhost:3000` from a NON-project directory", and I initially added a
guard for `PROJECT_ROOT` being empty — reasoning that `URL_FILE` would then be
`/.context/working/watchtower.url`, and `/.context` exists on this host (OBS-152).
The test written for it failed, which is how the claim got checked:
`lib/paths.sh:39-46` always falls back to `FRAMEWORK_ROOT`, so `PROJECT_ROOT` is
**never** empty for this entry point and the guard was unreachable.

The hazard is real; the mechanism in the title is not. It is the port guess
alone — a project *is* resolved, no Watchtower of its own is running, and the
well-known port is answered by someone else's. Guard removed rather than shipped
as dead code with a hazard comment attached to it.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw watchtower url` never emits a URL it has not positively identified as
      this project's Watchtower — the last-resort `http://localhost:<PORT>` guess
      is gone
- [x] When it cannot identify one it exits non-zero and the message **names which
      ambiguity** it hit: nothing listening, or a foreign service holding the port
- [x] The refusal names **which project** it was asked about — on a multi-project
      host that is half the answer
- [x] `fw watchtower port` still answers — a port is configuration, not a claim
      that a server is there (non-vacuity for the split)
- [x] Happy path unchanged: with Watchtower running,
      `curl -sf "$(bin/fw watchtower url)/"` still succeeds
- [x] Regression test covers nothing-listening → refusal, foreign holder →
      foreign-specific refusal, triple-file → URL, and `WATCHTOWER_URL` → URL

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

out=$(bats tests/unit/watchtower_url_no_guess.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n bin/watchtower.sh
# The guess is gone from the source, not just unreached by the tests.
! grep -qE 'echo "http://localhost:\$p"' bin/watchtower.sh
# Happy path: this repo's Watchtower is running, so the accessor must still answer.
url=$(bin/fw watchtower url) && curl -sf "$url/" -o /dev/null
cmp -s bin/watchtower.sh .agentic-framework/bin/watchtower.sh

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## Recommendation

**Recommendation:** GO — close as work-completed.

**Rationale:** Six Agent ACs verified, including a live demonstration of the
defect being prevented. `owner: human` is the `fw note promote` default; no Human
AC was identified for this task.

**Evidence:**

- Live, from a project with no Watchtower of its own, the refusal named the
  actual foreign holder: `Identity reported: {"project_root":
  "/opt/832-Workflow-designer","service":"watchtower",…}` — exactly the server
  OBS-158 predicted an onboarding agent would curl and get 200 from.
- `tests/unit/watchtower_url_no_guess.bats` — 6/6, covering both refusal
  branches and both legitimate-answer branches.
- Happy path unaffected: `bin/fw watchtower url` → `http://192.168.10.107:3001`,
  rc 0.
- `bin/fw watchtower port` → `3001`, rc 0 — the split holds.

**Two things to carry forward:**

- **OBS-160** — four callers (`lib/verify-acs.sh:74`, `lib/arc.sh:680`, `:802`,
  `:1046`) do `|| echo "http://localhost:3000"`, converting this refusal straight
  back into the guess. `lib/verification-port.sh:25` shows the anti-pattern in a
  doc comment as the example idiom. Producer/consumer parity class (L-399).
- The title's stated mechanism was wrong; see the correction in Context.

## RCA

**Symptom.** `fw watchtower url` returned `http://localhost:3000` for a project
that had no Watchtower running. On this host that port is
`/opt/832-Workflow-designer`'s Watchtower, and because consumer projects run the
same Flask app it answers 200 for almost any path — so a `## Verification` line
built on that URL passes without asserting anything about the project it is
supposed to be testing.

**Root cause.** `do_url`'s final branch (`bin/watchtower.sh`) emitted a
configured-port guess in the same shape as a verified answer. Nothing downstream
can tell the two apart: both are a string starting `http://`.

**Why structurally allowed.** The identical defect was fixed in T-1803 — but in
`lib/watchtower.sh`'s `_watchtower_url`, whose Layer 3 is explicitly "fail loud,
never return a URL to a service we didn't positively identify". The CLI accessor
`fw watchtower url` is a *different function in a different file* that answers the
same question, and it was not updated. Two implementations of one predicate, one
hardened and one not — the T-2735/T-2737 fabric-denominator shape.

That the un-hardened one is the shell-facing accessor is what made it costly:
CLAUDE.md tells agents to write `curl -sf "$(bin/fw watchtower url)/page"` in
Verification blocks, so the guessing implementation is the one governance
routes agents to.

**Prevention.** The guess is deleted, not demoted — `do_url` now returns non-zero
and explains which of the two states it is in (nothing listening → `fw serve`;
foreign holder → pick another port, and do not curl that one). Pinned by
`tests/unit/watchtower_url_no_guess.bats`, whose first assertion in each refusal
test is that the old URL string is *absent* from the output, so a reintroduction
fails loudly.

**Not fixed here (OBS-160).** Four callers re-add the guess on the consumer side.
The refusal is only as strong as the callers that propagate it.

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

### 2026-08-04T20:54:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2802-fw-watchtower-url-returns-httplocalhost3.md
- **Context:** Initial task creation

### 2026-08-04T22:07:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
