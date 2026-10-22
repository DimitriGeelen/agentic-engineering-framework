---
id: T-4616
name: "Nine timing/order-sensitive tests from the f028d507 cloud run that pass when
  rerun alone"
description: >
  Flaky (fail in the -j4 run, pass alone): t4491_runme_job_queue 80-column pty menu;
  test_sidecar_cli_peer_frame::test_alerts (hub fingerprint unreadable); test_t4458_search_degrade
  x2; test_t4043_docs_detail_title::test_file_with_card_links_to_it; test_t4044_task_page_doc_links
  x4. Also timing-bound: test_t3627_watchtower_wedge (3.18 s vs 2.0 s on 4 vCPU, passes
  here). Find the shared state or load dependence per test. Source: docs/reports/T-4508-cloud-prompts/perfailure-f028d507.txt
  (lines 123, 191-193, 203-208). Triaged in T-4589.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [cloud, test]
components: [tests/lib/module_identity.py, tests/unit/t4491_runme_job_queue.bats, tests/unit/test_t4458_search_degrade.py]
related_tasks: [T-4589]
origin: {kind: "agent"}
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
created: 2026-10-22T08:49:27Z
last_update: 2026-10-22T20:18:07Z
date_finished: 2026-10-22T20:18:07Z
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
  - ts: '2026-10-22T09:00:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-10-22T09:00:49Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=294,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4616: Nine timing/order-sensitive tests from the f028d507 cloud run that pass when rerun alone

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Each of the nine named tests (t4491 pty menu, sidecar test_alerts, t4458 x2, t4043, t4044 x4) has its load/order dependence identified in ## RCA with file:line, and is fixed or explained as not reproducible with evidence
- [x] test_t3627_watchtower_wedge's wall-clock assertion uses a budget that holds under load (or an injected clock), not 2.0 s
- [x] Every fixed test passes 10/10 runs under parallel load (run alongside a CPU load generator)
- [x] No entries added to .context/audits/unit-suite/baseline.yaml

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
#
# Vendored-path hint (T-3236, T-4419): if you edited bin/fw, lib/, agents/, policy/,
# web/, tools/ or .tasks/templates/, run `bin/fw vendor self` and add
#     bin/fw vendor self --check --task T-XXXX
# (your own task id). It checks only the files your commits changed, so another
# worker's uncommitted edit does not block your close; that drift is listed as
# "in flight, not this task". The whole-tree `--check` stays for audit/pre-push.
# t4044/t4043: run AFTER the module replacers (the order that failed in the cloud run)
timeout 600 python3 -m pytest -q -p no:cacheprovider tests/web/test_secret_key.py tests/web/test_load_latest_audit.py tests/web/test_fabric_loader.py tests/web/test_t4044_task_page_doc_links.py tests/web/test_t4043_docs_detail_title.py > /tmp/.t4616a 2>&1 && grep -q passed /tmp/.t4616a
# t4458: after test_t4223_gaps_perf deletes every web.* module
timeout 600 python3 -m pytest -q -p no:cacheprovider tests/unit/test_t4223_gaps_perf.py tests/unit/test_t4458_search_degrade.py > /tmp/.t4616b 2>&1 && grep -q passed /tmp/.t4616b
# sidecar test_alerts: with PROJECT_ROOT away from the checkout's committed hub-id
bash -c 'd=$(mktemp -d); trap "rm -rf $d" EXIT; PROJECT_ROOT=$d timeout 300 python3 -m pytest -q -p no:cacheprovider tests/unit/test_sidecar_cli_peer_frame.py > /tmp/.t4616c 2>&1 && grep -q passed /tmp/.t4616c'
# t4491: under the C locale cron/env -i gives (failed deterministically before)
LC_ALL=C timeout 600 bats -f "80-column" tests/unit/t4491_runme_job_queue.bats > /tmp/.t4616d 2>&1 && ! grep -q "^not ok" /tmp/.t4616d && grep -q "^ok 1 " /tmp/.t4616d
# t3627: no wall-clock budget left in the wedge test
! grep -qE "^[[:space:]]*assert .*< *2\.0" tests/web/test_t3627_watchtower_wedge.py && timeout 900 python3 -m pytest -q -p no:cacheprovider tests/web/test_t3627_watchtower_wedge.py > /tmp/.t4616e 2>&1 && grep -q passed /tmp/.t4616e
# baseline untouched by this task
! git log --format=%s -- .context/audits/unit-suite/baseline.yaml | grep -q "^T-4616"
python3 tools/bats-dead-negation-lint.py tests/ > /tmp/.t4616f 2>&1 && grep -q clean /tmp/.t4616f

## RCA

**Symptom:** nine tests red in the f028d507 cloud -j4 run, green when rerun alone; t3627 red on a 4-vCPU runner (3.18 s vs a 2.0 s budget).

**Root causes (four, one per class):**
1. *Module identity replaced* (t4044 x4, t4043, t4458 x2). `tests/web/test_secret_key.py:30`, `tests/web/test_load_latest_audit.py:30` pop `web.shared`/`web.app`; `tests/web/test_fabric_loader.py:29` pops `web.blueprints.fabric`; `tests/unit/test_t4223_gaps_perf.py:87` deletes every `web.*` module; each reimports, building NEW module objects. Later tests patch the module object they bound at collection (`import web.search as search_mod`, `import web.blueprints.fabric as fabric`) or the new `web.shared`, while the code under test reads the other copy (`web/blueprints/tasks.py:13` binds `_auto_link_files` from the original `web.shared`; `web/blueprints/docs.py:169` and `discovery.py:258` import lazily, getting the replacement). The patch is inert → 0 links / no degraded notice. Reproduced exactly with `--noconftest` in replacer-then-victim order.
2. *Hidden live state* (sidecar test_alerts). `lib/sidecar_cli.py:356` runs `addressing.orphan_inboxes()` → `circuit.hub_id()` (`lib/sidecar/circuit.py:115`), which silently read the checkout's committed `.context/sidecar/hub-id`; with PROJECT_ROOT/cwd elsewhere it shells out to the tripwire termlink and raises CircuitError. Reproduced with `PROJECT_ROOT=<empty dir>`.
3. *Locale, not load* (t4491). `lib/runme_queue.py:747` truncates to `ln[:w-1] + "…"` = 80 characters, but the test measured `${#ln}`, which counts BYTES under C/POSIX (cron, env -i): 79 + 3 = 82. Reproduced deterministically with `LC_ALL=C`.
4. *Wall-clock budget* (t3627, also t4458's `elapsed < 1.5` and `< 1.0`). The property is ordering (/ must not wait for the cold scan), asserted as a 2.0 s wall-clock budget against a 3 s sleep. A first ordering rewrite (f92abe06e) kept a 60 s safety timer that released the held scan; with ten concurrent copies beside 24 CPU burners, a slow-but-unblocked `/` (cold `/` is ~100 s on the live corpus, warm ~2 s, and other workers' `.tasks/` writes invalidate its change-driven caches) outlived the timer and read as "waited" (3/10 red). Now `/` and the static file run in a thread joined with a 900 s hang bound while the scan stays held: a wedged `/` never answers while held. Bite-checked with a scratch copy whose `/` view calls the held scan: red, `None == 200`.

**Why structurally allowed:** tests/unit/conftest.py named cause (1) (L-421 "cause 2") but only restored values (`PROJECT_ROOT`) and class identity, never module identity; tests/web/conftest.py likewise. Nothing pinned a hub id for test_alerts because the committed hub-id file made it pass everywhere the author ran it. Interactive shells are UTF-8, so nobody ran the bats under C.

**Prevention:** `tests/lib/module_identity.py` + an autouse fixture in both conftests restores every replaced `web*`/`lib*`/`agents*` module object after each test, covering future replacers and victims without editing them. Timing assertions in t3627/t4458 are now event-ordering assertions with a safety timer (no budget to miss). Verification lines above replay each failing order/env.

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

**Load evidence (2026-10-22):** 24 `python3 -c 'while 1: pass'` burners on the 24-CPU host. Web order set + sidecar (PROJECT_ROOT elsewhere) + t4491 under LC_ALL=C: 10/10. t4223→t4458 pair: 10/10. t3627 wedge test, ten copies concurrently: 10/10 after the hang-bound rewrite (7/10 with the 60 s timer). With the module-identity restore patched to a no-op, the replayed order fails t4044 x4 + t4043 (5 failed), so the fix is what makes it green.

**Left open (not this task):** `tests/web/test_bpmn_frozen_v1_pin.py::test_absent_marker_stage_output_byte_identical` fails here with and without this task's fixture, as do the 5 `tests/web/test_inception_verdict_render.py` tests (run alone, restore on and off: 5 failed both ways). `test_approvals_bvp_proposals.py::test_context_includes_pending_proposals` was red only in the full `tests/web` run (327 passed, 7 failed); it passes alone both ways, and whether it is order-dependent was not attributed. The t3627 wedge test costs 75-135 s alone because the live-corpus `/` and `/graduation` are slow cold, not because of the hold.

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

### 2026-10-22T08:49:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4616-nine-timingorder-sensitive-tests-from-th.md
- **Context:** Initial task creation

### 2026-10-22T11:16:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2f8a20b5
- **Timestamp:** 2026-10-22T20:19:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 2

**Per-AC findings:**

- **AC#2 (Human)** — [REVIEWER] Block message names both bypass mechanisms
  - **reviewer-prose-mismatch** (partial, heuristic) — `matched='reads' in: Verdict: PASS; no findings on `block-message-completeness``

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 147
     - evidence: `! git log --format=%s -- .context/audits/unit-suite/baseline.yaml | grep -q "^T-4616"`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-10-22T20:18:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
