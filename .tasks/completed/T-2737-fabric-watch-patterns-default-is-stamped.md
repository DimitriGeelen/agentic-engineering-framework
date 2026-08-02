---
id: T-2737
name: "Fabric watch-patterns default is stamped into every consumer and never checked
  against it"
description: >
  Fabric watch-patterns default is stamped into every consumer and never checked against
  it

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, tests/unit/fabric_coverage_single_source.bats, tests/unit/fabric_watch_pattern_fitness.bats]
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
created: 2026-08-02T13:09:28Z
last_update: 2026-08-02T13:46:39Z
date_finished: 2026-08-02T13:46:39Z
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
  - ts: '2026-08-02T13:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T13:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2737: Fabric watch-patterns default is stamped into every consumer and never checked against it

## Context

`fw context init` (T-367) stamps a default `.fabric/watch-patterns.yaml` into
every project. That file is the **denominator of every fabric coverage check**.
Nothing anywhere verifies it matches the project it was written into.

832 measured their vendored copy (rail-398, their defect B): the untailored
default expands to **zero files** — `web/`, `agents/`, `bin/`, `crates/` do not
exist there, `src/` holds one `.html` while the pattern wants `.py`, `lib/` is
empty. Their two coverage checks therefore compared an empty set against the
registry and reported complete coverage:

    [PASS] Fabric: 15 registered, 0 unregistered
    [PASS] Fabric drift: All watched source files registered (15 cards)

The `(15 cards)` reads as "15 files were checked". Zero were. Their real source
population is 115, of which 15 are carded — 13%, reported as 100%.

**Our exposure, measured, is different in shape and larger in absolute terms.**
Our watch file *is* tailored (this is the repo that authored it), so it expands
to 339 files, not zero. But:

| | |
|---|---|
| registered cards | 938 |
| files the watch file expands to | 339 |
| **cards pointing at files no pattern covers** | **600** |
| tracked `.py`/`.sh` outside `tests/` | 703, of which 447 unwatched |

So the registry has already decided 600 files are significant components, and
the drift check cannot see any of them. `agents/*/*.py` is not watched at all
(only `*.sh`), so every Python hook under `agents/context/` is invisible;
`web/*.py` is not watched (only `web/blueprints/`), so `web/ask.py`,
`web/config.py` are invisible — the same files T-2736 measured being discarded
as unresolvable edge targets.

**This is the tractable part.** "Which files *should* be watched" is a judgment
call and not mine to make. "The registry contains cards for files the watch file
cannot see" is a mechanical contradiction the project has already resolved in
one direction — no taste required. Same for the degenerate 832 case: patterns
expanding to zero while cards exist.

Ordering (832's argument, which holds here): this must land **after** T-2735,
because widening coverage while a second broken check printed `0 unregistered`
PASS beside it produces exactly the contradictory output that hid the class.
T-2735 is closed.

**Blast radius:** adds a WARN that will fire on consumers whose watch file has
drifted from their tree. That is the point — but it means consumers see new
audit output after upgrade. WARN-only, never blocking.

## Acceptance Criteria

### Agent
- [x] Audit emits a WARN when the registry contains cards for files that no
      watch pattern covers — the coverage denominator is then demonstrably
      incomplete, and the existing drift number is measuring a subset without
      saying so. Live: `WARN Fabric: 602 card(s) point at files no watch
      pattern covers`
- [x] Audit emits a WARN when the watch patterns expand to zero files while
      cards exist (the degenerate 832 case: coverage reported as complete
      because nothing was checked)
- [x] Both signals are derived — no allowlist of "expected" directories, no
      judgment about which files *should* be watched. The registry's own
      contents are the evidence (L-533). Guarded by a source-derived test
- [x] The existing drift line states the size of the set it measured
      (`all N watched file(s) registered`), so it can never again read as
      "all files registered". The old wording printed the *card* count, which
      is what made 832's `(15 cards)` look like coverage over 15 files
- [x] Neither signal can block: WARN only, consistent with the other fabric
      checks
- [x] An orphaned card (file deleted) is excluded — that is the orphan
      signal's subject. Without the `isfile` test both would fire on the same
      card with contradictory instructions
- [x] Negative control: neutering the carded-unwatched computation reddens
      tests 1/2/4/5/6; neutering the vacuity branch alone reddens test 3. Each
      for its stated reason. The fitting-project control proves the signals
      stay silent when the watch file and registry agree

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
# --- T-2737 ---
out=$(bats tests/unit/fabric_watch_pattern_fitness.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
# T-2735's suite must stay green — same file, adjacent checks
out=$(bats tests/unit/fabric_coverage_single_source.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
# the signal is live on this repo (it is what prompted the task)
out=$(bash agents/audit/audit.sh --sections structure 2>&1 || true); echo "$out" | grep -q "card(s) point at files no watch pattern covers"
# and neither new signal is a FAIL
out=$(bash agents/audit/audit.sh --sections structure 2>&1 || true); ! echo "$out" | grep -q "FAIL. Fabric: .* point at files"
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

**Symptom:** every fabric coverage verdict is computed over a set nobody
verified is the right set. On 832's tree the watch file expanded to zero files
and coverage read as complete (13% reported as 100%). Here it expands to 339
while 602 cards point at files outside it — so the drift number describes about
a third of what the registry itself treats as components, and says nothing
about the rest.

**Root cause:** `fw context init` (T-367) stamps a default watch file into every
project as a convenience, and nothing ever revisits it. The file is not
configuration the operator is prompted to complete — it arrives looking already
correct. Once stamped, the only thing that reads it is the coverage check whose
denominator it defines, so a wrong watch file produces no error anywhere: it
produces a *smaller true statement*, which is indistinguishable from a large one
in the output.

**Why structurally allowed:** the coverage checks and the watch file were
treated as instrument and input, never as a pair to be cross-examined. The
registry — the one artefact that records what this project actually considers a
component — was never compared against the file that decides what gets checked.
Both existed from T-367/T-368 onward. Nothing asked whether they agreed.

**Prevention:** two derived WARNs, both reading the registry as evidence rather
than asserting what should be watched. (1) cards pointing at files no pattern
covers — the project has already decided those are components. (2) patterns
expanding to zero while cards exist — the degenerate case where every verdict
above is vacuous. Plus the drift PASS now names the size of the set it measured,
so "all watched files registered" cannot be read as "all files registered". The
signals are WARN-only: which files *should* be watched remains a judgment call,
and the framework's job here is to surface the contradiction, not resolve it.

**Deliberately not done:** widening this repo's watch patterns to cover the 602.
That is the judgment call, it changes what every subsequent audit measures, and
the WARN now makes it visible and dateable. Operator's decision.

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

### 2026-08-02T13:09:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2737-fabric-watch-patterns-default-is-stamped.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-623e259d
- **Timestamp:** 2026-08-02T13:55:44Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 26
     - evidence: `out=$(bash agents/audit/audit.sh --sections structure 2>&1 || true); ! echo "$out" | grep -q "FAIL. Fabric: .* point at files"`

### 2026-08-02T13:46:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
