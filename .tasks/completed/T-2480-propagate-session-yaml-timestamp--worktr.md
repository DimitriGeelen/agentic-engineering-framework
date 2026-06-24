---
id: T-2480
name: "propagate session YAML-timestamp + worktree fixes to consumers (vendor refresh + land handoff)"
description: >
  Refresh this repo's vendored .agentic-framework/ copies of the session's framework edits (integrate.py union resolver, bvp.sh + estimator.py YAML-timestamp fallback) so the branch can push and consumers inherit correct copies on fw upgrade. Identify which hosts/consumers are actually affected and give concrete per-host upgrade actions. Do NOT remote-upgrade machines from this session.

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-06-24T11:12:03Z
last_update: 2026-06-24T11:26:35Z
date_finished: 2026-06-24T11:26:35Z
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

# T-2480: propagate session YAML-timestamp + worktree fixes to consumers (vendor refresh + land handoff)

## Context

Propagate the session's framework fixes to consumers without remote-upgrading
machines from this session. Two mechanisms: (a) refresh this repo's vendored
`.agentic-framework/` copies so the branch pushes and consumers inherit correct
copies on `fw upgrade`; (b) hand the branch→master land to the operator (operator
authority).

## Affected-host analysis (AC3)

**What's affected, and how badly:**
- **`integrate.py` union resolver** — used plain PyYAML with *no* ruamel guard, so
  it corrupted ISO-Z timestamps on **every** host. This is the leg that surfaced the
  class. Already FIXED and **on master** (T-2473, origin/master=47a20c351).
- **`bvp.sh` + `estimator.py` BVP frontmatter round-trip** — prefer ruamel, fall back
  to PyYAML. Corruption only fires where **ruamel.yaml is ABSENT**. Fixed in T-2477,
  currently on the branch — lands to master with this task.

**Severity is LOW / latent.** The BVP corruption only bites a host that BOTH
(a) runs `fw bvp confirm` or the BVP estimator (writes task frontmatter) AND
(b) lacks `ruamel.yaml`. This host has ruamel 0.19.1 → it never fired here.

**Per-host detection one-liner** (run on any host to see if it *was* exposed):
`python3 -c "import ruamel.yaml" 2>&1` — an ImportError means that host's BVP
write paths were reformatting `...Z` timestamps until it picks up the fix.

**Propagation mechanism (no remote upgrade from here):** once T-2480 lands to
master, each consumer inherits the corrected `bvp.sh`/`estimator.py`/`integrate.py`
on its next `fw upgrade` (which re-vendors `lib/` + `agents/`). Concrete per-consumer
action, run *in that consumer's own context* (not from this session):
`cd /path/to/consumer && .agentic-framework/bin/fw upgrade`
No emergency fan-out is warranted given the latent/low severity.

## Recommendation

**Recommendation:** GO — land the branch to master (FF-ready, clean).
**Rationale:** All session fixes are verified (T-2477 3/3 tests green, T-2473 union
resolver tested, Layer-2 worktree resolution verified live in T-2478). Vendored
copies in-sync, branch pushed, self-vendor gate clean. integrate check = FF-READY
(master +0). No conflicts.
**Land command (operator — branch→master is operator authority):**
`cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation && bin/fw integrate run master --push`

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] This repo's vendored `.agentic-framework/` copies of the session's framework edits are refreshed (`fw vendor self`) so `lib/bvp.sh`, `lib/integrate.py`, and `agents/termlink/bvp-estimator/estimator.py` are byte-identical between source and vendored copy (the self-vendor pre-push gate, T-2240, passes). — `fw vendor self` synced bvp.sh + estimator.py; all 3 verified in-sync; committed f264af001.
- [x] The branch is push-ready: `fw doctor`'s self-vendor check is clean (no "would sync" lines) OR the residual drift is explained. — broad vendored-drift scan = 0 stale; branch pushed clean (61734e966..f264af001), self-vendor gate passed.
- [x] Affected-host analysis recorded: which consumers/hosts actually inherit the YAML-timestamp corruption (ruamel-absent hosts only) and the concrete per-host action (`fw upgrade <path>` re-vendors lib/+agents/). NO remote machine is upgraded from this session — analysis + handoff only. — see ## Affected-host analysis: integrate.py leg (all hosts) already on master; bvp/estimator leg (ruamel-absent hosts only) lands with this task; detection one-liner + per-consumer `fw upgrade` action recorded; no fan-out.
- [x] Branch→master land is prepared and handed to the operator (Watchtower/CLI), since branch→master is operator authority — not self-executed. — integrate check = FF-READY (master +0); land command handed off in ## Recommendation (operator runs `fw integrate run master --push`).

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

### 2026-06-24T11:12:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2480-propagate-session-yaml-timestamp--worktr.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f998a187
- **Timestamp:** 2026-06-24T11:26:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — This repo's vendored `.agentic-framework/` copies of the session's framework edits are refreshed (`fw vendor self`) so `lib/bvp.sh`, `lib/integrate.py`, and `agents/termlink/bvp-estimator/estimator.py
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/bvp.sh in: This repo's vendored `.agentic-framework/` copies of the session's framework edits are refreshed (`fw vendor self`) so `lib/bvp.sh`, `lib/integrate.py`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `all hosts`

### 2026-06-24T11:26:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
