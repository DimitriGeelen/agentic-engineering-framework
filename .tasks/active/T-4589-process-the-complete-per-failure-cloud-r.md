---
id: T-4589
name: "Process the complete per-failure cloud report at f028d507 (197 items: 122 defect,
  65 env, 9 flaky, 1 hang)"
description: >
  ring20 relayed the operator-approved per-failure re-run (trig_01QQhSuKjra5B1gHPm8r7Zqm,
  pinned f028d507): /var/tmp/ring20-aef-perfailure-f028d507.txt, 230 lines, sha256
  a131b3d632ff542dfade8474c9e939aa81e902e92cc1797d526d8a322db07d79 (byte-exact to
  the cloud job's own report). Save it under docs/reports/T-4508-cloud-prompts/perfailure-f028d507.txt
  with the same sha256, then group the 122 defect lines by root cause (one task per
  independent cause, not per test), skip causes already owned by open tasks (T-4568..T-4582,
  T-4221, T-4574 Playwright triage) and note the mapping. Env lines: note as env,
  no tasks, except where the env gap is itself a framework defect (e.g. a test that
  silently needs ~/.claude/projects or a detached-HEAD-unsafe fixture). Flaky: one
  task listing them. Hang: fw_test_cmd.bats recursion.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [cloud, test, triage]
components: []
related_tasks: [T-4508, T-4575]
origin: {kind: "peer", source: "proxmox-ring20-management", ref: "cd7ae2ea"}
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
created: 2026-10-22T07:53:33Z
last_update: 2026-10-22T08:31:31Z
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
  - ts: '2026-10-22T07:54:51Z'
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
  - ts: '2026-10-22T08:00:46Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=307,acs=6)
    rubric_sha: e4a00f38e801
---

# T-4589: Process the complete per-failure cloud report at f028d507 (197 items: 122 defect, 65 env, 9 flaky, 1 hang)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] docs/reports/T-4508-cloud-prompts/perfailure-f028d507.txt committed with sha256 a131b3d632ff542dfade8474c9e939aa81e902e92cc1797d526d8a322db07d79
- [x] Every defect line grouped by root cause in a `## Triage` cause -> task table in this file; causes owned by open tasks mapped, not re-filed
- [x] One new task (owner agent, horizon next, related T-4589) per unowned independent root cause, plus one flaky task and the fw_test_cmd.bats hang
- [x] Env lines recorded as env; env gaps that are framework defects (detached-HEAD-unsafe fixtures, ~/.claude/projects dependency) filed

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
sha256sum docs/reports/T-4508-cloud-prompts/perfailure-f028d507.txt | grep -q '^a131b3d632ff542dfade8474c9e939aa81e902e92cc1797d526d8a322db07d79 '
git ls-files --error-unmatch docs/reports/T-4508-cloud-prompts/perfailure-f028d507.txt
grep -q '^## Triage' .tasks/active/T-4589-process-the-complete-per-failure-cloud-r.md

## Triage

Source: `docs/reports/T-4508-cloud-prompts/perfailure-f028d507.txt` (report line numbers). "HEAD" = re-run of
that file alone on bleeding-edge 2026-10-22 (single files only, no full suite).

### Defects: cause → task

| Report lines | Cause | Disposition |
|---|---|---|
| 13-14 | test_pretooluse_gates 6/12 hard-code /opt path | existing T-4579 |
| 15-17, 19-20 | register/T-3694 gate fixtures use a tautological Verification | existing T-4580 |
| 21 | inception-decide CLAUDECODE test predates T-2964 ordering; missing-task exit is silent | **filed T-4594** |
| 22, 26 | restart signal does not fold .next-directive.yaml | existing T-4577 |
| 23 | Bash redirect to /etc not blocked by check-project-boundary (HEAD: reproduces) | **filed T-4593** |
| 24-25 | claude_fw_restart_terminator FIX/CONTROL messages missing (HEAD: reproduces) | **filed T-4596** |
| 103 | t3247 D5 expects bare -c; T-4497 made continue `--resume <id>` (HEAD: reproduces) | **filed T-4595** |
| 34-36 | fw_inception fixture: template missing Recommendation/Decision | **filed T-4597** |
| 38 | greenfield control expects `jobs: []`; init now seeds jobs | **filed T-4598** |
| 39 | pickup local-save envelope lacks summary (no termlink; passes here with termlink) | **filed T-4614** |
| 41 | fw setup ignores PROJECT_ROOT | **filed T-4599** |
| 42 | fw_task placeholder test lacks required flags | **filed T-4600** |
| 44, 47 | fw_update / handover_latest_symlink fixtures not an initialised project | **filed T-4601** |
| 45-46 | validate-init prints no `dir-` results | **filed T-4602** |
| 48-49 | t2501 drift tests use doctor --quick (host probe skipped) | **filed T-4603** |
| 54-58 | approvals_close_ready_arcs policy fixture | baseline, owner T-3611 |
| 59 | atomic_yaml_write_lint | baseline, owner T-3612 |
| 60, 70-71, 83 | emit_review inception handoff-ready block vs bypass/pipefail tests | baseline, owner T-3609 |
| 61 | audit_split_root_asset ratchet | baseline, owner T-3614 |
| 63-65 | doctor_hook_counters | baseline, owner T-3615 |
| 94 | t2436 --check vs --dry-run | existing T-4585 |
| 95 | t2452 doctor --quick | baseline, owner T-3992 |
| 97, 102 | completed tasks carrying a non-null horizon (t3118, t3235) | existing T-4584 |
| 98-101 | t3232 extractor legs fail with LANG unset (confirmed `env -u LANG`) | **filed T-4608** |
| 104 | t3298 source pin on a trap literal audit.sh no longer has | **filed T-4604** |
| 105-107 | t3379 foreign port | passes on e785e48b9 (T-4575), passes at HEAD |
| 114-115 | t4226 needs ambient FRAMEWORK_ROOT (confirmed `env -u FRAMEWORK_ROOT`) | **filed T-4606** |
| 116 | t4259 (c) cron drift on fresh init | fixed after f028d507 (b6e45a8b1, T-4259) |
| 117-118 | t4263 restart-note banner | fixed after f028d507 (ccfc64f98, c939b2816) |
| 119 | t4381 fixture flagged by tree guard for its own `__pycache__` | **filed T-4609** |
| 120 | t4542_prepush_lock_holder runs a live sectioned audit (T-4401 lint) | **filed T-4605** |
| 121-122 | t4453 upgrade from checkout | existing T-4566 |
| 126 | bin/fw heredoc-in-cmd-sub | fixed by T-4581 (298c394b2) |
| 129 | test_index_doctor_rail reads installed .git/hooks/pre-push | env (git hooks), passes at HEAD |
| 144-183 | Playwright (40) | existing T-4574 |
| 184-186 | test_audit_frontmatter_variants cloud-only (passes here) | **filed T-4612** |
| 187 | test_cockpit_activity cloud-only (passes here) | **filed T-4613** |
| 190 | test_operator_facing_stderr | baseline, owner T-3605 |
| 194 | test_approvals_blocked_arcs threshold | fixed after f028d507 (112ad8bdb, T-4329) |
| 195-199 | decided_unclosed_count undefined | existing T-3898 |
| 200 | /tasks board started-work column uncapped (HEAD: reproduces) | **filed T-4610** |
| 201-202 | approval summary omits AC-review tasks (HEAD: reproduces) | **filed T-4611** |
| 203 | t3627 wedge 3.18 s > 2.0 s (passes here; load-bound) | folded into flaky T-4616 |
| 62, 96, 67-68 | bvp_auto_promote cron sync, t3062 budget, greenfield seed audit: cron not deployed | env (cron), as T-4575 |

### Hang and flaky

| Report lines | Disposition |
|---|---|
| 143 | fw_test_cmd.bats runs the full suite recursively → **filed T-4615** |
| 123, 191-193, 204-208 | 9 flaky (+ t3627 timing) → **filed T-4616** |

### Env (no task, except where the gap is a framework defect)

| Report lines | Env | Disposition |
|---|---|---|
| 72-77, 86-93, 130-137 | git hooks not installed | env |
| 43, 53, 78-82, 108-109, 124-125 | termlink / systemd hub absent | env |
| 27-31 | lib/ts node_modules | env; esbuild/js-yaml owned by T-4572 |
| 50-52 | python mcp absent | env |
| 66, 84-85, 127-128, 153 | vector index / ollama | env |
| 110-112 | ss absent | env |
| 37 | cron + termlink missing (greenfield doctor) | env |
| 18 | .context/approvals absent in fresh clone | existing T-4586 |
| 188-189 | /opt path in sandbox profile | existing T-4578 |
| 138-142 | detached HEAD, fresh-machine overlay | existing T-4587 |
| 113, 209 | detached HEAD: t3698 _overlay, web test_app branch | framework defect → **filed T-4617** |
| 69 | lib_costs needs ~/.claude/projects | existing T-4583 |
| 32-33, 40 | fw_costs / plugin_audit read host ~/.claude | framework defect → **filed T-4618** |

## RCA

**Symptom:** the 2026-10-21 per-failure cloud run at f028d507 reported 197 failing/hanging items (122 defect, 65 env, 9 flaky, 1 hang).
**Root cause:** not one cause — this is a triage task; each independent cause is filed as its own task in `## Triage` below with its file:line evidence.
**Why structurally allowed:** the local suite runs on a host that has termlink, installed hooks, a branch checkout, ~/.claude and the vector index, so env-dependent and corpus-drift reds never show locally; only a clean cloud clone surfaces them.
**Prevention:** the per-failure cloud run itself (T-4508) is the detector; each filed task carries its own regression pin.

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

### 2026-10-22T07:53:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4589-process-the-complete-per-failure-cloud-r.md
- **Context:** Initial task creation

### 2026-10-22T07:54:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
