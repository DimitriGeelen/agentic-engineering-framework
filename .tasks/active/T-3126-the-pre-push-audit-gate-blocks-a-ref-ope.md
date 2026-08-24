---
id: T-3126
name: "the pre-push audit gate blocks a ref operation on working-tree health findings"
description: >
  T-3125 fixed the self-vendor pre-push gate to judge the tree being pushed. The audit
  gate immediately downstream still blocks on findings computed from the WORKING TREE.
  Two of them, both from a concurrent session's uncommitted work, held the push after
  T-3125 cleared: 'Self-vendor drift: libs class - 3 file(s) out of sync' (uncommitted
  bin/fw and agents/audit/audit.sh) and 'Invariant suite: 1 of 74 RED' (invariant
  43, two untracked .bats files that a runner would collect). Neither is present in
  the ref being pushed. The audit is not wrong to read the working tree - that is
  what a health check is for. The defect is the COUPLING: a working-tree health FAIL
  is wired to refuse a ref-based operation, so one session's in-flight edits block
  every other session's push, which is exactly the class T-3125 just closed one surface
  of. Options are to partition audit findings into ref-scoped and worktree-scoped
  and gate only on the former, or to keep the gate but evaluate the failing checks
  against the pushed ref the way T-3125's hook now does. Sibling of T-2607 (vendor-self
  and audit disagree on the file-class list) but a different axis: this is about WHICH
  TREE, not which files.

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
created: 2026-08-23T21:41:55Z
last_update: 2026-08-24T20:29:25Z
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
  - ts: '2026-08-23T21:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-23T21:45:13Z'
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

# T-3126: the pre-push audit gate blocks a ref operation on working-tree health findings

## Context

The pre-push hook runs `audit.sh --section structure` and blocks on exit 2. The audit
reads the WORKING TREE; the push operates on a REF. A FAIL owned by another session's
uncommitted or untracked files therefore refuses a push of a commit that does not
contain them. Same proxy-vs-property class T-3125 closed on the sibling self-vendor
gate. Fix shape (decided): PARTITION — tag each structure finding with its scope, and
let the gate act only on ref-scoped FAILs. The audit's verdicts are unchanged.

### AC1 — classification of every `--section structure` FAIL site

Structure section spans `agents/audit/audit.sh:632-2785`. Scope definition used
throughout: a finding is **REF-scoped** when it is a property of committed content
(so it may be present in the ref being pushed); it is **WORKTREE-scoped** when it is a
property of state no git ref contains — uncommitted edits, untracked files, or host
state outside the repo entirely. `BOTH` / not-cheaply-provable resolves to REF
(fail safe = keep blocking).

| # | Line | Check (FAIL title) | Reads | Scope | Evidence / basis |
|---|------|--------------------|-------|-------|------------------|
| 1 | 639 | Tasks directory missing | `$TASKS_DIR` presence in worktree | REF (fail-safe) | Directory presence; a ref lacking `.tasks/` is equally possible. Not cheaply separable → default. |
| 2 | 818 | Duplicate task IDs detected (G-052) | task files across all corpus views | REF (fail-safe) | Colliding files may be tracked, untracked, or mixed. Mixed = BOTH → ref. |
| 3 | 871 | YAML parse error: `<project yaml>` | `.context/project/*.yaml`, `policy/*.yaml`, `.context/arcs/*.yaml` | REF (fail-safe) | Tracked files; a dirty copy could be worktree-only, but corruption in the ref is the case the gate exists for. |
| 4 | 903 | YAML parse error: inbox.yaml | `.context/inbox.yaml` (tracked) | REF (fail-safe) | Same as #3. |
| 5 | 1070 | Seed routes to missing corpus map | `lib/seeds/tasks`, `.context/designer/projects` | REF (fail-safe) | Both sides tracked; ships to consumers via `fw init` from the ref. |
| 6 | 1671 | inline `arc:<slug>` tag-only scan(s) | tracked source under `lib web agents bin tools` | REF (fail-safe) | Source lint; a hit in an uncommitted edit is possible but not separable per-hit here. |
| 7 | 1725 | PROJECT_ROOT resolution of framework-owned assets | tracked `*.py` under `web/ lib/` | REF (fail-safe) | Same as #6. |
| 8 | 2161 | Fabric drift: coverage expander failed | `agents/fabric/lib/expand_patterns.py` (tracked) | REF (fail-safe) | Instrument-failure; the instrument is committed source. |
| 9 | 2240 | Cron drift: registry ahead of generated | `.context/cron-registry.yaml` vs `.context/cron/agentic-audit.crontab` — **both tracked** | REF | Deterministic function of two tracked files; when both are clean the drift IS in the ref. Dirty case = BOTH → ref. |
| 10 | 2251 | Cron drift: generated differs from deployed | tracked crontab vs **`/etc/cron.d/`** | WORKTREE (host) | The comparand is host state. No git ref contains `/etc/cron.d`; pushing cannot create or clear it. Statically provable, unconditional. |
| 11 | 2256 | Cron drift: generated but not installed | existence of **`/etc/cron.d/agentic-audit-<slug>`** | WORKTREE (host) | Same as #10. |
| 12 | 2332 | cron(...): USER-field syntax but no install | **`$FW_CRON_INSTALL_DIR`/`/etc/cron.d`** | WORKTREE (host) | Same as #10. |
| 13 | 2515 | Self-vendor drift: libs class | worktree `<rel>` vs worktree `.agentic-framework/<rel>` | **DYNAMIC** | Recomputed against HEAD blobs per drifting pair (`git rev-parse HEAD:<p>`), the T-3125 method. Any pair still drifting in HEAD → REF; none → WORKTREE. |
| 14 | 2522 | Self-vendor drift: templates class | same, `.tasks/templates/*.md` | **DYNAMIC** | Same as #13. |
| 15 | 2574 | Invariant suite: N of M RED | `bats tests/lint/` over the worktree | **DYNAMIC** | Per RED test, two independent grounds for worktree scope: **(a)** the `.bats` file *declaring* it is untracked-in-HEAD or modified-vs-HEAD (the assertion is in no ref); **(b)** its failure evidence names ≥1 repo path and *every* named path is uncommitted-in-HEAD (the assertion is committed but its whole subject is not — this is `no-untracked-test-files.bats`, the literal AC6 case). Attribution via `lib/bats_red_attribution.py`, which excludes bats's own `(in test file …)` marker from the evidence set. WORKTREE only if every RED test qualifies and ≥1 was attributable; any RED test about committed content, or any unattributable one, → REF. |

Notes:
- #10-#12 are host state, not working-tree state. They satisfy the operative property
  the gate needs ("not a property of the commit being pushed") and are emitted with
  tag `worktree` and reason `host`. The audit still FAILs on them; `fw doctor` and the
  cron close-gate (L-364) are unaffected. Only the *push* stops being coupled to one
  host's deployment state.
- #13-#15 carry the two findings that held the 2026-08-23 push (AC6). Both are decided
  per-run, not statically — a genuinely committed self-vendor drift or a genuinely
  committed RED invariant still tags `ref` and still blocks.
- Fail-safe defaults everywhere: no git worktree, unparseable bats output, failed
  attribution, or a missing `AUDIT-SCOPE:` line all resolve to REF / block.

## Acceptance Criteria

### Agent
- [x] AC1 — Ground truth first: enumerate every audit `--section structure` check that can emit FAIL, and classify each as REF-SCOPED (the finding is a property of the commit being pushed) or WORKTREE-SCOPED (the finding is a property of uncommitted/untracked files and would not exist in a clean checkout of the pushed ref). Record the classification and its evidence in the task body. If a check is genuinely BOTH, say so and treat it as ref-scoped.
- [x] AC2 — Audit findings carry their scope. Each structure-section finding emits a machine-readable scope tag (`ref` or `worktree`). Adding the tag must not change any existing PASS/WARN/FAIL verdict — the audit reports exactly what it reported before, plus the tag.
- [x] AC3 — The pre-push gate blocks only on ref-scoped FAILs. A worktree-scoped FAIL is reported in full and downgraded to a non-blocking WARN whose message says plainly that the finding is in the working tree, is not in the ref being pushed, and is therefore not blocking this push.
- [x] AC4 — A ref-scoped FAIL still blocks. Blocking behaviour on genuine FAILs is unchanged, including the exit-75 could-not-run branch (T-2930), which must keep blocking — a gate that did not run is not a gate that passed.
- [x] AC5 — Regression test pinning both directions, in its own fixture tree (L-599: do not pin to a live defect or the live corpus). At minimum: (a) worktree-only FAIL → push allowed + WARN; (b) ref FAIL → BLOCKED; (c) both present → BLOCKED; (d) exit 75 → BLOCKED. State how many tests fail against the pre-change code — a test that passes before the fix guards nothing.
- [x] AC6 — The literal 2026-08-23 shape is covered: uncommitted `bin/fw` + `agents/audit/audit.sh` producing 'Self-vendor drift: libs class' and two untracked `.bats` files producing 'Invariant suite: 1 of 74 RED', on a ref containing neither, must push cleanly.

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

bash -n agents/git/lib/hooks.sh
bash -n agents/audit/audit.sh
bats tests/unit/t3126_prepush_audit_gate_scope.bats > /tmp/.t3126-bats.out 2>&1 && grep -qE "^ok " /tmp/.t3126-bats.out && ! grep -q "^not ok" /tmp/.t3126-bats.out
# Lint: this repo carries 4 standing FAILs (agents/sessions/{claude-code,antigravity}/list.sh
# and their vendored copies — each is a python3 script named .sh, so shellcheck refuses it with
# SC1071). They predate this task and are untouched by it. So the assertion is NOT "zero FAILs"
# — that can never pass here — and NOT "exactly 4 FAILs" either, which would pin a live defect
# (L-599) and go red the moment someone fixes those scripts. It is: no file this task touched
# is among the failures.
bin/fw test lint > /tmp/.t3126-lint.out 2>&1; ! grep -E "^\s*\x1b?\[?[0-9;]*m?FAIL" /tmp/.t3126-lint.out | grep -qE "audit\.sh|hooks\.sh|bats_red_attribution\.py"
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"

## RCA

**Symptom:** On 2026-08-23 a push was refused by the pre-push audit gate on two
`--section structure` FAILs — `Self-vendor drift: libs class — 3 file(s) out of sync`
(a concurrent session's uncommitted `bin/fw` and `agents/audit/audit.sh`) and
`Invariant suite: 1 of 74 RED` (invariant 43, two untracked `.bats` files the runner
collects). The commit being pushed contained neither.

**Root cause:** A working-tree health verdict was wired directly to a ref-based
decision. `audit.sh` reads the working tree — correctly, that is what a health check
is for — and the gate consumed only its exit code, which carries no information about
*which tree* a failure lives in. With no scope in the signal, the gate could not
distinguish "this commit is broken" from "somebody's editor is open".

**Why structurally allowed:** the same proxy-vs-property substitution T-3125 had just
closed on the sibling self-vendor gate in the same file. Exit code 2 was treated as a
property of the push; it is a property of the filesystem at audit time. Nothing in the
audit's output made the difference expressible, so no consumer could have honoured it
however carefully written. The failure mode is also self-clearing — the concurrent
session commits, the block evaporates, and no artefact survives to be counted — which
is why it recurred rather than accumulating into a visible defect.

**Prevention:** the audit now partitions its own findings. Every structure FAIL carries
a `Scope:` line and the run emits `AUDIT-SCOPE: fails=N ref=X worktree=Y`; the gate
blocks iff `X > 0`, iff the line is absent (an audit predating the contract is never
read as a clean bill of health), or iff the audit did not run (exit 75, T-2930,
untouched). `tests/unit/t3126_prepush_audit_gate_scope.bats` pins both directions in a
synthetic fixture — 15 of its 20 tests fail against the pre-change source, and the 5
that pass are the invariant-preservation cases that must not change. Fail-safe is the
default everywhere: unreadable git, unattributable test, unparseable count, and missing
scope line all resolve to `ref` and keep blocking.

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

### 2026-08-23T21:41:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3126-the-pre-push-audit-gate-blocks-a-ref-ope.md
- **Context:** Initial task creation

### 2026-08-24T20:29:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
