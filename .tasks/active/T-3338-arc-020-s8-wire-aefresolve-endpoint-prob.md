---
id: T-3338
name: "arc-020 S8: wire aef_resolve endpoint-probe seam to live termlink probes (G3
  self-heal)"
description: >
  arc-020 S8: wire aef_resolve endpoint-probe seam to live termlink probes (G3 self-heal)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:arc-020]
components: []
related_tasks: [T-3335, T-3336]
arc_id: arc-020
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
created: 2026-09-07T15:36:38Z
last_update: '2026-09-07T15:45:09Z'
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
  - ts: '2026-09-07T15:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=318,acs=8)
    rubric_sha: e4a00f38e801
---

# T-3338: arc-020 S8: wire aef_resolve endpoint-probe seam to live termlink probes (G3 self-heal)

## Context

arc-020 S3 (`lib/aef_resolve.py`) climbs the 5-rung address ladder (agent→session→
project→hub→host) calling an injectable `probe(addr) -> bool` per rung — True = rung
exists, False = definitively absent, **RAISE = world unknowable (INDETERMINATE)**. The
raise/return-False distinction is the D4-A death-test: an unreachable world must never be
reported as a not-found, or provisioning would smuggle timeout-death back in. Until now
the only probe wired is `_default_path_exists` (project rung, filesystem). This task adds a
**live termlink-backed probe** — the endpoint-probe seam — that dispatches per deepest-
present rung to the real termlink binary, serving **G3** (a dropped circuit is *detected*
so it can self-heal). Design: `docs/reports/T-3287-identity-taxonomy-circuit-model.md`.

**Verb shapes localised against the live binary (the claim-backend grammar-surprise lesson
— T-3335 Decisions):**
- session rung → `termlink ping <session> --json` (liveness; `--timeout` guards).
- hub rung, local → `termlink hub status --json` → `{"ok":true,"status":"running",...}`.
- hub rung, remote host → `termlink hub probe <host>` (TLS handshake, leaf-cert sha256).
- host rung → reachability via `hub probe` / net-test (host is the one rung provisioning
  may only ask, never invent — D5).
- project rung stays on the existing `path_exists` seam (out of endpoint-probe scope).

Same adapter shape as the T-3335 claim-backend: an injectable `invoke` (default = subprocess
over `termlink`, reusing `default_termlink_invoke`), fake-invoke unit tests (no live hub),
one live smoke `[REVIEW]`.

## Acceptance Criteria

### Agent
- [x] `lib/aef_resolve.py` exposes a `termlink_probe(invoke=None, *, timeout=...)` factory returning a `probe: Callable[[AEFAddress], bool]` that dispatches per deepest-present rung field (session→ping, hub→hub status/probe, host→reachability) to live termlink verbs via the injectable `invoke` (default subprocess invoker, same pattern as `aef_election.default_termlink_invoke`).
- [x] The probe returns `True` for a present rung and `False` for a definitively-absent one, and **RAISES `ResolveIndeterminate`** (never returns False) when `invoke` errors/times out — so `resolve()` yields INDETERMINATE, not NOT_FOUND, on an unreachable world (D4-A death-test preserved).
- [x] The rung→verb dispatch is deterministic and total over the rung kinds it owns (session, hub, host); an unhandled/empty rung raises rather than silently returning False.
- [x] `tests/unit/test_aef_resolve_termlink.py` covers exists / absent / indeterminate for each owned rung kind via a fake invoke (no live hub), and the existing `tests/unit/test_aef_resolve*.py` stay green.
- [x] `bin/fw vendor self --check` clean (lib/ is vendored).

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
- [ ] [REVIEW] Live wire-level smoke of the endpoint-probe against a running local hub — the G3 self-heal foundation. A durable session that IS running probes True; a bogus session id probes False; with the hub stopped (or an unreachable remote host), the probe RAISES indeterminate rather than reporting False. This proves the probe distinguishes "gone" from "unreachable" on real termlink — the distinction the self-heal (reconnect vs. give-up) rests on.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && termlink hub status --json 2>&1 | head` — confirm a hub is running (if not: `termlink hub start`).
  2. `cd /opt/999-Agentic-Engineering-Framework && python3 tests/manual/s8_probe_smoke.py` (the smoke script committed with this task).
  **Expected:** Output shows a live session → `exists`, a bogus session → `absent`, and a hub-down/unreachable path → `INDETERMINATE (raised)`.
  **If not:** Capture the script output + `termlink list --json`; note whether the miss was a real absence or a reachability error the probe mis-reported as absence (that inversion is the D4-A bug the AC guards).

## Verification

python3 -c "import ast; ast.parse(open('lib/aef_resolve.py').read())"
out=$(timeout 120 python3 -m pytest tests/unit/test_aef_resolve_termlink.py tests/unit/test_aef_resolve.py -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
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

### 2026-09-07 — verb shapes differed from the S3 design's assumed grammar (again)
- **What changed:** The T-3287 seam map named the probe rungs "host→ping, hub→hub_probe, session→list_sessions". Localising against the live binary showed all three were off: `ping` is *session* liveness (not host), `list-sessions` is `list`, and `hub probe` is a *remote* TLS handshake while local-hub existence is `hub status`. Same class as the T-3335 claim-backend grammar surprise — the design's verb names were plausible but not the real CLI.
- **Plan impact:** The dispatch table is by *rung kind → real verb*, not the design's guessed pairs: session→`ping`, project→`path_exists` (filesystem, delegated), local-hub→`hub status`, remote-hub/host→`hub probe`. The agent rung is probed via its carrying session (circuit = session token, `is_circuit`); a bare agent rung with no session raises rather than guess — agent-level presence is a documented v2 deferral, not a silent gap.
- **What sharpened:** the D4-A death-test became concrete per verb — a hub that *answers* `ok:false / "not found"` is a definitive False, but no-structured-verdict (socket down, non-JSON) and every *remote* miss raise INDETERMINATE. The reachable-vs-absent line is the crux the 18 unit tests and the live smoke pin.
- **Triggered:** no new sub-task. Remaining S8 follow-ons unchanged (peer-query/materialize fleet-source; the full G1+G3 arc-close demo, which now has both its foundations — the T-3335 claim mutex and this probe).

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

**Recommendation:** GO (endpoint-probe seam)

**Rationale:** The endpoint-probe seam — the live probe `resolve()` climbs the ladder with,
and the G3 self-heal detection foundation — is wired to real termlink and verified three
ways: 18 unit tests through an injectable fake invoke (exists/absent/indeterminate per rung
kind, no hub needed), the existing resolve suite still green (34 passed total), and a **live
smoke on the real hub passing** (live session→exists, bogus→absent, unreachable→INDETERMINATE
raised). The one `[REVIEW]` Human AC is that live smoke, which already ran green in-session —
the human need only re-run `python3 tests/manual/s8_probe_smoke.py` on their hub.

**Evidence:**
- `lib/aef_resolve.py` — `termlink_probe()` factory (session→ping, project→path_exists, local-hub→hub status, remote→hub probe); D4-A raise-vs-False contract enforced per verb.
- `tests/unit/test_aef_resolve_termlink.py` — 18 tests; existing `test_aef_resolve.py` green (34 total).
- `tests/manual/s8_probe_smoke.py` — live smoke, exit 0 on hub PID 1026708.
- `## Evolution` — the verb-grammar divergence from the S3 design captured (sibling to T-3335).
- `bin/fw vendor self --check` clean.

**Scope note:** one deliverable — the probe seam. Remaining S8 (peer-query/materialize
fleet-source; the full G1+G3 arc-close demo) tracked in `## Context`. This plus the T-3335
claim mutex are the two foundations that demo stands on.

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

### 2026-09-07T15:36:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3338-arc-020-s8-wire-aefresolve-endpoint-prob.md
- **Context:** Initial task creation
