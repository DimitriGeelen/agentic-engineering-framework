---
id: T-2736
name: "Fabric enrich discards unresolvable and ignorable edges through one silent branch"
description: >
  Fabric enrich silently discards unresolvable edges, so its own mitigation cannot move the metric

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
created: 2026-08-02T13:00:05Z
last_update: 2026-08-02T13:00:05Z
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

# T-2736: Fabric enrich silently discards unresolvable edges, so its own mitigation cannot move the metric

## Context

> **Scope correction against the reporting rail.** 832 reported this as "the
> mitigation cannot move the metric" — on their tree `fw fabric enrich` returns
> `Cards enriched: 0`. **That symptom does not reproduce here.** Measured:
> `fw fabric enrich --dry-run` reports 57 cards enriched, 153 edges added. Our
> `[WARN] Fabric: 28/851 cards have no edges` persists because nobody has run
> the remedy, not because the remedy is inert.
>
> What *does* reproduce is the underlying silent discard. Their headline is
> occupancy-dependent; the defect beneath it is not. This task fixes the
> defect and does not inherit the headline — the title was written from their
> framing before the local measurement was taken.

`fw audit` emits `[WARN] Fabric: 28/851 cards have no edges` with
`Mitigation: Run: fw fabric enrich`. 832 followed exactly that instruction on
their vendored copy and got `Cards enriched: 0. Forward edges: 0.` — a
prescribed remedy that cannot move the metric it is prescribed for, across all
13 audits that recommended it (rail-398, their defect A).

The mechanism is in `agents/fabric/lib/enrich.py:662`:

```python
target_id = loc_to_id.get(loc)
if not target_id:
    continue
```

No counter, no verbose line, no effect on the summary. Enrichment can therefore
only ever draw edges *inside* the already-registered set, and reports a clean
zero whether it found nothing or dropped everything.

Measured here by wrapping the real `resolve_edges` (not reimplementing the
dispatch): **2419 raw edges detected, 2124 kept, 295 discarded** across 117
distinct targets, **all 117 of which exist on disk**.

The split matters, and is where this diverges from 832's reading:

| discarded target | distinct | edge instances |
|---|---|---|
| real files with no card | 72 | 147 |
| directories | 45 | 148 |
| non-existent | 0 | 0 |

So `if not target_id: continue` is doing **two different jobs at once** —
suppressing detector noise (a dependency resolved to `lib/`, `tools/`,
`.tasks/`, which are not components and never will be) and swallowing genuine
missing-card edges (`web/ask.py`, `web/config.py`, `agents/context/check-arc-id.py`).
Because the drop is mute, the two are indistinguishable from outside, and the
operator sees the same clean zero either way.

That is the actual defect. Not "it discards real files" — it discards two
categories through one silent branch, so no reader can tell a healthy run from
a lossy one.

Depends on T-2735 (their defect C) landing first, which it has.

## Acceptance Criteria

### Agent
- [x] `resolve_edges` distinguishes *unresolvable* targets from *ignorable* ones
      rather than dropping both through one mute branch — `classify_unresolved`
      returns `ignorable` / `actionable` / `absent`
- [x] Discards are counted and surfaced in the enrich summary, so a run that
      drops 295 edges cannot report identically to one that drops none. Live:
      `Actionable: 149 (74 real file(s) with no card)`, `Ignorable: 148`
- [x] The distinction is derived from the target, not from an allowlist of
      known-noisy paths (L-533): a directory is ignorable because it is a
      directory, not because someone listed it. Guarded by a source-derived
      test that fails on allowlist smells inside `classify_unresolved`
- [x] A file target that exists but has no card is reported as *actionable*
      (it is what `fw fabric register` exists for), separately from ignorables
- [x] The measurement is reproducible from the shipped code — the tests call
      `enrich.resolve_edges` / `enrich.classify_unresolved` directly rather
      than re-typing their logic, so they cannot drift from the producer
- [x] Negative control: reverting the counting reddens exactly the two
      breakdown tests (`assert 0 == 5`); reverting the classifier to an
      allowlist reddens exactly the allowlist guard. Each for its stated reason
- [x] The `Actionable:` line prints even at zero, so a clean run and a broken
      counter are distinguishable (L-525)

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
# --- T-2736 ---
out=$(python3 -m pytest tests/unit/test_enrich_unresolved_targets.py -q 2>&1); echo "$out" | grep -q "9 passed"
# the summary reports the breakdown on a real run
out=$(timeout 900 bin/fw fabric enrich --dry-run 2>&1); echo "$out" | grep -q "Unresolved edge targets"
out=$(timeout 900 bin/fw fabric enrich --dry-run 2>&1); echo "$out" | grep -q "^Actionable:"
# the pre-existing enrich suites still pass (backward-compatible signature)
out=$(python3 -m pytest tests/unit/test_enrich_python_path_refs.py tests/unit/test_enrich_bats_parser.py -q 2>&1); echo "$out" | grep -qE "[0-9]+ passed" && ! echo "$out" | grep -q "failed"
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

**Symptom:** `fw fabric enrich` reports a clean summary regardless of how much
it threw away. Measured here: 295 of 2419 detected edges (12.2%) discarded, and
nothing in the output said so. On 832's tree the same silence hid a total
failure — `Cards enriched: 0` across all 13 audits that prescribed the command.

**Root cause:** `resolve_edges` used `dict.get` returning `None` to mean "not a
dependency", when it actually means "not present in the card registry". Those
are different claims. The branch then served two unrelated purposes through one
mute `continue`: suppressing real detector noise (148 edge instances pointing at
directories, correctly dropped) and swallowing genuine coverage loss (147
instances pointing at real uncarded files). Absence carrying a decision it
cannot carry.

**Why structurally allowed:** the discard had no counter, so it could not appear
in any summary, any `--verbose` output, or any metric. A defect that produces no
observable difference cannot be noticed by inspection of output — only by
reading the source or instrumenting it. The audit's own mitigation line
(`Run: fw fabric enrich`) pointed operators straight at the command whose
failure mode was invisible, and nothing compared what enrichment *detected*
against what it *kept*.

**Prevention:** the breakdown is now part of the summary, printed on every run,
including at zero — so a clean run and a broken counter are distinguishable
(L-525). The classification is derived from the filesystem rather than an
allowlist, guarded by a source-derived test that fails on allowlist smells
inside the function body, so the next unseen noisy shape cannot be misfiled in
silence (L-533). The tests call the shipped functions directly rather than
re-typing their logic, so they cannot drift from the producer.

**Scope note:** the headline 832 reported ("the mitigation cannot move the
metric") does **not** reproduce here — our enrich adds 153 edges. Their symptom
is occupancy-dependent; the silent discard beneath it is not. Fixed the defect,
did not inherit the headline.

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

### 2026-08-02T13:00:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2736-fabric-enrich-silently-discards-unresolv.md
- **Context:** Initial task creation
