---
id: T-2518
name: "fabric drift SIGPIPE flake — echo|grep -qx membership FPs carded files"
description: >
  fabric drift SIGPIPE flake — echo|grep -qx membership FPs carded files

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
created: 2026-07-10T00:10:08Z
last_update: 2026-07-10T00:10:08Z
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

# T-2518: fabric drift SIGPIPE flake — echo|grep -qx membership FPs carded files

## Context

`bin/fw fabric drift` reported a different random subset of genuinely-registered
files as "unregistered" on each run (observed counts 0,1,2,3,4,5,7 across
consecutive invocations; every flagged file — `bin/fw`, `lib/mirror.sh`,
`lib/pause_cli.py`, … — had a valid card with a matching `location:`). Root-caused
to the SIGPIPE-under-pipefail trap (L-387/L-402 class) in the membership check at
`agents/fabric/lib/drift.sh:30`. This flake is what surfaced the audit's "N source
file(s) have no fabric card" WARN as a moving target. See `## RCA`.

## Acceptance Criteria

### Agent
- [x] drift.sh membership check uses a herestring + fixed-string match (`grep -qxF "$rel_path" <<<"$registered"`) — no `echo "$registered" | grep` producer that can take SIGPIPE
- [x] `bin/fw fabric drift` reports `unregistered: 0` on 15 consecutive real runs (was nondeterministic 0–7 before the fix)

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
bash -n agents/fabric/lib/drift.sh
grep -qF 'grep -qxF "$rel_path" <<<"$registered"' agents/fabric/lib/drift.sh
out=$(grep -n 'echo "$registered" | grep -qx' agents/fabric/lib/drift.sh || true); [ -z "$out" ]
fail=0; for i in $(seq 1 15); do out=$(bin/fw fabric drift 2>&1); echo "$out" | grep -qE "unregistered: 0," || fail=1; done; [ "$fail" -eq 0 ]

## RCA

**Symptom:** `bin/fw fabric drift` reported "unregistered" files nondeterministically —
a different random subset of *carded* files each run (counts 0,1,2,3,4,5,7 observed).
The audit's fabric-scan WARN ("N source file(s) have no fabric card") inherited this
and moved around, so it could never be cleanly remediated.

**Root cause:** `drift.sh:30` used `if ! echo "$registered" | grep -qx "$rel_path"`.
`registered` is an ~877-line string; `grep -q` short-circuits (exits 0) the instant
it finds a match and closes the pipe. `echo` — still writing the long string — then
receives SIGPIPE (exit 141). Under the inherited `set -euo pipefail` the pipeline's
exit status becomes 141 (non-zero), so `! 141` evaluates true and the file is flagged
as unregistered *even though it matched*. Whether `echo` has finished before `grep`
short-circuits is timing-dependent, and files whose `location:` sorts early in
`$registered` are matched sooner → more likely to trigger the race → different random
subset each run.

**Why structurally allowed:** the L-387 SIGPIPE class was known and documented (captured
5+ times: T-1716/T-1838/T-1862/T-1863/T-1900→L-402) but only as *advisory hints in the
task template's Verification block*. No lint/scan caught the same `cmd | grep -q` shape
in shipped framework code (`drift.sh` predates the hints). Because the failure mode is a
false *positive* (over-reporting), not a crash, drift kept "working" and the noise was
written off as OBS-092 flake rather than a determinate bug.

**Prevention:** the fix itself (herestring, no producer process → SIGPIPE impossible;
`-F` fixed-string so path dots aren't regex) plus AC2's 15-run stability gate that would
regress-catch a reintroduced pipe. Broader class-catch (a reviewer detector for
`echo "$X" | grep -q` inside `set -o pipefail` scopes) is a candidate follow-up, filed
separately if pursued — this task fixes the one live instance.

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

### 2026-07-10T00:10:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2518-fabric-drift-sigpipe-flake--echogrep--qx.md
- **Context:** Initial task creation
