---
id: T-3065
name: "Watchtower session cookie is named for FW_PORT, not the port it is actually
  serving"
description: >
  Watchtower session cookie is named for FW_PORT, not the port it is actually serving

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
created: 2026-08-17T11:55:05Z
last_update: '2026-08-17T12:00:19Z'
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
  - ts: '2026-08-17T12:00:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-17T12:00:19Z'
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
---

# T-3065: Watchtower session cookie is named for FW_PORT, not the port it is actually serving

## Context

Reported upstream by the 832-Workflow-designer agent (thread
`aef-upstream-findings-2026-08-16` on `agent-chat-arc`, item 3), verified
independently against our own source before filing.

`web/app.py:89` names the session cookie after the port:

```python
app.config["SESSION_COOKIE_NAME"] = f"fw_session_{Config.PORT}"
```

`Config.PORT` is `int(os.environ.get("FW_PORT", "3000"))` — a class attribute
evaluated once at import (`web/config.py:80`). The `--port` flag is parsed into a
local (`web/app.py:476`, `port = args.port`) and handed to `run(...)` only. It is
never written back to `Config.PORT`. So an instance started as
`fw serve --port 3012` with no `FW_PORT` in the environment **serves on 3012 and
names its cookie `fw_session_3000`**.

Two instances on one host then share a cookie slot, which is the exact collision
the T-2278 comment above the line says this scoping prevents. Each app signs with
its own `.fw-secret-key`, so neither can decode the other's cookie: the session
reads empty, `_csrf_token` is `None`, and **every state-changing POST returns 403
"Session expired"** — on a freshly loaded page, with no restart. 832 measured this
between their `:3012` and a `:3000` instance; both emitted `fw_session_3000`.

Two things make this worse than an ordinary off-by-one:

1. **It presents as expiry, not as collision.** "Session expired" sends the
   operator to reload and re-auth — the two actions that cannot help, because
   nothing expired.
2. **The guard vouches for itself.** Lines 82-88 are six lines of comment
   asserting that per-port scoping is in place. In review, and in its own
   docstring, the protection reads as present. This is the §Watchtower Port
   failure class (T-1376, T-2732) on a new surface: a literal `3000` standing in
   for a port that was resolved elsewhere. Our own CLAUDE.md rule against
   hard-coding `:3000` exists because that literal was written 371 times across
   277 tasks; the resolution order it mandates (triple-file → `fw config get
   PORT` → 3000) is precisely what `Config.PORT` skips.

Scope fence: this task fixes the cookie name only. 832's items 1, 2, 4, 5 and 6
are separate defects and get their own tasks (§Task Sizing: one bug = one task).

## Acceptance Criteria

### Agent
- [x] The session cookie name is derived from the port the instance is actually
      serving on, so `fw serve --port N` (with no `FW_PORT` set) emits
      `fw_session_N` and not `fw_session_3000`.
- [x] `FW_PORT` and the default path are unchanged: with `FW_PORT=3007` and no
      flag the name is `fw_session_3007`; with neither, `fw_session_3000`.
- [x] A regression test pins the `--port` case specifically — the one the flag
      parser silently dropped — and fails against the pre-fix code (mutation
      check recorded in Updates, per L-616: a harness that passes on unfixed code
      is indistinguishable from no test).
- [x] The self-vouching comment at `web/app.py:82-88` is corrected: it must not
      assert per-port scoping in terms that were false for the `--port` path.

### Human

- [ ] [REVIEW] Watchtower's buttons still work in your actual browser after a
      restart, and you were not silently logged out of the instance you use.

  Renaming a cookie slot is the one change that cannot be fully proven from the
  command line: `curl` gets a fresh empty jar every time, so it can confirm which
  name the server *offers* but never what your existing browser session does with
  it. The live `:3000` instance keeps the name it already had (`FW_PORT` defaults
  to 3000, so nothing moved for it) — this AC is here to confirm that reasoning
  against a real browser rather than against my own argument.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` — open
     that URL in the browser you normally use for Watchtower.
  2. Click any button that changes state — an Approve on `/approvals`, or a
     driver action on `/arcs/<slug>`.
  3. If you also run a second instance started with `fw serve --port N`, open that
     one too and click a state-changing button there.

  **Expected:** the action completes. No "Session expired". No 403 toast. You are
  not asked to re-authenticate on the instance you were already using.

  **If not:** note which instance (port), whether you had an old tab open, and
  whether a hard reload clears it — a one-time logout on a `--port` instance is
  the intended consequence of the fix (its cookie name genuinely changed);
  a persistent 403 on `:3000` is not, and means reopening this task.

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

python3 -m pytest tests/unit/test_session_cookie_port.py -q > /tmp/.t3065 2>&1 && grep -q "6 passed" /tmp/.t3065
# The naming rule must have exactly one definition. A second f-string reintroducing
# Config.PORT is how this regresses, and it would read as correct in isolation.
test "$(grep -c 'f"fw_session_{' web/app.py)" = "1"
# The join main() owns: flag resolved, THEN cookie re-scoped.
grep -q 'apply_session_cookie_name(app, port)' web/app.py

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

## RCA

**Symptom:** every state-changing POST in Watchtower returns 403 "Session
expired", on a freshly loaded page, with no restart — whenever a second instance
runs on the same host. Measured by 832 between their `:3012` and a `:3000`
instance; both emitted `fw_session_3000`.

**Root cause:** `web/app.py` named the cookie from `Config.PORT`, which is
`FW_PORT`-or-`3000` read once at import. The `--port` flag is parsed into a local
and passed to `run()`; it was never written back. So the name tracked the
*configured* port and the socket tracked the *requested* one, and the two diverge
for every flag-started instance.

**Why structurally allowed:** three things compounded.

1. **T-2278 shipped a correct helper for one of its two callers.** The
   environment path was right; the flag path had no line at all. This is the
   producer/consumer split of L-399 in miniature — the guard existed, the second
   entry point did not honour it.
2. **The comment vouched for the guard.** Six lines above the defect assert that
   per-port scoping allocates a distinct slot per instance. Anyone reviewing the
   line reads the claim, not the coupling. `fw_session_{Config.PORT}` *looks*
   port-scoped; that it is scoped to the wrong port is invisible without chasing
   `Config.PORT` to `web/config.py:80`.
3. **The failure names the wrong cause.** "Session expired" routes the operator
   to reload and re-authenticate — the two responses that cannot work, because
   nothing expired. A collision that presents as expiry cannot be diagnosed from
   its own message, which is why it took a second project on the same host to
   find it rather than us.

The same shape is already written down: §Watchtower Port exists because `:3000`
was hard-coded 371 times across 277 tasks, and its whole point is that the port
must be *resolved*, never assumed. `Config.PORT` is that assumption wearing a
config lookup — it consults `FW_PORT` and then stops, so it is authoritative about
what was configured and silent about what is running. Both T-1376's false greens
and this defect come from a value that names a port without having asked which
port is live.

**Prevention:** `tests/unit/test_session_cookie_port.py`, six tests. Five drive
start-up in a clean subprocess (load-bearing: `Config.PORT` and the module-level
`app` are both one-shot per interpreter, so an in-process test would keep passing
after the coupling returned). The sixth asserts the join in `main()` — the leg the
other five structurally cannot see, since they mirror `main()`'s ordering rather
than running it. Mutation-checked both ways: reverting the helper to `Config.PORT`
killed 3 tests including both flag cases; deleting `main()`'s call killed exactly
the wiring test. Verification also pins that the naming rule has exactly one
definition, since a second `f"fw_session_{...}"` is how this comes back.

What this does *not* prevent: other values derived from `Config.PORT` drifting the
same way. Today there are only two consumers (this one and the flag's own
default), so the class is closed by inspection rather than by a rail — noted here
because that is true now and may not stay true.

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

**Recommendation:** GO

**Rationale:** The defect is confirmed at the wire, the fix is confirmed at the
wire, and the test that guards it has been shown to fail against the broken code
in both directions it can break. What remains is the one thing a command line
cannot reach — what a real browser with an existing cookie jar does — which is why
there is a Human AC rather than a fourth verification line. The blast radius is
small and bounded by inspection: `Config.PORT` has exactly two consumers in the
whole tree, and the other one is the flag's own default, where reading the
configured port is correct.

**Evidence:**
- Wire-level, pre-condition: `Config.PORT` = `FW_PORT`-or-3000 at import
  (`web/config.py:80`); `--port` reached only `run()` (`web/app.py:476`).
- Wire-level, post-fix: an instance serving `:3097` with `FW_PORT` unset emits
  `Set-Cookie: fw_session_3097`. Before the fix that byte string was
  `fw_session_3000` — the same slot as the live `:3000` instance.
- `tests/unit/test_session_cookie_port.py` — 6 passed.
- Mutation M1 (helper reverted to `Config.PORT`): 3 failed, including both
  flag-specific cases. Mutation M2 (`main()`'s call deleted — a correct helper
  wired nowhere, which is precisely the T-2278 shape): 1 failed, exactly the
  wiring test. Neither mutant survived, and each was killed by the test written
  for it.
- Live `:3000` instance verified still serving throughout; the throwaway instance
  was started with a direct `python3` invocation specifically so it could not
  write the Watchtower triple-file and re-point later port lookups at itself.
- Independent origin: reported by 832-Workflow-designer as item 3 of six upstream
  findings, then re-verified here against our own source before anything was
  changed. Their measurement (two instances, both `fw_session_3000`) and ours
  agree.

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

### 2026-08-17T11:55:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3065-watchtower-session-cookie-is-named-for-f.md
- **Context:** Initial task creation
