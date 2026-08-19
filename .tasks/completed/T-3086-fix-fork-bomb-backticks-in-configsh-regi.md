---
id: T-3086
name: "Fix fork bomb: backticks in config.sh registry string"
description: >
  Fix fork bomb: backticks in config.sh registry string

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/check-tier0.sh, bin/fw, lib/config.sh]
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
created: 2026-08-19T19:27:47Z
last_update: 2026-08-19T19:38:10Z
date_finished: 2026-08-19T19:38:10Z
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
  - ts: '2026-08-19T19:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=158,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-19T19:30:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3086: Fix fork bomb: backticks in config.sh registry string

## Context

`lib/config.sh:247` wrapped `fw tier0 approve` in Markdown-style backticks inside a
**double-quoted** element of the `FW_CONFIG_REGISTRY` array. Bash treats backticks in
double quotes as command substitution, so merely *sourcing* config.sh executed
`fw tier0 approve` — which sources config.sh again. Self-replicating fork bomb,
~150 procs/sec, unbounded.

Only the source copy was infected — vendored `.agentic-framework/` copies were not yet
synced, which is why cron had not yet become 23 concurrent fork bombs.

**Provenance, measured 2026-08-19 21:35 — supersedes any earlier "introduced by
dce7d3074" note.** The poisoned line was **never committed**. `git show
dce7d3074:lib/config.sh` contains no `TIER0_APPROVAL_TTL` entry at all; `git show
HEAD:lib/config.sh` has zero backticks on any non-comment line; the last commit to touch
`lib/config.sh` is 471f054ab (T-3028), long before. `git diff --stat lib/config.sh`
reports 9 insertions and 0 deletions, which is only possible if HEAD never carried the
line. The bomb lived solely in the **uncommitted working tree**, written by the T-3080
TermLink worker before it died.

That moves the blast radius in the safe direction: `origin` was never poisoned, the GitHub
mirror was never poisoned, and no consumer could have inherited it by vendoring. It also
re-explains the paragraph above — the vendored copies were clean not because we won a race,
but because the commit that would have carried it never happened.

Host state after the fix (21:31): 9.4 GB used of 64 GB, 662 procs, 4 `fw` procs, load 6.01
with ollama and chromium accounting for the top of the RSS table. Uptime 1:10, consistent
with the 20:20 OOM being the last one.

## Acceptance Criteria

### Agent
- [x] Backticks removed from `lib/config.sh` registry entry (replaced with single quotes)
- [x] No backticks remain on any non-comment line of `lib/config.sh` — each one is a
      command substitution that fires on every source, and `bin/fw` sources this file on
      every single invocation, including every cron job and every PreToolUse hook
- [x] `bash -n lib/config.sh` passes
- [x] Sourcing `lib/config.sh` inside a bounded cgroup (TasksMax=30) spawns no `fw`
      processes — the fork-bomb regression, asserted against the real file
- [x] `fw work-on` / `fw audit` run without process explosion

## Verification

# Syntax must be valid
bash -n lib/config.sh

# No backticks on non-comment lines of config.sh (each would be a command substitution)
test "$(grep -n '`' lib/config.sh | grep -vE '^[0-9]+:[[:space:]]*#' | wc -l)" -eq 0

# Fork-bomb regression: sourcing config.sh in a bounded cgroup must not spawn fw procs
systemd-run --scope --quiet -p TasksMax=30 -p MemoryMax=256M timeout 10 bash -c 'source lib/config.sh' >/dev/null 2>&1; test "$(pgrep -x fw 2>/dev/null | wc -l)" -lt 3

## RCA

**Symptom:** the host hard-crashed via kernel OOM four times in 22 hours (22:14, 01:00,
08:29, 20:20). The final OOM dump showed 2,135 live `fw tier0 approve` processes holding
10.52 GB — 96% of all RSS — across 10,412 distinct `fw` PIDs. From the operator's seat this
read as "huge numbers of cron sessions being spawned", because cron is what runs `fw`
unattended around the clock; cron was the victim surface, not the cause.

**Root cause:** a doc-comment reflex crossing a shell-quoting boundary. `FW_CONFIG_REGISTRY`
elements are **double-quoted** bash strings whose third field is human-readable prose. Prose
invites Markdown. Inside double quotes, backticks are command substitution, not typography —
so writing the command name in backticks inside a description made *sourcing the file*
execute it. `bin/fw` sources `lib/config.sh` on every invocation, and `fw tier0 approve` is
a `bin/fw` invocation, so each source spawned a child that sourced again. Self-replicating,
~150 procs/sec, unbounded. Nothing in the entry looked like code.

**Why structurally allowed:** three gaps compose.

1. **No lint on the registry's own quoting.** `tests/lint/config-registry-parity.bats`
   checks that documented keys exist and vice versa — a *naming* invariant. Nothing checks
   that a description is inert. `bash -n` passes happily: command substitution is valid
   syntax, which is exactly the problem.
2. **The dangerous and the safe usage sit two lines apart and look identical.** The
   comment lines above each entry are full of backticked command names and are completely
   safe. An author following the local convention by eye cannot see the boundary, because
   the boundary is the quoting context, not anything visible on the line.
3. **A dispatched worker's uncommitted edits are live immediately.** The T-3080 worker
   wrote the line and died before committing, so no commit-time gate was ever reachable —
   PreToolUse fires on the worker's own Write, and there was no subsequent commit to catch.
   The file was load-bearing for every `fw` call in the system the instant it hit disk.
   Same class as T-3077 (a test that writes live state) but at the config layer: **the
   working tree is production for anything `bin/fw` sources.**

**Prevention** (distinct from the fix, which is one line):

- A lint asserting every `FW_CONFIG_REGISTRY` element is free of backticks, `$(`, and `${`
  on the value side — that no registry entry can execute anything when sourced. This is the
  missing rail, and it generalises past this key and this file. **Not yet written** — filed
  as follow-up, and until it lands this class is open.
- AC 4 in this task pins the behavioural half (bounded cgroup, source, assert no spawn), so
  a regression is caught by consequence and not only by pattern.
- Learning to file: *a doc-comment reflex is a code-injection vector wherever prose lives
  inside a double-quoted shell literal.*

**Not prevention, said plainly:** the four OOMs were bounded by the host's memory ceiling,
not by anything the framework did. There is no framework-side circuit breaker on runaway
self-invocation, and this task does not add one. If a future entry re-opens this class
before the lint lands, the outcome is another OOM.


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

### 2026-08-19T19:27:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3086-fix-fork-bomb-backticks-in-configsh-regi.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-341098db
- **Timestamp:** 2026-08-19T19:38:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-19T19:38:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
