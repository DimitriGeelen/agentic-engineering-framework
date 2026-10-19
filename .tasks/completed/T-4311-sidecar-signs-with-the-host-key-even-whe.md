---
id: T-4311
name: "Sidecar signs with the host key even when RAIL_IDENTITY_FILE is configured
  (only fw rail applies it)"
description: >
  832 T-1151 consult (msg 01b13f84): lib/rail-identity.sh (T-2904) resolves RAIL_IDENTITY_FILE,
  but only 'fw rail' (bin/fw:8199) applies it. lib/sidecar (send, circuit.py, dm.py,
  inbox) calls termlink with the inherited env, so sidecar mail is signed with the
  host-shared key d1993c2c3ec44c94 unless TERMLINK_IDENTITY_FILE happens to be in
  the process env. Confirmed here: RAIL_IDENTITY_FILE=.context/rail-identity.key is
  set, termlink whoami still shows d1993c2c. Make every sidecar termlink call use
  the same identity resolution as fw rail, without breaking DM rails or cursors keyed
  by the old fingerprint.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [sidecar, identity, bug]
components: [lib/config.sh, lib/sidecar/dm.py, lib/sidecar/hooks.py, lib/sidecar/http_server.py, lib/sidecar/identity.py, lib/sidecar/inject.py, lib/sidecar/watcher.py, lib/sidecar_cli.py]
related_tasks: []
origin: {kind: "peer", source: "832"}
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
created: 2026-10-18T13:58:59Z
last_update: 2026-10-18T21:42:43Z
date_finished: 2026-10-18T21:42:43Z
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
  - ts: '2026-10-18T14:15:34Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-18T14:16:24Z'
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
---

# T-4311: Sidecar signs with the host key even when RAIL_IDENTITY_FILE is configured (only fw rail applies it)

## Context

Sidecar termlink calls must use the same project signing identity as `fw rail post` (T-2904), behind an opt-in switch, without losing DMs addressed to the old host fingerprint. Dispatched as worker w4311.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] One helper (`lib/sidecar/identity.py`) builds the termlink env: sets `TERMLINK_IDENTITY_FILE` to the resolved `RAIL_IDENTITY_FILE` (FW_RAIL_IDENTITY_FILE env > .framework.yaml, relative paths against PROJECT_ROOT), never overrides an already-set TERMLINK_IDENTITY_FILE / TERMLINK_AGENT_ID / TERMLINK_IDENTITY_DIR, and is off unless `SIDECAR_RAIL_IDENTITY=1` (registered in lib/config.sh; this repo's config is NOT changed)
- [x] Every sidecar process entry point (sidecar_cli, watcher, hooks, http_server, inject) installs that env once at start, so every termlink subprocess lib/sidecar runs (and every child it spawns) inherits it — no per-call-site env plumbing
- [x] DM transition: when the switch moves this project off the host key, the old host-key `dm:*` rails stay readable (their cursors in the same inbox state store are untouched and keep advancing) so no DM addressed to the old fingerprint is lost; behaviour without the switch is byte-identical to before
- [x] Regression tests with a fake `termlink` that records the env it was called with: fail before the fix, pass after; existing sidecar dm/inbox tests still pass

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

<!--
  Render-touching build tasks (web/templates, web/static, web/blueprints, web/shared.py,
  web/app.py …) add a section headed "Visual Verification" (level-2 heading) after
  Verification, with one checklist table — the check-visual-verification gate reads it
  at commit time (T-4213; T-4202 GO):

    | state | control | 1024 | 1440 | 1920 | note |
    |-------|---------|------|------|------|------|
    | toolbar | Load | ok | ok | ok | |

  Cells: ok / clipped / hidden / overlap / unreachable (non-ok needs a note). Each
  listed state needs screenshots at every UX_SHOT_WIDTHS width:
  fw ux shots <T-ID> <state>=<URL>. This comment is inert: the gate ignores it.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
# Build/refactor/decommission tasks with NO command here are refused. If nothing can be
# run, add the line `# verification: none — <why nothing can be run>`; it is serviced
# (queued for review: add a check / other evidence / accept). See docs/reports/T-4024-servicing-loop.md.
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
python3 -m pytest tests/unit/test_sidecar_rail_identity_t4311.py -q -p no:cacheprovider > /tmp/.t4311-a 2>&1 && grep -q "19 passed" /tmp/.t4311-a
python3 -m pytest tests/unit/test_sidecar_dm.py tests/unit/test_sidecar_dm_host_shared_t4252.py tests/unit/test_sidecar_dm_scope_t3966.py tests/unit/test_sidecar_inbox.py -q -p no:cacheprovider > /tmp/.t4311-b 2>&1 && grep -q passed /tmp/.t4311-b
grep -q "identity.apply()" lib/sidecar_cli.py && grep -q "identity.apply()" lib/sidecar/watcher.py && grep -q "identity.apply()" lib/sidecar/hooks.py && grep -q "identity.apply()" lib/sidecar/http_server.py && grep -q "identity.apply()" lib/sidecar/inject.py
bash -n lib/config.sh && grep -q '"SIDECAR_RAIL_IDENTITY|0|' lib/config.sh && grep -q '"SIDECAR_HOST_DM_TRANSITION|1|' lib/config.sh
! grep -q "^SIDECAR_RAIL_IDENTITY" .framework.yaml
bin/fw vendor self --check

## RCA

**Symptom:** with `RAIL_IDENTITY_FILE=.context/rail-identity.key` configured, sidecar mail (send, DM, inbox drain, receipts, watcher subscribe) was still signed with the host-shared key d1993c2c; `termlink whoami` from a sidecar process showed the host fingerprint (832 T-1151 consult, msg 01b13f84).

**Root cause:** the identity is selected only by env precedence (TERMLINK_IDENTITY_FILE > TERMLINK_AGENT_ID > TERMLINK_IDENTITY_DIR > host). `lib/rail-identity.sh` resolves RAIL_IDENTITY_FILE but applies it in exactly one place, the `fw rail post` branch of `do_rail` (lib/rail-identity.sh, `TERMLINK_IDENTITY_FILE="$idfile" termlink channel post`). Every lib/sidecar termlink call (e.g. lib/sidecar/inbox.py:210 `default_reader`, lib/sidecar/dm.py `default_lister`/`identity_fingerprint`, lib/sidecar/receipts.py:231, lib/sidecar/watcher.py:689) runs `subprocess.run/Popen` with the inherited env, and no sidecar entry point (lib/sidecar_cli.py:main, watcher.main, hooks.main, http_server.main, inject `__main__`) ever set it.

**Why structurally allowed:** T-2904 framed the problem as "rail posts" and gated one verb; the sidecar grew its own termlink producer surface afterwards (arc-011) and nothing tied "this project has a signing identity" to "every producer of this project uses it". `rail_identity_guard` only runs inside `fw rail post`, and dm.py's `identity_is_host_shared` (T-4252) *measures* host-sharing but treats it as a read-safety question, not a signing defect. No test asserted the env a sidecar termlink subprocess receives.

**Prevention:** the identity is now decided in one helper (`lib/sidecar/identity.py:termlink_env`) and installed once per process at every sidecar entry point, so new call sites inherit it with no plumbing. `tests/unit/test_sidecar_rail_identity_t4311.py` runs a real sidecar process against a fake `termlink` that records its env and asserts every call carries the project key, plus a per-entry-point test that fails if a new/changed entry point stops calling `identity.apply()`.

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

### 2026-10-18 — where the identity is applied
- **Chose:** one helper `lib/sidecar/identity.py` (`termlink_env()` builds the env, `apply()` installs it into `os.environ`), called once at each process entry point (sidecar_cli.main, watcher.main, hooks.main, http_server.main, inject `__main__`). All lib/sidecar subprocess calls inherit os.environ (spawned children pass `dict(os.environ, ...)`), so every termlink call and every child is covered.
- **Why:** ~25 termlink call sites, most with injectable `runner=` parameters; threading `env=` through each is the per-call-site approach the task rules out, and a new call site would silently miss it.
- **Rejected:** applying at `lib/sidecar/__init__.py` import time (mutates the env of every test and every importer); per-call `env=` (drifts).

### 2026-10-18 — opt-in switch, and precedence
- **Chose:** off unless `SIDECAR_RAIL_IDENTITY=1` (new registry key, default 0). Existing TERMLINK_IDENTITY_FILE / TERMLINK_AGENT_ID / TERMLINK_IDENTITY_DIR win. RAIL_IDENTITY_FILE is resolved as fw_config does (FW_RAIL_IDENTITY_FILE env > .framework.yaml), relative to PROJECT_ROOT, and — like `fw rail post` — a configured path that does not exist yet is created by termlink on first use; only a configured path is ever used.
- **Why:** this repo already has RAIL_IDENTITY_FILE set, so an unconditional fix would switch the live sidecar's signing key (and its DM rail set) on the next watcher restart — the task says not to enable it here. A switch also makes adoption the explicit coordination event rail-identity.sh says it is. Enabling: `bin/fw config set SIDECAR_RAIL_IDENTITY 1`, then restart the sidecar.
- **Rejected:** keying the switch off RAIL_IDENTITY_FILE alone (enables it here immediately).

### 2026-10-18 — DM rails and cursors across the switch
- **Chose:** when `apply()` moved the process off the host key (marker `FW_SIDECAR_RAIL_IDENTITY_APPLIED`), `dm.rails_for_key()` with no explicit key returns rails for BOTH the new project fingerprint and the old host fingerprint (`dm.legacy_host_fingerprint()`, measured by stripping the identity env — never hard-coded), while `SIDECAR_HOST_DM_TRANSITION` is on (default 1). `pending()`, `summary()` and everything else on that path see both sets.
- **What happens to cursors:** nothing is migrated, reset or copied. Cursors live in the one inbox state store keyed by topic NAME (`state["topics"]["dm:a:b"]`), and a rail's name does not change when our key does. So: old host-key rails `dm:*:<hostfp>` keep whatever cursor they already had and keep advancing as they are drained; new project-key rails `dm:*:<projectfp>` are different topics and start at cursor 0 (all their posts read as unread once). Under the host key before the switch, T-4252 had stopped `pending()` draining at all, so any cursor on a host rail predates T-4252, and any DM posted since is still unread and is delivered on the first drain after the switch.
- **Trade-off, stated plainly:** draining host-key rails is what T-4252 stopped, because every co-resident project reads them. During the transition this project again consumes (for itself) DMs on host rails, including any meant for a co-resident — the same as 832's transition. Set `SIDECAR_HOST_DM_TRANSITION=0` once peers address the project fingerprint; then only project rails are read.
- **Not a transition:** an operator-exported TERMLINK_IDENTITY_FILE (no marker) does not drain host rails — that key was chosen outside the sidecar, so behaviour is unchanged from before this task. With the switch off, rails, cursors and signing are byte-identical to before.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-18T13:58:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4311-sidecar-signs-with-the-host-key-even-whe.md
- **Context:** Initial task creation

### 2026-10-18T21:09:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f091bf5a
- **Timestamp:** 2026-10-18T21:42:51Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Human)** — [REVIEWER] Block message names both bypass mechanisms
  - **reviewer-prose-mismatch** (partial, heuristic) — `matched='reads' in: Verdict: PASS; no findings on `block-message-completeness``

### 2026-10-18T21:42:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
