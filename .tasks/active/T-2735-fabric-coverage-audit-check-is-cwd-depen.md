---
id: T-2735
name: "Fabric coverage audit check is CWD-dependent, non-recursive, and cannot warn"
description: >
  Fabric coverage audit check is CWD-dependent, non-recursive, and cannot warn

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
created: 2026-08-02T11:45:35Z
last_update: '2026-08-02T12:00:11Z'
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
  - ts: '2026-08-02T12:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T12:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2735: Fabric coverage audit check is CWD-dependent, non-recursive, and cannot warn

## Context

`audit.sh` answers "which source files have no fabric card?" **twice**, with two
private glob implementations, and neither is the canonical one.

T-1842 already fixed this class: it extracted `expand_patterns.py` as the
"single source of truth for glob + exclude" after a parallel copy in
`register.sh` / `drift.sh` produced 5946 junk cards undetected for ~22 days.
Both of those callers were migrated. **The two audit copies were never
migrated**, so the centralisation is real but incomplete, and the surface that
reports a coverage verdict to the operator is the one still running its own glob.

Measured here, same repo, same run — three answers to one question:

| Implementation | unregistered |
|---|---|
| `audit.sh:1405` (the PASS-only check) | 0 |
| `audit.sh:1499` (the drift WARN check) | 1 |
| `expand_patterns.py` (canonical, T-1842) | 1 |

The `:1405` copy has three independent defects, any one of which alone zeroes it:
- **no `PROJECT_ROOT` join** — globs resolve against CWD. Measured: total files
  matched drops to **0** when the audit runs from anywhere but the project root.
- **no `recursive=True`** — Python's `**` does not recurse without it. Measured
  on the one `**` pattern we have: `lib/**/*.py` sees 12 files instead of 45,
  **blind to 33**.
- **both verdict arms call `pass()`** — `>0` prints "(coverage growing)", `==0`
  prints "0 unregistered". No value of the metric can recruit attention, so
  fixing the count alone would still produce a check nobody can act on.

The `:1499` copy resolves the root and recurses, but ignores `exclude:` — the
key `expand_patterns.py` exists to honour.

Reported by 832 at rail-398 as three defects against vendored framework code
(their A/B/C). This task is their **C**, which must land before the watch-pattern
work (their B, our T-2737): widening the patterns first makes the good check
start warning while the broken check prints `0 unregistered` PASS beside it.

Sibling to T-2732 — a check that fires, passes, and asserts almost nothing.

## Acceptance Criteria

### Agent
- [x] No audit fabric check globs `watch-patterns.yaml` itself. The `:1405` copy
      no longer answers the coverage question at all (it reports registered and
      orphaned card counts only); the drift check answers it via
      `expand_patterns.py`, the T-1842 canonical expander
- [x] `audit.sh` contains exactly **one** live answer to "which watched source
      files have no card", and it equals `expand_patterns.py`'s answer —
      asserted differentially, so a future divergence is a test failure rather
      than a silent disagreement. Two checks that merely *agree* is the state
      that hid this for 14 days; the fix is one question, one answer
- [x] The coverage count is CWD-independent: running the check from outside
      PROJECT_ROOT yields the same number as running it from inside
- [x] `**` patterns resolve recursively (`lib/**/*.py` yields 45, not 12)
- [x] `exclude:` entries are honoured by the audit path (previously dropped).
      Occupancy here is zero — our one `exclude:` is neutralised by a second
      pattern that re-adds the same files — so this is proven on a fixture where
      the exclude carries weight, and a discrimination control asserts canonical
      and naive expansion are separable at all
- [x] The coverage verdict can reach a non-PASS state — proven by running the
      real audit against a fixture project three ways: fully carded → PASS,
      one uncarded file injected → WARN, corrupt watch file → FAIL. Not by
      reading the branch
- [x] Shape guard: a test derived from source (no filename allowlist) fails if a
      private glob over watch-patterns is reintroduced into `audit.sh`, with a
      guard control proving the guard catches a reintroduced instance

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
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# --- T-2735 ---
# Suite green, asserted by name+absence rather than by index (G-015).
out=$(bats tests/unit/fabric_coverage_single_source.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
# audit.sh contains no private glob over watch-patterns (source-derived shape guard)
! grep -nE "glob\.glob\((os\.path\.join\([^)]*)?p\['glob'\]|glob\.glob\(os\.path\.join\(PROJECT_ROOT, g\)" agents/audit/audit.sh
# both audit fabric checks route through the canonical expander
grep -q "expand_patterns.py" agents/audit/audit.sh
# exactly one live coverage claim, and it equals the canonical expander's answer
a=$(bash agents/audit/audit.sh --sections structure 2>&1 || true); echo "$a" | grep -q "Fabric: [0-9]* registered card(s)" && ! echo "$a" | grep -qE "registered, [0-9]+ unregistered"
a=$(bash agents/audit/audit.sh --sections structure 2>&1 || true); live=$(echo "$a" | grep -oE "Fabric drift: [0-9]+ source" | grep -oE "[0-9]+" || echo 0); canon=$(python3 -c "import subprocess,glob,os,yaml,sys; r=os.getcwd(); reg={d['location'] for c in glob.glob('.fabric/components/*.yaml') if (d:=yaml.safe_load(open(c))) and d.get('location')}; o=subprocess.run([sys.executable,'agents/fabric/lib/expand_patterns.py','.fabric/watch-patterns.yaml',r],capture_output=True,text=True).stdout.split(); print(len([f for f in o if f not in reg]))"); test "$live" = "$canon"
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
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

**Symptom:** `fw audit` prints two fabric coverage lines that disagree in the
same run — `[PASS] Fabric: 938 registered, 0 unregistered` directly above
`[WARN] Fabric drift: 1 source file(s) have no fabric card`. The PASS is the one
that reads as reassurance, and it is the wrong one.

A sharper instance surfaced while building the severity control: given a
**corrupt** `watch-patterns.yaml`, the drift check printed

    [PASS] Fabric drift: All watched source files registered ( cards)

The YAML parse raised, python exited non-zero, the shell's `-gt 0` test failed
on the traceback text, and the `else` arm reported full coverage. Coverage was
not merely miscounted — it was **entirely unmeasurable, and reported as
complete**. Measured by running the pre-fix code against a corrupt fixture, not
inferred from the branch. Note the empty `( cards)`: the one visible trace of
the failure was cosmetic, and sat inside a PASS.

**Root cause:** three implementations of one predicate. T-1842 centralised
pattern expansion into `expand_patterns.py` and migrated `register.sh` and
`drift.sh`, but the two copies inside `audit.sh` were never migrated. The
`:1405` copy globs without a `PROJECT_ROOT` join (CWD-dependent → structurally
zero from anywhere else), without `recursive=True` (blind to 33 of 45 files
under our one `**` pattern), and reports through two `pass()` arms so no value
of the metric can recruit attention. The `:1499` copy resolves correctly but
drops `exclude:`.

**Why structurally allowed:** the two checks agree on zero for *different*
reasons, and green agreeing with green reads as corroboration. Nothing compares
sibling checks that answer the same question, so a disagreement of 1 sat in
plain text in every audit for 14 days without being a failure of anything. The
severity defect compounds it: even a correct count could not have surfaced,
because both arms pass. T-1842's centralisation had no guard asserting that it
was *complete* — it fixed the two callers its author knew about, which is the
L-533 shape (a sweep that can only reach sites already in mind).

**Prevention:** the two audit checks now call `expand_patterns.py`, so there is
one definition rather than three. A differential test asserts all live answers
to the question are equal — a future divergence fails rather than prints. A
source-derived shape guard (no filename allowlist) fails if a private glob over
watch-patterns reappears anywhere in `audit.sh`, with a guard control proving it
catches a reintroduced instance. Severity is made a function of the count, and
that is proven by injecting an uncarded file and observing the verdict change,
not by reading the branch.

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

### 2026-08-02T11:45:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2735-fabric-coverage-audit-check-is-cwd-depen.md
- **Context:** Initial task creation
