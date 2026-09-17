---
id: T-3379
name: "fw task review hands out localhost:3000 (a foreign Watchtower) when identity
  handshake fails on the live one"
description: >
  fw task review T-2171 printed http://localhost:3000/review/T-2171 while this project's
  Watchtower is live at the triple-file URL http://192.168.10.107:3002 (fw watchtower
  url resolves it). _watchtower_url (lib/watchtower.sh) reported 'No Watchtower reachable'
  — Layer 1 identity handshake (curl --max-time 2 /api/_identity) failed against the
  live instance — and _watchtower_base_or_placeholder (lib/watchtower.sh:219-231)
  then returned localhost:<fw_config PORT>=3000, which on this host is held by /005-Yellowtwig/.../002-Azure-DevOps's
  Watchtower (pid 1204738). The operator handoff URL therefore points at another project's
  server: the T-1376/T-2732 wrong-server class, in the human-review verb. Two defects:
  (a) why the handshake fails against a live, correct instance; (b) the placeholder
  ignores the triple-file port and names a port another service holds.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [watchtower, review, bug]
components: []
related_tasks: [T-2922, T-2732, T-1376, T-2802]
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
created: 2026-09-17T16:45:56Z
last_update: '2026-09-17T16:46:58Z'
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
  - ts: '2026-09-17T16:46:40Z'
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
  - ts: '2026-09-17T16:46:58Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=272,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3379: fw task review hands out localhost:3000 (a foreign Watchtower) when identity handshake fails on the live one

## Context

Observed 2026-09-17 while closing T-2171. `bin/fw task review T-2171` printed
`No Watchtower reachable for project: /opt/999-Agentic-Engineering-Framework`
and then emitted `http://localhost:3000/review/T-2171`. At the same moment:

- `bin/fw watchtower url` and `.context/working/watchtower.url` both named `http://192.168.10.107:3002`.
- `:3000` was held by pid 1204738, `python3 -m web.app --port 3000`, with cwd
  `/005-Yellowtwig/001-theSpiceFactory/002-Azure-DevOps/.agentic-framework`. That is
  **another project's Watchtower**, running the same Flask app.

So the one link a human-review handoff exists to hand over pointed at a foreign
server. That is the T-1376/T-2732 wrong-server class, which T-1284/T-1290 built a
three-layer identity resolver to prevent. Low task IDs collide across projects, so
that link can render a real-looking page for the wrong task.

There are two mechanisms, and they are not yet known to share a root cause:
- **(a)** `_watchtower_url` Layer 1 (`lib/watchtower.sh:126-150`) did not accept the
  live, triple-file instance. Its handshake is `curl -sf --max-time 2 …/api/_identity`
  plus a `project_root` equality check (`lib/watchtower.sh:62-71`). Cause unknown.
- **(b)** `_watchtower_base_or_placeholder` (`lib/watchtower.sh:219-231`) falls back to
  `http://localhost:<fw_config PORT>`. PORT is unset here, so that is `3000`. The
  fallback ignores the triple file's port, and it doesn't check whether the port it
  names belongs to someone else. T-2922 introduced the placeholder deliberately (so
  the `.reviewed-<id>` marker write is never aborted), and that property must be kept.

### Localisation (2026-09-17)

| Hypothesis | Test | Result |
|---|---|---|
| H1: the handshake times out on a loaded host | `curl -s --max-time 10 -w '%{http_code} %{time_total}' http://192.168.10.107:3002/api/_identity` ×3 | **Disproved.** `http=000` in 0.00013–0.00016 s, a refused connection, not a timeout. Load average was 1.37 |
| H2: nothing is listening, so the triple file is stale | `uptime -s`; `ps -p 3990664`; `ss -tlnp` on :300x; triple-file mtimes | **Confirmed.** Booted `2026-09-17 17:09:04`; pid 3990664 not running; `:3000` held by the foreign pid 1204738, `:3001` by pid 7493, `:3002` by nothing; triple files written at 00:27–00:28, before the reboot |

**So there is one defect, not two.** "No Watchtower reachable" was the truth.
The defect is what happened next: the fallback named `localhost:3000`. On this
host that is a foreign Watchtower (another project's, same Flask app). The
triple file still held `:3002`, which is the answer `bin/watchtower.sh`'s own
`do_url` treats as "stale, but never someone else's".

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **(a) localised by measurement:** the reason Layer 1 rejects the live instance
      is stated in this file together with the command that demonstrates it. It is
      not inferred from reading code
      *(It was not live. See "Localisation" below: the host rebooted at 17:09:04, and
      `ps -p 3990664` shows the pid is not running. Nothing listens on `:3002`
      (`ss -tlnp`), and curl to it returns `http=000` in 0.1 ms, a refused
      connection. Layer 1 was **correct**. The premise "live instance" in this AC
      was wrong, and the record says so rather than rewording it.)*
- [x] **(a) homed correctly:** if (a)'s cause is independent of (b), it is filed as its
      own task and not fixed here (one bug = one task). If it is the same cause,
      that is shown
      *((a) is not a defect, so nothing is filed. The related observation, that
      `fw watchtower url` still names `:3002`, is designed behaviour
      (`bin/watchtower.sh:449-451`, "where it WAS running … Stale, but never someone
      else's"). Not a defect, not filed.)*
- [x] **(b) fixed:** when resolution fails, the placeholder never names a port whose
      listener identifies as a *different* project's Watchtower. When a triple-file
      port exists, it is preferred over the bare config default. The T-2922
      property is kept: the placeholder path still returns exit 2, and `emit_review`
      still writes the `.reviewed-<id>` marker
      *(`lib/watchtower.sh:_watchtower_base_or_placeholder` tries the triple port,
      then the config port, and skips any port something is listening on.
      If all are held, it returns `http://watchtower-not-running.invalid`; exit 2 on
      every placeholder path. The fix is stricter than the AC: any listener is
      skipped, not only an identified-foreign one. In this branch nothing identified
      as ours, so a holder can't be ours. Live check on the incident host:
      `bin/fw task review T-2171` now emits `http://localhost:3002/review/T-2171`
      (the triple port, which is free) instead of `:3000` (the foreign pid 1204738).
      `emit_review` suites (`lib_review`, `review_pipefail`,
      `emit_review_ac_counter`, `inception_decide_emit_review_post_move`,
      `recommendation_gate_build_partial`): 38/38 ok.)*
- [x] **Regression test** for (b) in `tests/unit/`, driving a stub listener that
      answers `/api/_identity` with a foreign `project_root`. It asserts that the
      placeholder does not name that port
      *(`tests/unit/t3379_review_placeholder_foreign_port.bats`, 5 tests, reusing
      `tests/fixtures/foreign_watchtower.py`. 5/5 ok after the fix.)*
- [x] **Control leg:** the same test goes red against the pre-fix
      `_watchtower_base_or_placeholder`. Without that, a test that never fires is
      indistinguishable from one that works
      *(Before the fix, tests 1, 2 and 4 went **red at the incident assertions**:
      foreign port named; triple port ignored; foreign port named. Tests 3 and 5
      were green, as expected: 3 because the old code ignores the triple and the
      config port it names happened to be free, 5 because it pins unchanged T-2922
      behaviour. An earlier all-5-red run was a **harness** bug, not a control:
      `run` merged the resolver's stderr into `$output`. It was fixed before this
      run was counted.)*
- [x] Existing Watchtower URL tests remain green (`tests/unit/` files that source
      `lib/watchtower.sh`)
      *(`lib_watchtower`, `t2438_notify_review_url`,
      `watchtower_health_verdict_identity`, `watchtower_url_no_guess`,
      `t3054_watchtower_root_fallback` plus the new file: 34/34 ok. One red
      found nearby, `t2862_greenfield_first_inception_e2e` test 4, is
      **pre-existing**: it fails identically on a `git archive` export of HEAD
      `9e8b6f330`, which lacks this change. Filed as OBS-433, not claimed here.)*
- [x] `bin/fw vendor self --check` is clean before close (OBS-250 ordering)
      *(Self-vendor withheld `lib/watchtower.sh` as uncommitted. It was synced via
      the named-file route `FW_VENDOR_ONLY="lib/watchtower.sh"`, not the Tier-2
      `FW_VENDOR_ALL`. `--check`: "in sync with source"; `cmp` identical.)*

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

bash -n lib/watchtower.sh
timeout 300 bats tests/unit/t3379_review_placeholder_foreign_port.bats > /tmp/.t3379-new.out 2>&1 && ! grep -q "^not ok" /tmp/.t3379-new.out && grep -q "^ok 5 " /tmp/.t3379-new.out
test "$(grep -c '# skip' /tmp/.t3379-new.out)" -eq 0
timeout 400 bats tests/unit/lib_watchtower.bats tests/unit/watchtower_url_no_guess.bats tests/unit/t2438_notify_review_url.bats tests/unit/watchtower_health_verdict_identity.bats tests/unit/t3054_watchtower_root_fallback.bats > /tmp/.t3379-wt.out 2>&1 && ! grep -q "^not ok" /tmp/.t3379-wt.out
timeout 500 bats tests/unit/lib_review.bats tests/unit/review_pipefail.bats > /tmp/.t3379-rv.out 2>&1 && ! grep -q "^not ok" /tmp/.t3379-rv.out
bin/fw vendor self --check

## RCA

**Symptom.** After a host reboot killed this project's Watchtower,
`fw task review T-2171` printed `http://localhost:3000/review/T-2171`. On that
host `:3000` belonged to another project's Watchtower (the same Flask app, whose
task IDs overlap ours), so the operator's review link opened a foreign server.

**Root cause.** `_watchtower_base_or_placeholder` built its "not running yet"
URL from the configured port alone, `fw_config PORT 3000`. It had two blind spots:
1. It ignored the triple file, which is this project's own record of where it ran,
   and the port `fw watchtower restart` rebinds (T-2598).
2. It never asked whether anything was listening on the port it named.

Its docstring promised the link would be "correct the moment `fw serve` runs".
On a host where the default port is foreign-held, `fw serve` **refuses** (T-1803),
so that promise could not hold.

**Why structurally allowed.** Three things combined:
- T-1284/T-1290/T-1803 hardened the *live* resolver with an identity handshake,
  and T-2802 removed the well-known-port guess from `fw watchtower url`.
- T-2922 then added a placeholder path, deliberately, to keep `emit_review` from
  aborting before its marker write. That path reintroduced the exact guess the
  resolver refuses to make, one function below it. It passed review because it
  is honest *by exit code* (2 = placeholder). Its consumer, however,
  prints the URL to a human, and a human doesn't see exit codes.
- No test covered the placeholder with a foreign listener present. The fixture
  for that case already existed (`tests/fixtures/foreign_watchtower.py`, T-2802)
  and was used only against `do_url`.

The failure also needs a state that ordinary development never produces: our
instance dead *and* a neighbour on the default port. A reboot creates exactly
that. The same false-green shape appears in CLAUDE.md §Watchtower Port: a link
to the wrong server renders a plausible page, so nothing prompts anyone to look.

**Prevention.**
- `tests/unit/t3379_review_placeholder_foreign_port.bats` pins the property
  (never name a held port; prefer the triple port; `.invalid` when everything is
  held; T-2922's exit-2 contract kept). It has a recorded control leg, so it is
  known to fire.
- The docstring now states the contract that is actually implemented, not the
  `fw serve` promise.
- **Not prevented here** and recorded as open: the resolver's stderr hint still
  says "Start one with: fw serve". On a host whose default port is foreign-held
  that command refuses, and the working command is `fw watchtower restart`. This
  is a wording change in operator-facing text, filed for triage as **OBS-434**.

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

### 2026-09-17T16:45:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3379-fw-task-review-hands-out-localhost3000-a.md
- **Context:** Initial task creation

### 2026-09-17T16:46:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
