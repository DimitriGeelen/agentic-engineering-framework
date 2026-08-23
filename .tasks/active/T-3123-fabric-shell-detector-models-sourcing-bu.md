---
id: T-3123
name: "fabric shell detector models sourcing but not invocation - a script that RUNS
  another script produces no edge"
description: >
  832-Workflow-designer measured 65 project .sh files with ZERO source/. statements:
  their shell composes by invocation, one script running another as a subprocess.
  20 of 65 invoke 110 distinct tracked targets; tests/run-bridge-tests.sh alone invokes
  93 and its card has zero edges. detect_bash_sources models only the relationship
  where one script's TEXT becomes part of another's. T-3122 widened the variable vocabulary,
  which moves their number from 0 to 0. Third sighting of the class: the detector
  was calibrated against the one tree its author could see.

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
created: 2026-08-23T20:11:51Z
last_update: 2026-08-23T20:48:50Z
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
  - ts: '2026-08-23T20:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-23T20:15:13Z'
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

# T-3123: fabric shell detector models sourcing but not invocation - a script that RUNS another script produces no edge

## Context

`detect_bash_sources` in `agents/fabric/lib/enrich.py` models exactly one shell
relationship: script A's *text* becomes part of script B (`source`, `.`). Shell
also composes by **invocation** — A runs B as a subprocess — and that edge is
not modelled at all, so a script whose only dependency is what it executes gets
a card with zero edges.

This is the third sighting of one class. T-3121: Python import prefixes
hardcoded to `web|lib|agents|tools`. T-3122: shell source targets hardcoded to
four `$VAR` names. Both were calibrated to the one tree their author could see.
T-3122 widened the *vocabulary* of sourcing, which is why it moved
832-Workflow-designer's number from 0 to 0 — their tree does not source at all.
Widening a vocabulary cannot reach a relationship the detector does not model.

Evidence is currently entirely 832's (20/65 files, 110 distinct targets,
`tests/run-bridge-tests.sh` at 93 invocations with a zero-edge card). AC1 exists
because that evidence must be reproduced locally before the fix is trusted — if
our own tree composes by sourcing, the change ships blind and the measured
delta is the only thing that can say so.

## Acceptance Criteria

### Agent
- [x] Local baseline is measured and reported before any code change: how many
      tracked `.sh` files contain no `source`/`.` statement, how many reference
      another tracked `.sh`, and the distinct-target count. Reported even when it
      is small — a near-zero local number is a valid result that qualifies the
      fix, not a reason to suppress it.
- [x] `enrich.py` grows invocation detection for shell: a tracked script
      referenced as a command by another tracked script produces a dependency
      edge, alongside the existing source/. edges.
- [x] Detection is not keyed to any project-specific directory name, variable
      name, or top-level package list. A fixture using vocabulary this repo does
      not use must still resolve.
- [x] Self-edges are excluded and duplicate edges are collapsed, matching the
      guarantees T-3122 added to the sourcing path.
- [x] New tests live in `tests/unit/` with their own fixture tree (L-599: not
      pinned to the live corpus), and are mutation-checked — the report states
      how many of them fail against the pre-change code. A test that passes both
      before and after guards nothing and does not count.
- [x] Before/after edge counts are reported as both raw and deduplicated totals.
      T-3122's raw count read as a 54% regression until dedup inverted it; a
      single number is not reportable here.
- [x] `bin/fw fabric drift` and the fabric section of `bin/fw audit` still run
      clean after the change.

## Baseline (AC1, measured 2026-08-23, pre-change)

Measured over tracked `.sh` files, excluding the vendored `.agentic-framework/`
copy so the same file is not counted twice.

| Population | Count |
|---|---|
| tracked `.sh` files | 246 |
| no `source`/`.` statement anywhere | 89 |
| reference another tracked `.sh` | 165 (158 distinct targets) |
| **both — no source AND invokes** | **37** |

The 37 are the population this task targets: their composition is entirely
invocation, so `detect_bash_sources` produces a zero-edge card for every one of
them. 832's finding reproduces locally rather than being specific to their tree,
which is what AC1 existed to settle. Largest invokers here are
`agents/audit/audit.sh` (38 referenced scripts), `agents/audit/self-audit.sh`
(23), `agents/task-create/update-task.sh` (19) and `agents/handover/handover.sh`
(18) — all framework-core, all currently under-connected in the fabric.

### Correction to AC1 (issued by the worker, accepted)

The "37" above is wrong and is left in place rather than quietly edited, because
the way it was wrong is the point. It came from a basename substring match, which
counts a script *named* anywhere in a file — including in prose. Checked properly,
those files reference other scripts only in comments and help text:
`agents/git/lib/status.sh` prints `Create a task first: ./agents/task-create/create-task.sh`
inside an `echo`; `lib/colors.sh` names `lib/errors.sh` in a header comment;
`agents/context/session-end.sh` names `session-silent-scanner.sh` in a comment.
Of the 32 that still have zero edges after the change, only 7 contain a
command-position invocation at all, and none of those resolves to a tracked file.

So they *should* stay edgeless — emitting edges for them would be false positives.
A cross-check with a deliberately different recogniser found 0 undetected genuine
invocation sites across all 246 files. I built the baseline with the same
shape of shortcut the bug itself is made of: a pattern that looks like it measures
the relationship and actually measures a spelling.

## Result (measured, post-change)

| | raw sites | dedup unique (src,tgt) | files with edges |
|---|---|---|---|
| before (HEAD) | 760 | 289 | 98 |
| after | 839 | 302 | 106 |
| delta | +79 (+10.4%) | **+13 (+4.5%)** | +8 |

13 new pairs, 0 lost. Raw and dedup agree in direction and disagree in magnitude:
most new invocation *sites* point at a target the file already reached by sourcing,
so they collapse into an existing edge. Raw counts sites, dedup counts
relationships — dedup is the honest headline.

**+4.5% understates it, and the reason matters.** This tree's dominant idiom is
already covered by the legacy hardcoded `$FRAMEWORK_ROOT` / `$PROJECT_ROOT` /
`$AGENTS_DIR` patterns, so a measurement taken *here* flatters the old code. The
worker probed that by rewriting every blessed variable name to a neutral one (no
files moved, so every real edge still exists):

| | edges | files |
|---|---|---|
| old code, real names | 289 | 98 |
| new code, real names | 302 | 106 |
| old code, renamed vars | 186 (−36%) | 84 |
| new code, renamed vars | 231 (−24%) | 101 |

The old detector loses over a third of its edges when the vocabulary changes.
The new one loses a quarter, and carries +24% more than the old under rename.
That gap is the decalibration, and it is invisible to any measurement taken on
the one tree the detector was written against.

Enricher against the live corpus: 2 cards / 1 forward edge before, 31 cards /
26 forward edges after.

**Mutation check: 19 of 32 new tests fail against pre-change `enrich.py`**
(verified independently by stashing the change). 48/48 pass after — 32 new plus
the 16 T-3122 sourcing tests, zero regressions. The one red test in
`fabric_coverage_single_source.bats` (line 241) fails identically pre-change and
is not caused by this task.

Implementation carries no project vocabulary: command position is recognised by
shell grammar, interpreters by name (`sh`/`bash`/`zsh`/`ksh`/`dash`/`ash`), and
the bare-command form is guarded by the shell's own rule — the execute bit.
Quoted-string interiors, trailing comments and heredoc bodies are blanked
offset-for-offset before matching, so a `# bash tools/x.sh` example in a comment
does not become an edge. Targets resolve through the existing T-3122
`_trailing_literal_path` + resolver, sharing its `add()` closure, so self-edges
are excluded and duplicates collapse.

## Verification

python3 -m pytest tests/unit/test_fabric_shell_invocations.py -q > /tmp/.t3123a.out 2>&1 && grep -q "32 passed" /tmp/.t3123a.out
python3 -m pytest tests/unit/test_fabric_shell_sources.py tests/unit/test_fabric_dotted_imports.py -q > /tmp/.t3123b.out 2>&1 && grep -q "27 passed" /tmp/.t3123b.out
python3 -c "import ast,sys; ast.parse(open('agents/fabric/lib/enrich.py').read())"
bin/fw fabric drift > /tmp/.t3123c.out 2>&1; grep -qv "ERROR" /tmp/.t3123c.out
diff -q agents/fabric/lib/enrich.py .agentic-framework/agents/fabric/lib/enrich.py
