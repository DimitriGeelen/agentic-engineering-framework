---
id: T-3694
name: "Design-conformance gate (finish): T-3691 closed with items 3 and 5 deferred
  to non-existent owners — audit FAIL/doctor WARN on unowned or orphaned register
  rows, stale-keystone WARN on /approvals"
description: >
  T-3691's result deferred its own items 3 (fw audit FAIL: row with no owner, missing
  owner, or owner completed while row unbuilt) and 5 (stale keystone >3 days captured:
  audit WARN + /approvals line) to 'T-3692/T-3693'. T-3692 is an unrelated task and
  T-3693 does not exist: the exact pattern the gate exists to stop. Item 3 must flag
  the sidecar register now: T-3561 is completed while R2-R5 are unbuilt; re-point
  those rows to the S1-finish task.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [design-conformance, arc-011, T-3682, false-completion]
arc_id: arc-011
components: [agents/audit/audit.sh, agents/task-create/update-task.sh, bin/fw, 
      lib/design_register.py, web/blueprints/approvals.py, 
      web/templates/_approvals_content.html]
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
created: 2026-10-01T23:22:44Z
last_update: '2026-10-02T23:30:26Z'
date_finished: 2026-10-02T11:35:57Z
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
  - ts: '2026-10-01T23:24:42Z'
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
      (workflow:build); effort=8 (lines=287,acs=11)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-02T23:30:26Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 5
      tier: 2
      effort: 8
    rationale: blast_radius=5 (6-components-medium-blast); tier=2 
      (workflow:build); effort=8 (lines=345,acs=12)
    rubric_sha: e4a00f38e801
---

# T-3694: Design-conformance gate (finish): T-3691 closed with items 3 and 5 deferred to non-existent owners — audit FAIL/doctor WARN on unowned or orphaned register rows, stale-keystone WARN on /approvals

## Context

Contract: T-3691 description items 3 and 5. Design register: docs/architecture/sidecar-target-architecture.md §7.
Audit of the gap: docs/reports/T-3682-sidecar-design-conformance-audit.md. Review brief:
docs/reports/T-3694-review-brief.md.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw audit` (structure section) FAILs when a register row has no owner_task, a non-existent owner_task, or an owner that is completed while the row is not built — predicate lib/design_register.py `violations`, called from agents/audit/audit.sh:check_register_requirements
- [x] `fw doctor` WARNs on the same register row conditions (bin/fw do_doctor, same predicate)
- [x] Sidecar register re-pointed so each row's owner commits to it in an AC: R2, R4, R6 → T-3693 (its ACs: inject-when-ready, Stop/UserPromptSubmit ready flag, sender state ledger); R3, R5 → T-3684 and R12 → T-3688 (each given an AC naming the rows, whose descriptions already said 'Gap rows R2-R5' / 'Gap row R12'); R7, R14, R15 stay on T-3685 (S-LIVE), now with an AC naming them; no row points at T-3692; live `violations` exits 0
- [x] Stale keystone: audit WARNs on a captured task that owns an unbuilt register row or is an arc's keystone / slice 1 and has stayed captured >3 days
- [x] Stale keystone appears on Watchtower /approvals (section-stale-keystones) with task link, arc link and days-captured count
- [x] Close gate refuses a close whose own result hands work to a missing, inactive, or unrelated task (one that never mentions the closer), including when the target is backticked, linked, emphasised or wrapped onto the next line — fixture: T-3691's own task file, tests/fixtures/t3694/T-3691-as-closed.md
- [x] Close gate also refuses a task that closes while owning an unbuilt register row (T-3561 shape), and resolves arcs by `id:` so arc-011 slices are actually gated
- [x] Tests for every gate with control and treatment: tests/governance/test_t3694_conformance_gate.bats (12), tests/unit/test_t3694_design_register.py (25); existing tests/governance/test_register_requirements_gate.bats green with its assertions pinned to the gate's own messages; captured run in docs/reports/T-3694-test-evidence.txt
- [x] All verification commands pass (tests green, live register clean, vendor in sync, watchtower current) — 2026-10-02: drift cleared once T-3693 committed and vendored lib/sidecar/direct.py; `bin/fw vendor self --check` in sync; codex round 4 PASS (docs/reports/T-3694-review-codex.md)

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
- [ ] [REVIEW] Watchtower /approvals "Stale Keystones" section reads cleanly and its links work
  **Steps:**
  1. List what the section should show: `cd /opt/999-Agentic-Engineering-Framework && python3 lib/design_register.py stale-keystones`
  2. If step 1 prints nothing (today every captured sidecar slice is under 3 days old; T-3684 and T-3685 cross the line on 2026-10-05 if still captured), the live page correctly has no section; `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_t3694_design_register.py -k renders -q` proves the rendering against a fixture meanwhile
  3. Get the address: `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url`, open `<that url>/approvals` and scroll to "Stale Keystones"
  4. Click a task id and an arc link
  **Expected:** one card per task from step 1: linked task id, red "captured N days" badge, arc link, task name, reasons line; links open /tasks/T-XXXX and /arcs/<slug>
  **If not:** screenshot the section and note the broken element (styling, alignment, link target)

## Verification

grep -q "R3 (30 s configurable tick) and R5" .tasks/active/T-3684-*.md && grep -q "register row R12" .tasks/active/T-3688-*.md && grep -q "rows R7 (liveness.yaml" .tasks/active/T-3685-*.md
python3 -m pytest tests/unit/test_t3694_design_register.py -q > /tmp/.t3694-py 2>&1 && grep -q " passed" /tmp/.t3694-py && ! grep -qE "failed|error" /tmp/.t3694-py
timeout 900 bats tests/governance/test_t3694_conformance_gate.bats > /tmp/.t3694-gate 2>&1 && ! grep -q "^not ok" /tmp/.t3694-gate
test "$(grep -c '# skip' /tmp/.t3694-gate)" -eq 0
timeout 900 bats tests/governance/test_register_requirements_gate.bats > /tmp/.t3694-reg 2>&1 && ! grep -q "^not ok" /tmp/.t3694-reg
test "$(grep -c '# skip' /tmp/.t3694-reg)" -eq 0
python3 lib/design_register.py violations
bash -c '! grep -q "owner_task: T-3692" docs/architecture/sidecar-target-architecture.md'
bash -n agents/audit/audit.sh && bash -n agents/task-create/update-task.sh && bash -n bin/fw
bin/fw vendor self --check
bin/fw watchtower current
curl -sf "$(bin/fw watchtower url)/approvals" -o /tmp/.t3694-appr.html

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

### 2026-10-02 — the sidecar register was invisible to the gate built for it
- **What changed:** arc-011 lives in .context/arcs/parallel-execution-aef.yaml (id: arc-011) and linked no design doc, so the T-3691 close gate (filename lookup, design_doc only) never found the sidecar register. T-3691's own treatment tests were also red at its close: its matcher knew only the word "deferred", never "defers".
- **Plan impact:** one shared predicate (lib/design_register.py) for audit, doctor, /approvals and the close gate; arc lookup by id; register_docs: on arc-011; every verb form matched.
- **Triggered:** the register re-point used each task's own ACs rather than a single owner, because the S1-finish ACs cover R2/R4/R6 but not the tick (R3) or urgent bypass (R5).

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

**Recommendation:** GO
**Rationale:** Items 3 and 5 of T-3691 and the self-deferral hole are built on one predicate and proven through the real entry points (update-task.sh, audit.sh, bin/fw doctor, /approvals) against throwaway project roots, each with a control. The T-3691 case is reproduced from T-3691's own task text and is refused; a mutation that disables the gate turns that test red. The live sidecar register is clean because every row now points at the task whose ACs build it, not because the check is lenient (the same check FAILs on the pre-repoint register).
**Evidence:**
- tests/governance/test_t3694_conformance_gate.bats: 12/12 ok, 0 skipped
- tests/unit/test_t3694_design_register.py: 25 passed
- tests/governance/test_register_requirements_gate.bats: 5/5 ok (was 3/5 on T-3691's code)
- docs/reports/T-3694-review-brief.md, docs/reports/T-3694-test-evidence.txt, docs/reports/T-3694-review-codex.md (round 1 FAIL, findings fixed) docs/reports/T-3694-review-codex-r2.md (round 2 FAIL: T-3685 AC, fixed) and docs/reports/T-3694-review-codex-r3.md
- The one open item is the [REVIEW] rendering check of /approvals, which is the operator's.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-02 — owners of the re-pointed sidecar rows
- **Chose:** R2, R4, R6 → T-3693; R3, R5 → T-3684; R12 → T-3688.
- **Why:** the brief said to point R2-R5 at T-3693, on the premise that T-3561 owned them. The register showed R2-R5 on T-3684 and the completed-owner violation on R6 (T-3561). T-3693's ACs build the ready-flag hooks, the inject-when-ready path and the sender state ledger (R4, R2, R6); they contain no tick and no urgent bypass, which T-3684's description names (R3, R5). T-3688's description names "Gap row R12"; T-3690 retires the legacy address. Pointing a row at a task that will not build it is the false-owner pattern this gate exists to stop.
- **Rejected:** all of R2-R5 on T-3693 (R3/R5 would read owned by a task that does not build them).
- **Follow-through (review rounds 1-2):** T-3684, T-3688 and T-3685 had placeholder ACs only, so an AC naming their rows was added to each; only that line was committed for T-3685 and T-3688, whose other uncommitted edits belong to another session.

### 2026-10-02 — self-deferral relatedness test
- **Chose:** a deferral target must exist, be active, and mention the closing task's id anywhere in its file.
- **Why:** deterministic, and it caught both halves of T-3691 (T-3693 absent, T-3692 an unrelated bug). Measured over 129 completed T-35xx/T-36xx tasks: 4 hits, all deferrals to tasks that never named the closer.
- **Rejected:** name-similarity scoring (not deterministic); arc_id equality (T-3692 and the S-slices share an arc).
- **Scope of the scan:** the task's own result (ACs, Evolution, Recommendation, Decisions, other sections); Context, RCA, Updates, Reviewer Verdict, comments and code spans are skipped because they describe other tasks.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-01T23:22:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3694-design-conformance-gate-finish-t-3691-cl.md
- **Context:** Initial task creation

### 2026-10-01T23:24:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-28128ebe
- **Timestamp:** 2026-10-02T11:42:44Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#8 (Agent)** — Tests for every gate with control and treatment: tests/governance/test_t3694_conformance_gate.bats (12), tests/unit/test_t3694_design_register.py (25); existing tests/governance/test_register_requirem
  - **AC-verify-mismatch** (narrow, heuristic) — `path=docs/reports/T-3694-test-evidence.txt in: Tests for every gate with control and treatment: tests/governance/test_t3694_conformance_gate.bats (12), tests/unit/test_t3694_design_register.py (25)`

### 2026-10-02T11:35:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
