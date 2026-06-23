---
id: T-2471
name: "Implement fw integrate run — smooth worktree merge-back (T-2397 spec + live-gap extensions)"
description: >
  Implement fw integrate run — smooth worktree merge-back (T-2397 spec + live-gap extensions)

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
created: 2026-06-23T20:15:20Z
last_update: 2026-06-23T20:15:20Z
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

# T-2471: Implement fw integrate run — smooth worktree merge-back (T-2397 spec + live-gap extensions)

## Context

The mutating merge-back verb `fw integrate run` is fully designed in the T-2397 spec
(`docs/reports/T-2397-layer2-integration-queue-spec.md` §3 — a 9-step algorithm) but was
never built; only the read-only half shipped (`fw integrate check|classify`, T-2399). This
task builds the MVP of `fw integrate run`, extended for the gaps that bit a live session
(2026-06-23, T-2465 deploy): the target checkout being full of uncommitted generated churn
(git refuses to merge), and the focus/active-task gate blocking the integration's own commits.

Scope = the common case the spec calls FF-ready / auto-resolvable: lock → preflight (reuse
`fw integrate check`) → quiesce regenerable churn → merge → vendor-refresh → verify → release,
with a focus-gate exemption. **Deferred to a follow-up slice:** full per-class resolution of
BOTH-SIDED un-partitionable conflicts (applying append-union/id-union/field-merge at actual
git conflicts) — the technically hardest part of T-2397 §3.2; this MVP handles the
quiesce-and-clean-merge path and refuses (clean abort) when real both-sided conflicts remain.

## Acceptance Criteria

### Agent
- [x] `fw integrate run [target] [--dry-run] [--push]` exists (default target master); composes `fw integrate check` as preflight and refuses cleanly (clear message, nonzero) on needs-human (exit 2) or not-on-a-branch (exit 3) — never blind-merges
- [x] Acquires a single-writer lock (git-common-dir lockfile, stale TTL per T-2397 §3.3) and always releases it on exit (trap), so concurrent integrations serialize
- [x] Quiesces regenerable working-tree churn in the target before merge (stash) so a clean merge is not blocked by uncommitted generated/governance files (the live blocker), and restores it after — using `lib/integrate.py` classify_path to decide what is regenerable
- [x] Refreshes vendored `.agentic-framework/` (`fw vendor self`) after the merge (T-2397 §3.1 step 6)
- [x] The run's own git operations are NOT blocked by the focus/active-task gate — exemption is **verb-scoped in `agents/context/lib/safe-commands.sh`** (`fw integrate` allow-listed), NOT an `FW_INTEGRATION_IN_PROGRESS` env honor. Build-time revision (see Evolution): an env-var the gate honors would reintroduce the T-2446 inherited-env poison class this arc exists to eliminate; the env approach is also "too late" (the gate fires on the agent's top-level call before bin/fw sets the env). The verb-scoped allow-list is poison-safe and is the EFFECTIVE exemption. `FW_INTEGRATION_IN_PROGRESS=1` remains as a marker for the python subprocess's own internal git calls only.
- [x] `--dry-run` prints the planned steps and the `fw integrate check` verdict without mutating anything; without `--push` the verb never pushes
- [x] `tests/unit/t2471_integrate_run.bats` passes — synthetic fixture: a divergent branch + dirty regenerable churn in the target → `fw integrate run` yields target with branch merged, churn restored, vendored refreshed, exit 0; and a both-sided code conflict → clean refuse (nonzero, target untouched)

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
python3 -m py_compile lib/integrate.py
bash -n bin/fw
bash -n agents/context/lib/safe-commands.sh
bats tests/unit/t2471_integrate_run.bats
bats tests/unit/t2399_integrate_check.bats
out=$(bash -c "source agents/context/lib/safe-commands.sh && is_bash_safe_command 'fw integrate run master' && echo SAFE"); echo "$out" | grep -q SAFE

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

### 2026-06-23 — AC5 mechanism changed: verb-scoped allow-list, not env honor

- **What changed:** The filed AC5 said the focus-gate exemption would be an
  `FW_INTEGRATION_IN_PROGRESS=1` env var honored in `check-active-task.sh`. Building
  it surfaced two problems: (1) **poison class** — a gate that exits 0 on a leaked
  env var is exactly the T-2446 daemon-inherited-env vulnerability this whole arc
  (T-2464) exists to eliminate; (2) **too late** — the gate fires on the agent's
  top-level `fw integrate run` Bash call, *before* bin/fw runs and sets the env, so
  the env honor can't even reach the call it's meant to exempt.
- **Plan impact:** Implemented the exemption as a verb-scoped entry in
  `lib/safe-commands.sh` (`fw integrate` → safe), the same category as the existing
  `git push/add/commit` task-agnostic exemptions (T-2054/T-2462). Poison-safe (scoped
  to a specific command verb, not an ambient flag) and it actually intercepts the
  top-level call. `FW_INTEGRATION_IN_PROGRESS=1` is retained only as a marker for the
  python subprocess's own internal git calls. bin/fw comments corrected to match.
- **Triggered:** AC5 reworded; no new task.

### 2026-06-23 — production bug found + fixed in _dirty_files() (porcelain slice)

- **What changed:** While writing the AC7 fixture, the regenerable-churn test refused
  instead of merging. Root cause: `_dirty_files()` parsed `git status --porcelain`
  via `_git()`, whose `r.stdout.strip()` removes the **leading space** of the first
  porcelain `XY ` status column (` M path` → `M path`). The fixed `line[3:]` slice
  then dropped the path's first character — `.context/working/.hook-counter` became
  `context/working/.hook-counter`, which misses the regenerable-classify rule and
  mis-classifies as real code. This would have made `fw integrate run` refuse on the
  most common churn case in real use (an unstaged-only modified counter/governance file).
- **Plan impact:** `_dirty_files()` now parses raw, unstripped subprocess output
  (per-line `line[3:]`), plus handles `R old -> new` rename lines. Caught only because
  the AC7 fixture exercised the real mutating path, not just preflight.
- **Triggered:** fix in same task; no follow-up needed.

### 2026-06-23 — taxonomy completeness is the next usefulness gap (follow-up)

- **What changed:** Live `fw integrate run --dry-run` on this very repo refuses because
  many real-world transient/governance files (`.context/working/focus.yaml`,
  `session.yaml`, `.session-metrics.yaml`, `watchtower.{log,pid}`, `.gate-bypass-log.yaml`,
  `.context/project/decisions.yaml`, `VERSION`) are NOT in the T-2397 §3.2 taxonomy, so
  classify_path defaults them to real-code/needs-human. The MVP is correct and SAFE
  (refuse rather than risk stashing real work) but refuses more than ideal on a busy tree.
- **Plan impact:** None for this MVP — the ACs are met and the core mechanism is proven.
  Broadening the shared `classify_path` taxonomy touches T-2399's pinned behavior and each
  new class needs a correct strategy, so it is genuinely separate work.
- **Triggered:** follow-up (un-filed; deferred alongside the true append/id/field UNION at
  both-sided conflicts noted in Context). File when merge-back is exercised for real.

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

### 2026-06-23T20:15:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2471-implement-fw-integrate-run--smooth-workt.md
- **Context:** Initial task creation
