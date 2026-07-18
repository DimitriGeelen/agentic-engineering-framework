---
id: T-2448
name: "F8 build — thin re-exec shim routes bare fw to consumer-local + doctor skew-WARN
  (T-2447 GO: C+E+B)"
description: >
  F8 build — thin re-exec shim routes bare fw to consumer-local + doctor skew-WARN
  (T-2447 GO: C+E+B)

status: captured
workflow_type: build
owner: agent
horizon: next
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
created: 2026-06-21T11:19:48Z
last_update: '2026-07-08T08:15:04Z'
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
  - ts: '2026-07-07T08:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-07T08:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      F3=1 (body/components:prompt-incidental); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-08T08:15:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2448: F8 build — thin re-exec shim routes bare fw to consumer-local + doctor skew-WARN (T-2447 GO: C+E+B)

## Context

Implements the **T-2447 GO decision** (Candidate C+E, fold B; reject A/D). Origin: T-2441 dogfood F8 —
on a host with a global install, `command -v fw` → `~/.local/bin/fw`, a **symlink to the GLOBAL**
`bin/fw`, so bare `fw` from a consumer runs the global framework's stale resolution logic (proven:
global lacks the T-2446 fix). Full analysis + 5-candidate matrix: `docs/reports/T-2447-f8-shim-routing.md`.

**Dominant constraint (do not skip):** T-2099 was a **fork bomb (SEV-1)** in exactly the re-exec +
T-498 re-resolution path. The re-exec MUST carry a `T-2099`-style env-sentinel guard (see bin/fw:598-606).
Candidate A (re-exec on bin/fw's hot path) was rejected for this reason — the fix lives in a **thin,
isolated shim**, NOT bin/fw's resolver.

**Consumer-facing setup-command change (T-1633):** touches the shim that `fw init`/`fw upgrade` install;
`tests/unit/upgrade_fresh_machine_simulation.bats` MUST stay green and gain coverage for all 4 invocation
modes (framework-repo-self, direct-vendored, global-from-consumer, global-from-non-project).

**SCOPE REFRAME (T-2450 session discovery — read before building):** Candidate C is **largely already
built.** `bin/fw-shim` (T-664) already walks CWD→project-local and exec's it — resolution order
`bin/fw`+`FRAMEWORK.md` (framework repo) → `.agentic-framework/bin/fw` (consumer) — with a T-1278
`realpath` self-loop guard. `install.sh link_fw()` (install.sh:233-257) installs fw-shim **when
`$INSTALL_DIR/bin/fw-shim` is executable**, and only **falls back** to the legacy global symlink (the F2
"legacy — upgrade for project-local routing" message, install.sh:246) when it is not. The dogfood F8
symptom (bare `fw` → global symlink) was the **fallback path firing** — i.e. the stale v1.6.25 GitHub
clone (F1) lacked a working fw-shim — NOT an absent mechanism. So this build's real scope is:
1. **Ensure fw-shim always ships + is chosen** (diagnose why the fallback fired; the fix may be mostly
   F1 — stale public install — plus making `link_fw` prefer fw-shim more robustly).
2. **Harden fw-shim's recursion guard** — it has a `realpath` self-loop guard but NOT the T-2099
   env-sentinel (`FW_REEXEC_GUARD=1`); add the env-sentinel for defence-in-depth on the exec.
3. **Candidate E** (`fw doctor` skew-WARN) and **Candidate B** (install-prompt path text) unchanged.
4. F2 (soften/forward-action the legacy message) is the **same fallback path** — fold or sibling.
F1/F2/F8 are entangled through `link_fw`'s fw-shim-vs-fallback branch; scope them together here or split
F1 out as the "stale public install" leg. Re-read `bin/fw-shim` + `install.sh:232-260` first.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] AC1 (Candidate C) — `fw init`/`fw upgrade` install the PATH shim as a **thin re-exec wrapper**
      (not a symlink to the global `bin/fw`): if cwd-ancestry has `.agentic-framework/bin/fw` AND no
      sentinel set → `exec` it with `FW_REEXEC_GUARD=1`; else fall through to the global `bin/fw`.
- [ ] AC2 (recursion guard) — the wrapper carries a `T-2099`-style env-sentinel so a project-local fw
      that itself re-resolves cannot recurse. A regression test drives the guard (no fork bomb).
- [ ] AC3 (Candidate E) — `fw doctor` emits a WARN when the bare-`fw`-resolved shim's version differs
      from the cwd consumer's vendored version, with an actionable message (use project-local path / run
      `fw upgrade`). Zero change to bin/fw's resolution hot path.
- [ ] AC4 (Candidate B) — the T-2441 install prompt + onboarding text use `.agentic-framework/bin/fw`
      for consumer steps (no bare `fw` for consumers), per §Copy-Pasteable Commands / T-1257.
- [ ] AC5 (4-mode + simulation) — `tests/unit/upgrade_fresh_machine_simulation.bats` stays green AND
      gains assertions for all four invocation modes (framework-repo-self, direct-vendored,
      global-from-consumer, global-from-non-project). Live-fired via a TermLink shell (OBS-080 bypass).
- [ ] AC6 (env contract intact) — explicit `PROJECT_ROOT` still wins (T-2391/T-2446); the existing
      resolver bats (t2390/t2391/t2446) + `test_project_root_discovery.py` stay green.

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

### 2026-06-21T11:19:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2448-f8-build--thin-re-exec-shim-routes-bare-.md
- **Context:** Initial task creation

### 2026-06-21T11:20:55Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → next
