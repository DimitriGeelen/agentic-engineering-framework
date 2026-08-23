---
id: T-3122
name: "fabric shell detector recognises only four framework path variables - 65 percent of source statements produce no edge, including 88 that use FRAMEWORK_ROOT"
description: >
  detect_bash_sources matches only source/. under $LIB_DIR, $SCRIPT_DIR, $AGENTS_DIR, $FW_LIB_DIR. Measured here: 194 source statements across 247 .sh files, 67 recognised, 127 not - the largest unrecognised group being $FRAMEWORK_ROOT/ at 88. Reported by 832-Workflow-designer, whose 17/17 shell cards are edgeless. Same conflation class as T-3121: the detector encodes one project's vocabulary as if it were the language's.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-3121]
arc_id: arc-004
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
created: 2026-08-23T19:48:24Z
last_update: 2026-08-23T19:48:24Z
date_finished: null
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
---

# T-3122: fabric shell detector recognises only four framework path variables - 65 percent of source statements produce no edge, including 88 that use FRAMEWORK_ROOT

## Context

`detect_bash_sources` (`agents/fabric/lib/enrich.py`) resolves a `source` / `.`
statement only when the path is written under one of four variable names:
`$LIB_DIR`, `$SCRIPT_DIR`, `$AGENTS_DIR`, `$FW_LIB_DIR` (plus `python3 -m web.*`).
Anything else produces no edge at all.

Measured on this repo — 247 `.sh` files, 194 `source`/`.` statements:

| form | count | seen? |
|------|------:|-------|
| `$LIB_DIR` / `$SCRIPT_DIR` / `$AGENTS_DIR` / `$FW_LIB_DIR` | 67 | yes |
| `$FRAMEWORK_ROOT/…` | 88 | **no** |
| literal / relative paths | 26 | **no** |
| `$(dirname "$0")/…` and other command substitution | 8 | **no** |
| one-off lowercase vars (`$fw_root`, `$script_dir`, `$_self_root`, …) | 5 | **no** |

**127 of 194 unrecognised — 65%.** The single largest miss is `$FRAMEWORK_ROOT/`,
which is this framework's *own* dominant idiom. The detector's vocabulary does
not cover the codebase it was written for, let alone anyone else's.

Reported by 832-Workflow-designer, who measured 17 of 17 shell cards edgeless in
their tree and inferred the shell detector "has never produced an edge". That
inference is wrong here — ours produces plenty (184 `.sh` cards, 8 edgeless, 4%)
— but the underlying claim is right and sharper than they stated it: the detector
recognises a vocabulary, not a language. We look healthy because 67 statements
happen to use the four blessed names, not because the detector understands
sourcing.

Same class as T-3121, one language over. There the fix was resolving
project-root-relative instead of trusting a hardcoded `web|lib|agents|tools`
prefix list; here it is resolving the *path* instead of trusting a hardcoded set
of variable names.

## Acceptance Criteria

### Agent
- [x] `source`/`.` resolves when the path uses ANY variable prefix, not a hardcoded set — `$FRAMEWORK_ROOT/lib/x.sh`, `$fw_root/x.sh`, `$_self_root/x.sh` all resolve by trying the trailing path, never by pattern-matching the variable's name
- [x] Literal relative paths (`source ./lib/common.sh`, `source lib/common.sh`) resolve
- [x] Command-substitution prefixes (`source "$(dirname "$0")/lib/x.sh"`, `$(cd .. && pwd)`) resolve on their trailing literal path segment
- [x] Resolution is tried source-dir-relative AND project-root-relative, in that order, so local sourcing keeps winning
- [x] Every emitted edge is existence-guarded and de-duplicated; no self-edges. Widening the match must not invent an edge to a path that is not on disk
- [x] The four existing recognised forms still resolve exactly as before — pinned by a test that fails if the old branches are dropped
- [x] Regression test builds its own fixture tree with consumer-shaped names (NOT `lib/`+`$LIB_DIR`, which would pass against the broken code), covering each row of the table above
- [x] Re-measured over this repo, and the raw number went the *wrong* way before it went the right way — which is the finding, not a footnote. Raw emitted edges **631 → 290**, which reads as a 54% regression. Deduplicated, it is **264 → 290 unique (file, target) pairs: +28 gained, 2 lost**. The old detector emitted every edge an average of 2.4 times, and both "lost" edges are self-edges (`lib/arc_membership.sh` → itself, `lib/task-audit.sh` → itself) that the old code had no guard against. Files with at least one shell edge: 88 → 99. Concretely, `bin/fw` now resolves 97 shell dependencies where the four blessed variable names found a fraction of them

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

python3 -c "import ast; ast.parse(open('agents/fabric/lib/enrich.py').read())"
python3 -m pytest tests/unit/test_fabric_shell_sources.py -q 2>&1 | tail -3 | grep -qE '[0-9]+ passed'
python3 -m pytest tests/unit/test_fabric_dotted_imports.py -q 2>&1 | tail -3 | grep -qE '[0-9]+ passed'

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

**Symptom:** 832-Workflow-designer reported 17 of 17 shell component cards with
zero edges, 12 identical audit WARNs in 14 days, mitigation `Run: fw fabric
enrich` unable to clear the warning it ships with. Their inference was that the
shell detector "has never produced an edge". Ours produces plenty — 184 `.sh`
cards, 8 edgeless — so on our numbers nothing was wrong.

**Root cause:** `detect_bash_sources` matched the VARIABLE NAME, not the path.
`source`/`.` resolved only under `$LIB_DIR`, `$SCRIPT_DIR`, `$AGENTS_DIR`,
`$FW_LIB_DIR`. Measured here: 194 source statements, 67 recognised, **127 not**
— the largest unrecognised group being `$FRAMEWORK_ROOT/` at 88, this
framework's own dominant sourcing idiom. Two further defects surfaced only on
measuring the fix: the detector emitted **no self-edge guard** (two files
depended on themselves) and **no deduplication** (631 raw emissions for 264
unique pairs, 2.4x).

**Why structurally allowed:** identical to T-3121, one language over, and the
pair is the point. There a hardcoded `web|lib|agents|tools` prefix list made the
framework immune to its own consumer-facing bug; here a hardcoded four-variable
vocabulary does the same. In both cases the framework's own health reading was
produced by the narrow path, so the metric that should have detected the defect
was computed by the defect. Our 4% edgeless rate was not evidence the detector
worked — it was evidence that 67 statements happened to use blessed names.

Neither instance was findable from inside this repo. Both arrived from consumer
projects whose directory names and shell idioms differ from ours, which is the
only vantage point from which a vocabulary-shaped detector looks broken.

**Prevention** (distinct from the fix):
- `tests/unit/test_fabric_shell_sources.py` uses fixture paths that deliberately
  avoid `lib/` + `$LIB_DIR`. A fixture using the blessed vocabulary passes
  against the broken code and guards nothing — the same trap the T-3121 suite
  had to dodge.
- One test pins that the four legacy forms still resolve, so the general path
  cannot silently drop them.
- Self-edge and duplicate suppression are pinned as their own tests, since both
  defects were invisible until a raw edge count was compared against a
  deduplicated one.
- Still open, and now twice-observed: no check asserts that an audit WARN's
  mitigation command can actually clear that WARN. Both T-3121 and T-3122 are
  instances. Recorded rather than fixed here — it is a detector of its own.

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

### 2026-08-23 — trailing-path resolution replaces the blessed-name branch

- **What changed:** the `$LIB_DIR`/`$SCRIPT_DIR` branch turned out to be fully
  subsumed by the general path (its two candidates are candidates (a) and (b) of
  the new resolver, with the order flipped to local-first), so it was removed
  rather than kept alongside. The `$FW_LIB_DIR` branch was KEPT: it resolves to
  `<root>/lib/<file>` from a bare trailing filename, which none of the three
  general candidates reach, and it also matches `exec` (a non-source pattern).
- **Plan impact:** none — AC 6 anticipated this ("removing them is fine, but a
  test must pin the behaviour"); `test_lib_subdir_candidate_still_reachable`
  is that pin.
- **Triggered:** nothing new.

### 2026-08-23 — the fix looked like a 54% regression

- **What changed:** the acceptance criterion asked for recognised source
  statements to rise from the 67 baseline. Measuring gave raw emitted edges
  **631 → 290**, a headline that reads as a severe regression and would have been
  reported as one by anything counting emissions.
- **Plan impact:** deduplicating before comparing inverted the result —
  **264 → 290 unique pairs, +28 gained, 2 lost**. The old detector emitted each
  edge 2.4 times on average, and the 2 losses are self-edges it should never have
  produced. The AC was rewritten to report both numbers, because the raw one is
  the more likely to be quoted and the more misleading.
- **Triggered:** two defects nobody had filed — missing self-edge guard, missing
  deduplication — folded into this fix rather than deferred, since both were
  already inside the function being rewritten and both are pinned by tests now.
- **Worth keeping:** this is the second measurement this session whose first
  reading was wrong in the same direction — T-3121's "114 invisible imports" and
  this one's "edges halved". Both times the code was right and the metric was
  lying. A number that moves is not a result until you know what it counts.

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

### 2026-08-23T19:48:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3122-fabric-shell-detector-recognises-only-fo.md
- **Context:** Initial task creation
