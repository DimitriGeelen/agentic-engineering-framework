---
id: T-4221
name: "Triage the long-lived baselined unit reds: 28 tests in 16 files expired 2026-10-15
  (4 files untriaged) plus the load-sensitive t1719 latency budget"
description: >
  After T-4220 the pre-push ratchet still blocks on 28 baselined reds past expiry
  (16 files, owners T-3556/T-3604/T-3605/T-3609/T-3611/T-3612/T-3614/T-3615/T-2787;
  untriaged: context_safe_commands, fabric_coverage_single_source, test_bin_fw_no_heredoc_cmd_sub,
  test_cron_registry_generated_drift) and the new load-sensitive red t1719_index_one_post_write
  ('stays under the 5s budget', passes alone, fails under the 6-job suite). The operator
  extends them 14 days (runme t4221-extend-baseline); this task owns the untriaged
  ones and the per-file plan: fix, re-own to a live task, or delete a test that no
  longer measures anything. Results per file from T-4220: .context/scratch/t4220-expired-results.tsv.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
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
created: 2026-10-17T03:04:20Z
last_update: 2026-10-21T22:33:34Z
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
  - ts: '2026-10-17T03:15:26Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-17T03:16:07Z'
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
  - ts: '2026-10-21T22:15:37Z'
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
---

# T-4221: Triage the long-lived baselined unit reds: 28 tests in 16 files expired 2026-10-15 (4 files untriaged) plus the load-sensitive t1719 latency budget

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every file named in `.context/audits/unit-suite/baseline.yaml` was run alone in the foreground on current bleeding-edge and has a per-entry verdict (green-alone / red + cause) in `## Triage` below
- [x] Each red owned by T-4221 is either fixed here (with a regression test that fails without the fix) or handed to one filed task per independent cause
- [x] The baseline was not edited by hand and no entry was added (`git diff` on baseline.yaml is empty for this task's commits)
- [x] `port_in_use` (bin/watchtower.sh) and `_watchtower_port_listening` (lib/watchtower.sh) report a held port as held under pipefail when `ss` output is large; `tests/unit/t4221_port_in_use_sigpipe.bats` fails without the fix and passes with it
- [x] The T-2888 git-verb scan in `context_safe_commands.bats` reads tracked files only (not gitignored `.context/scratch`); the regression leg in the same file fails without the fix

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
grep -q '^## Triage' .tasks/active/T-4221-triage-the-long-lived-baselined-unit-red.md
timeout 300 bats tests/unit/t4221_port_in_use_sigpipe.bats > /tmp/.t4221a 2>&1 && ! grep -q "^not ok" /tmp/.t4221a && test "$(grep -c '# skip' /tmp/.t4221a)" -eq 0
timeout 300 bats -f 'T-2888|T-4221' tests/unit/context_safe_commands.bats > /tmp/.t4221b 2>&1 && ! grep -q "^not ok" /tmp/.t4221b && grep -q '^ok' /tmp/.t4221b
timeout 600 bats tests/unit/t3662_watchtower_port_allocation.bats > /tmp/.t4221c 2>&1 && ! grep -q "^not ok" /tmp/.t4221c
bash -n bin/watchtower.sh && bash -n lib/watchtower.sh
bin/fw vendor self --check --task T-4221
# 956f05f36 / e6199c726 are the operator's own runme extensions; nothing after them under T-4221 may touch the baseline
test -z "$(git log --format=%H --grep='^T-4221' 956f05f36..HEAD -- .context/audits/unit-suite/baseline.yaml)"

## Triage

Every file in `.context/audits/unit-suite/baseline.yaml` (28 files, 43 entries),
run alone in the foreground on bleeding-edge 2026-10-22, `timeout 280` per file,
load average 45–70. Raw output: `.context/scratch/t4221/<file>.out`. Every owner
listed below is a live task in `.tasks/active/`.

| File | Owner | Alone | Verdict / cause |
|---|---|---|---|
| approvals_close_ready_arcs.bats (5) | T-3611 | RED 5 | fixture has no `policy/value-drivers.yaml`; loader exits 2 — stays with T-3611 |
| atomic_yaml_write_lint.bats | T-3612 | RED | `lib/govd_sandbox.py`, `agents/audit/unit_tier.py` truncate-write YAML — stays with T-3612 |
| audit.bats | T-4325 | green | drops on regenerate |
| audit_inception_recommendation.bats | T-3609 | RED (#10) | bypass leg exits non-zero — stays with T-3609 |
| audit_split_root_asset_lint.bats | T-3614 | RED | 28 PROJECT_ROOT asset sites vs baseline 22 — stays with T-3614 |
| check_render_surface_human_ac_sigpipe.bats | T-4221 | green | drops on regenerate |
| context_safe_commands.bats | T-4221 | timeout (green in 5 min) | **fixed here** — RCA cause 2 |
| doctor_hook_counters.bats (3) | T-3615 | RED 3 | doctor no longer prints `Hook configuration valid` — stays with T-3615 |
| fabric_coverage_single_source.bats (2) | T-4221 | green | drops on regenerate |
| fw_focus_alias.bats (4) | T-4325 | green | drops on regenerate |
| fw_mode_detection.bats | T-4038 | RED (#2) + timeout | `fw doctor` exits >1 — stays with T-4038 |
| handover_push_timeout.bats (3) | T-3556 | green | drops on regenerate |
| hook_telemetry_race.bats | T-4325 | green | 5 ms budget, load-sensitive — T-3992 class |
| lib_review.bats (2) | T-3609 | RED 2 | stays with T-3609 |
| no_root_framework_markers.bats | T-2787 | green | drops on regenerate |
| review_pipefail.bats | T-3609 | RED | stays with T-3609 |
| t1719_ask_routing.bats (2) | T-4325 | timeout (#8 live ask hangs) | stays with T-4325 |
| t1719_index_one_post_write.bats | T-4221 | green | 5 s budget fails only under suite load — T-3992 class (parallel-load flakes) |
| t2243_doctor_self_vendor_templates.bats | T-3747 | green | drops on regenerate |
| t2244_audit_self_vendor_drift.bats (2) | T-3604 | green | was TIMEOUT in T-4220; drops on regenerate |
| t2298_audit_structure_no_perfile_fork.bats (2) | T-3604 | green | drops on regenerate |
| t2452_doctor_quick.bats | T-3992 | RED (#5) | `doctor --quick` exits 2 — stays with T-3992 |
| t3662_watchtower_port_allocation.bats | T-4221 | RED 3 | **fixed here** — RCA cause 1; 3/3 green after |
| t4119_terminator_handover_git_extension.bats | T-4221 | green | drops on regenerate |
| test_bin_fw_no_heredoc_cmd_sub.bats | T-4221 | RED | bin/fw:2679 and :3143 heredoc in `$(...)` — **filed T-4581** |
| test_cron_registry_generated_drift.bats | T-4221 | green | drops on regenerate |
| test_doctor_litellm_ollama.bats | T-4138 | RED (#6) | `fw doctor` exits non-zero — stays with T-4138 |
| test_operator_facing_stderr.py | T-3605 | RED | unsanitized stderr site — stays with T-3605 |

Baseline not edited; the greens leave it through `unit_suite_baseline.py
regenerate` after the next full run.

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

### Cause 1 — t3662_watchtower_port_allocation (3 reds)

**Symptom:** `watchtower.sh start` for a second project (or next to a foreign
listener) picks a port that is already held, Flask dies with "Address already in
use", start exits 1. Intermittent: depends on where the held port sorts in `ss`.

**Root cause:** `bin/watchtower.sh:75` `port_in_use` is `ss -tlnp | grep -q ":$port "`
under `set -euo pipefail` (bin/watchtower.sh:11). On this host `ss -tlnp` prints
~250 KB; when the port's line comes early, `grep -q` exits, `ss` takes SIGPIPE and
the pipeline returns 141, which `port_in_use` reports as "not in use". Measured:
5/5 runs rc=141 for the first listed port. `lib/watchtower.sh:314`
`_watchtower_port_listening` has the same idiom (L-387 class).

**Why structurally allowed:** the test only fails when `ss` output exceeds what it
writes before grep exits, i.e. on a busy host; on a dev box with a few sockets the
pipe never breaks, so the allocator test was green where it was written.

**Prevention:** both checks now count with `grep -c` (reads all input, no early
exit) on `ss -tln`; `tests/unit/t4221_port_in_use_sigpipe.bats` stubs a large
`ss` output with the port first, under pipefail, for both functions.

### Cause 2 — context_safe_commands.bats T-2888 git-verb scan (timeout)

**Symptom:** the test takes 5 min alone (29 s CPU) and is killed by the suite's
per-file timeout; green when it is allowed to finish.

**Root cause:** `tests/unit/context_safe_commands.bats:299` scans "our own tooling"
with `grep -r "$FRAMEWORK_ROOT"`, which walks the gitignored `.context/scratch`
(22,183 matching files, 202k of 226k matches) inside a 36 GB `.context/`. Those are
not our tooling, and the walk is I/O-bound.

**Why structurally allowed:** the scratch tree grows by worker output over time;
the scan was cheap when it was written.

**Prevention:** the scan reads `git ls-files` (tracked files only, falls back to
`grep -r` outside a git checkout); a regression leg builds a temp repo with an
untracked script and asserts its verb is not collected.

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

### 2026-10-17T03:04:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4221-triage-the-long-lived-baselined-unit-red.md
- **Context:** Initial task creation

### 2026-10-21T22:33:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
