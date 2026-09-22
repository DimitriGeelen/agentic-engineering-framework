---
id: T-3431
name: "Fabric enrichment at every session start: SessionStart/resume runs a bounded
  fw fabric enrich --describe and the resume statement carries the fabric quality
  line (operator ruling 2026-09-22; depends on T-3430)"
description: >
  Structural counterpart to T-3430's daily cron: the SessionStart hook (post-compact-resume,
  all three matchers) and fw resume run 'fw fabric enrich --describe' under a hard
  timeout (target <10s on 1,314 cards: only cards still carrying a placeholder are
  visited; heavy work deferred to the cron), and the injected resume context gains
  one line — 'Fabric: N cards, T with TODO purpose, U unknown subsystem, R refused
  (see drift)' — so the agent sees fabric quality on every start and the refusal list
  when it can still act. Never blocks the session: on timeout or error it prints the
  last known counts and moves on. Depends on T-3430 shipping --describe and the under-populated
  drift class.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/post-compact-resume.sh, agents/fabric/lib/enrich.py, agents/resume/resume.sh, tests/unit/t3431_fabric_session_start.bats, tests/unit/test_t3430_enrich_describe.py]
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
created: 2026-09-22T12:00:48Z
last_update: 2026-09-22T13:33:27Z
date_finished: 2026-09-22T13:33:27Z
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
  - ts: '2026-09-22T12:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=273,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T12:15:25Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3431: Fabric enrichment at every session start: SessionStart/resume runs a bounded fw fabric enrich --describe and the resume statement carries the fabric quality line (operator ruling 2026-09-22; depends on T-3430)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `agents/context/post-compact-resume.sh` (the one hook behind all three SessionStart matchers: startup, resume, compact) runs `timeout ${FW_FABRIC_DESCRIBE_TIMEOUT:-10} bin/fw fabric enrich --describe --quiet` and never fails the hook on timeout/error (exit 0, last-known counts printed instead)
  - Evidence: `agents/context/post-compact-resume.sh` (Fabric describe pass block, before the Discovery findings section). Live: `FW_FABRIC_DESCRIBE_TIMEOUT=0` forces the call to fail — hook still exits 0 and injects the cached line (proven in `tests/unit/t3431_fabric_session_start.bats`, test 2).
- [x] The additionalContext the hook injects gains one line `Fabric: N cards · T TODO purpose · U unknown subsystem · E no edges · R refused this run (bin/fw fabric drift for ids)`; `fw resume status` prints the same line under its state block
  - Evidence: `enrich.py --quiet` prints exactly this line (verbatim format, `agents/fabric/lib/enrich.py:apply_describe`'s quiet branch); the hook writes it to `.context/working/.fabric-describe.last` and injects it under `## Fabric Quality`; `agents/resume/resume.sh:cmd_status` reads the same cache file and prints it under `Fabric Quality:` right after the Git state block.
- [x] `fw fabric enrich --describe --quiet` visits only cards that still carry a placeholder (purpose TODO or subsystem unknown), so the session-start call stays under the timeout on 1,314 cards — measured and recorded here; full sweeps remain the cron's job (T-3430)
  - Evidence: `--quiet` forces `--describe-only` internally (skips the edge-recompute phase entirely — that phase alone measured 13s on this corpus, over budget). `apply_describe()` itself already only does file I/O (`derive_purpose`/`derive_subsystem`) for cards where `is_placeholder_purpose`/`is_placeholder_subsystem` is true — the ~1,280 non-placeholder cards are a cheap in-memory boolean check. **Measured live, 3 runs: 3.39s / 3.31s / 3.28s** on the full 1,323-card corpus (`build_index()`'s `yaml.safe_load` over every card is the dominant, unavoidable cost) — comfortably under the 10s default `FW_FABRIC_DESCRIBE_TIMEOUT`. Full `--describe` + edges measured 13.1s for comparison — over budget, which is why `--quiet` does not run it.
- [x] Tests: the hook emits the fabric line on a fixture fabric with 2 TODO cards; the hook exits 0 and emits the last-known line when the enrich call is forced to fail (`FW_FABRIC_DESCRIBE_TIMEOUT=0`); `fw resume status` shows the line
  - Evidence: `tests/unit/t3431_fabric_session_start.bats` — 5 tests green (2-TODO-card fixture, forced-fail fallback with cache-file identity check, no-`.fabric/` no-op, `resume status` shows the cached line, `resume status` silent with no cache yet). `tests/unit/test_t3430_enrich_describe.py` — 6 new `--quiet` tests added (17 total in file, all green): one-line-only output, headers/refusals suppressed, cards still written (not dry-run), edge phase skipped, post-update counts, `--dry-run` honoured.
- [x] `bin/fw enforcement baseline` re-run if `.claude/settings.json` changes (it should not — the hook script changes, not the wiring); vendored copies synced, `bin/fw vendor self --check` clean
  - Evidence: `.claude/settings.json` untouched (`git diff --quiet .claude/settings.json` exits 0). `fw doctor` → `OK Enforcement baseline intact`. `FW_VENDOR_ONLY="agents/context/post-compact-resume.sh agents/fabric/lib/enrich.py agents/resume/resume.sh" bin/fw vendor self` run, then `bin/fw vendor self --check` → "vendored .agentic-framework/ in sync with source."
- [x] Recorded: decision D-(this) "enrichment at every session start" points here; T-3430's cron description cross-references this task as the per-session counterpart
  - Evidence: D-592 (`.context/project/decisions.yaml`) already named this task ("implemented as T-3431") at filing time — no new decision needed. `.context/cron-registry.yaml`'s `fabric-describe-daily` entry description now cross-references T-3431/D-592 as the per-session counterpart; `fw cron generate` + `fw doctor` → `OK Cron registry in sync`, no "edited but not generated" WARN.

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

bash -n agents/context/post-compact-resume.sh
bash -n agents/resume/resume.sh
python3 -c "import ast; ast.parse(open('agents/fabric/lib/enrich.py').read())"
out=$(python3 -m pytest tests/unit/test_t3430_enrich_describe.py -q 2>&1); echo "$out" | grep -q "17 passed" && ! echo "$out" | grep -q "failed"
out=$(bats tests/unit/t3431_fabric_session_start.bats 2>&1); echo "$out" | grep -q "^ok 5 " && ! echo "$out" | grep -q "^not ok"
timeout 15 bin/fw fabric enrich --describe --quiet
bin/fw vendor self --check
git diff --quiet .claude/settings.json
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"

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

### 2026-09-22 — `--quiet` forces `--describe-only` semantics rather than literally running edges too
- **Chose:** `enrich.py --quiet` internally sets `args.describe_only = True` regardless of the flags passed, skipping the forward/reverse edge-computation phase entirely, and prints exactly one line: `Fabric: N cards · T TODO purpose · U unknown subsystem · E no edges · R refused this run (bin/fw fabric drift for ids)`. The hook and `fw resume status` inject this line verbatim.
- **Why:** Measured live: `--describe-only` (no edges) is ~3.3s on the full 1,323-card corpus; `--describe` with the edge pass is 13.1s — over the 10s default `FW_FABRIC_DESCRIBE_TIMEOUT`. The nightly T-3430 cron already only ever runs `--describe-only` for the same reason ("the nightly sweep has no business recomputing the dependency graph"). Session start inherits that same boundary rather than inventing a different one. The AC's literal invocation (`enrich --describe --quiet`) is honoured at the call-site; `--quiet` is what narrows the actual work performed.
- **Rejected:** (a) A separate raw-text pre-filter that skips YAML-parsing non-placeholder cards before `build_index()` — unnecessary once edges are already out of scope, since `apply_describe()` only does real file I/O on placeholder cards; the ~3.3s floor is `yaml.safe_load` over 1,323 files, which is inherent to any full-corpus fabric scan (paid identically by `fw doctor`/`fw audit`/`fw fabric drift` today) and did not need re-solving here. (b) A background/`nohup` hook invocation with a cached-summary read — the ground truth text allowed this as a fallback if the foreground path couldn't be made fast enough, but 3.3s comfortably fits inside the 10s budget so the simpler foreground call was kept.

### 2026-09-22 — `fw resume status` reads the cache file rather than re-running the scan
- **Chose:** `resume.sh:cmd_status` reads `.context/working/.fabric-describe.last` (the same cache file the hook writes) instead of invoking `fw fabric enrich --describe --quiet` itself.
- **Why:** `resume status` is documented as a "routine check" callers may run repeatedly in one session (CLAUDE.md recommends `resume quick` over `resume status` for that reason); paying the ~3.3s scan cost on every invocation is unnecessary when the SessionStart hook already refreshes the cache once per session. The line is only as stale as the last session-start/resume/compact event, which is the same freshness bound the additionalContext line has.
- **Rejected:** Re-running the live scan inside `cmd_status` — correct but slower for no accuracy gain in the common case, and duplicates work the hook already did moments earlier.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-22T12:00:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3431-fabric-enrichment-at-every-session-start.md
- **Context:** Initial task creation

### 2026-09-22T12:58:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-22 — build [t3431-session-enrich]
- **Action:** Added `--quiet` to `agents/fabric/lib/enrich.py` (one-line summary,
  implies `--describe-only`), wired `agents/context/post-compact-resume.sh` to run
  `timeout ${FW_FABRIC_DESCRIBE_TIMEOUT:-10} bin/fw fabric enrich --describe --quiet`
  on every SessionStart (startup/resume/compact) and cache the line to
  `.context/working/.fabric-describe.last`, and wired `agents/resume/resume.sh`
  (`cmd_status`) to print the same cached line under its Git-state block.
- **Measured:** `--quiet` (describe-only path) 3.28-3.39s on the live 1,323-card
  corpus, 3 runs; full `--describe` + edge recompute 13.1s (over the 10s default
  budget, why `--quiet` skips it). Foreground call kept — no background/`nohup`
  fallback needed.
- **Tests:** `tests/unit/t3431_fabric_session_start.bats` (new, 5 tests) — fixture
  fabric, 2-TODO-card emit, forced-fail-via-`FW_FABRIC_DESCRIBE_TIMEOUT=0` fallback,
  no-`.fabric/` no-op, `resume status` shows/hides the line. 6 new tests added to
  `tests/unit/test_t3430_enrich_describe.py` (17 total, all green) for `--quiet`
  itself. `bin/fw fabric register` run on the new test file (T-3430 auto-derived a
  real purpose from its header comment).
- **Side effect noted, not a defect:** `bin/fw fabric register` auto-runs a full
  non-dry-run `enrich.py` (pre-existing behaviour, `register.sh:135,393`), which
  recomputed edges across 145 live `.fabric/components/*.yaml` cards as a normal
  consequence of registering the new test file — all 145 verified still valid YAML;
  this is standard `register` behaviour, unrelated to the `--quiet` change.
- **Observed, out of scope:** `fw resume status` crashes on the LIVE corpus today
  (`agents/resume/resume.sh: line ~188/195: ... invalid arithmetic operator`,
  inside `get_active_tasks`) — confirmed pre-existing via `git stash` (identical
  crash with this task's edits removed). Some active task's title/body content
  breaks a `$((...))` count. My Fabric Quality line prints correctly *before* the
  crash point, and all 5 new bats tests pass in an isolated fixture project
  unaffected by the live corpus, so this task's ACs are unaffected — but the
  pre-existing `resume status` unit tests (`tests/unit/resume.bats`, 4 tests) are
  already red on this repo for the same unrelated reason (confirmed both before
  and after this task's changes). Not registered as a new concern — out of scope
  for this task's file list, flagging here per CLAUDE.md's "don't silently work
  around it" guidance.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-09efea8c
- **Timestamp:** 2026-09-22T13:35:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-22T13:33:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
