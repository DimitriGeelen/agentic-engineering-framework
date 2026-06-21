---
id: T-2446
name: "F10 residual — CLAUDE_PROJECT_DIR trusted without cwd-consistency check (daemon-inheritance leak)"
description: >
  F10 residual — CLAUDE_PROJECT_DIR trusted without cwd-consistency check (daemon-inheritance leak)

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
created: 2026-06-21T10:09:27Z
last_update: 2026-06-21T10:28:38Z
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

# T-2446: F10 residual — CLAUDE_PROJECT_DIR trusted without cwd-consistency check (daemon-inheritance leak)

## Context

**Origin / reframe of F10 (T-2441 dogfood, T-2442 batch).** F10 was filed as "`fw serve` from a fresh
consumer misidentifies the project as /opt/999." Investigation under T-2445's session **disproved that
framing**: a real operator terminal (no `CLAUDE_PROJECT_DIR` in env) resolves the consumer correctly —
`watchtower status` from a fresh `fw init` consumer prints "Watchtower is **not running**" (correct). The
original /opt/999 observation came from running inside a **TermLink shell** (`aef-install-505`) that
inherited `CLAUDE_PROJECT_DIR=/opt/999-Agentic-Engineering-Framework` from the long-lived TermLink daemon
(itself spawned by a Claude Code session in the framework repo). Proof (live, via TermLink):

| `CLAUDE_PROJECT_DIR` | `<consumer>/.agentic-framework/bin/fw watchtower status` |
|----------------------|----------------------------------------------------------|
| unset                | "Watchtower is not running" ✓ (resolves to consumer)     |
| `=/opt/999-…`        | resolves to /opt/999's Watchtower (the F10 symptom)      |

**Real residual bug.** `bin/fw:195-197` (T-2390) trusts `CLAUDE_PROJECT_DIR` whenever it points at a dir
with a `.framework.yaml`/`.tasks` marker — with **no check that it's consistent with cwd**. T-2390's
stated assumption ("only kicks in inside a CC hook context") is violated by daemon inheritance: a long-lived
CC-spawned daemon (TermLink, cron) propagates `CLAUDE_PROJECT_DIR` to **every** descendant shell, so `fw`
run from inside a *different* project mis-resolves to the daemon's project. This is the daemon-poison class
T-2391 already fixed for inherited `PROJECT_ROOT` (`_project_root_is_stale`) — but `CLAUDE_PROJECT_DIR`
(T-2390) never got the equivalent cwd-consistency validation.

**Blast / urgency.** Agent/automation-facing only — never bites real operators (their `CLAUDE_PROJECT_DIR`
is unset). It bit this session's task-closes (had to pass `PROJECT_ROOT="$(pwd)"` explicitly via TermLink).
Workaround exists (set `PROJECT_ROOT` explicitly). **High-blast core path** (bin/fw:181-201 is the
most-poked resolver — T-2389/T-2390/T-2391/T-2392, each live-fire-validated). Parked `horizon: next`:
deserves a focused session with full dual-case live-fire, NOT a tack-on to a context-deep turn.

**Proposed fix (needle-threading — preserve T-2389/T-2390, fix the leak).** In `bin/fw:195-200`, prefer
`CLAUDE_PROJECT_DIR` **unless** a cwd-ancestry walk (`find_project_root`) finds a *different* valid project
root. Logic: if `find_project_root` succeeds AND differs from `CLAUDE_PROJECT_DIR`, the shell is genuinely
inside another project → cwd wins; else (cwd=$HOME / no marker above, the CC-hook case) → `CLAUDE_PROJECT_DIR`
wins (T-2389/2390 preserved). Must keep `tests/.../test_project_root_discovery.py` green and add a
dual-case regression (CC-hook cwd=$HOME → CLAUDE_PROJECT_DIR wins; consumer-cwd + stale CLAUDE_PROJECT_DIR →
cwd wins), live-fired via a TermLink shell (the channel that surfaced this).

## Acceptance Criteria

### Agent
- [x] AC1 — `bin/fw:195-200`: `CLAUDE_PROJECT_DIR` wins only when a cwd-ancestry `find_project_root` does
      NOT find a different valid project root; otherwise cwd wins. T-2389/T-2390 hook case (cwd=$HOME, no
      marker above) still resolves to `CLAUDE_PROJECT_DIR`. **Done** — discriminator is the shared
      `_project_root_is_stale` (T-2391's =$HOME/no-marker test), reused so both daemon-poison guards stay in
      lockstep. cwd wins only when the cwd-root is a real, non-$HOME project differing from CLAUDE_PROJECT_DIR.
- [x] AC2 — Dual-case regression added: (a) CC-hook (cwd=$HOME-like, no ancestry marker) → CLAUDE_PROJECT_DIR
      wins; (b) consumer-cwd with a *stale/foreign* CLAUDE_PROJECT_DIR → cwd consumer wins. Live-fired via
      TermLink (OBS-080 bypass). **Done** — `tests/unit/t2446_project_root_cwd_consistency.bats` (4 tests:
      (b) consumer-wins, (a) $HOME-stray-poison → CPD-wins, (a) no-marker → CPD-wins, env-PROJECT_ROOT-wins).
      4/4 green; sibling t2390 (3/3, reconciled t1) + t2391 (6/6) all green = 13/13.
- [x] AC3 — `tests/unit/test_project_root_discovery.py` (and the env-wins-unconditionally PROJECT_ROOT test)
      remain green — the change touches only the CLAUDE_PROJECT_DIR branch, not the PROJECT_ROOT env contract.
      **Done** — unit 7/7 + web 4/4 green via TermLink. t2391 t3/t4 (env-wins-unconditionally) green.
- [x] AC4 — Live-fire confirmation: a fresh `fw init` consumer, run with a stale `CLAUDE_PROJECT_DIR=/opt/999`,
      reports its OWN watchtower state (not /opt/999's). **Done** — fresh `fw init` consumer at /tmp; /opt/999's
      Watchtower running on :3005; from consumer cwd + stale `CLAUDE_PROJECT_DIR=/opt/999`, patched fw resolved
      `Project: <consumer>` and "Watchtower is not running" (consumer's own state, NOT /opt/999's :3005).

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

bash -n bin/fw
bats tests/unit/t2446_project_root_cwd_consistency.bats
bats tests/unit/t2390_project_root_claude_dir.bats
bats tests/unit/t2391_project_root_inherited_stale.bats
python3 -m pytest tests/unit/test_project_root_discovery.py -q
python3 -m pytest tests/web/test_project_root_discovery.py -q -p no:cacheprovider
grep -q "T-2446: CLAUDE_PROJECT_DIR is trusted ONLY" bin/fw

## RCA

**Symptom:** `fw` run from inside a consumer project resolves PROJECT_ROOT to a *different*
project (`/opt/999`) when a long-lived Claude-Code-spawned daemon (TermLink, cron) has leaked
`CLAUDE_PROJECT_DIR` into the descendant shell's environment. Observed in the T-2441 onboarding
dogfood: a TermLink shell rooted in `/opt/505` reported `/opt/999`'s Watchtower (F10).

**Root cause:** `bin/fw:195` (T-2390) trusted `CLAUDE_PROJECT_DIR` whenever it pointed at a dir
with a `.framework.yaml`/`.tasks` marker, with **no cwd-consistency check**. T-2390's stated
assumption — "only kicks in inside a CC hook context, so non-hook fw calls are unaffected
(CLAUDE_PROJECT_DIR unset)" — is violated by daemon inheritance: a CC-spawned daemon exports
`CLAUDE_PROJECT_DIR` to **every** descendant, so it is *not* unset for non-hook calls made from
inside other projects. The CLAUDE_PROJECT_DIR branch was the exact mirror of the inherited-
`PROJECT_ROOT` poison T-2391 had already fixed via `_project_root_is_stale` — but that
discriminator was never applied to the CLAUDE_PROJECT_DIR branch.

**Why structurally allowed:** T-2390 and T-2391 were authored as two separate live-fire fixes
(budget-gauge blindness) and never reconciled into a single "daemon-inherited env var" contract.
T-2391 guarded `PROJECT_ROOT`; T-2390 introduced the sibling `CLAUDE_PROJECT_DIR` precedence one
commit earlier without the same guard. The gap is agent/automation-facing only (real operators
have `CLAUDE_PROJECT_DIR` unset), so it never surfaced in operator use — only in TermLink/cron
descendants, which is precisely where it bit this session's task-closes.

**Prevention:** (1) the fix reuses `_project_root_is_stale` so the two guards now share one
discriminator and cannot drift; (2) `tests/unit/t2446_project_root_cwd_consistency.bats` pins the
dual-case contract (consumer-cwd wins / $HOME-poison + no-marker → CLAUDE_PROJECT_DIR wins);
(3) the reconciled `t2390` t1 now makes the `$HOME` signature load-bearing, so a future change that
re-broadens CLAUDE_PROJECT_DIR trust will fail t2446 rather than silently regress.

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

### 2026-06-21 — discriminator: reuse `_project_root_is_stale`, not "any different root"
- **Chose:** cwd wins only when `find_project_root` returns a **non-stale** root (marker present
  AND != `$HOME`) differing from `CLAUDE_PROJECT_DIR` — reusing T-2391's `_project_root_is_stale`.
- **Why:** The task's literal proposal ("if find_project_root finds a *different* root → cwd wins")
  is under-specified: it silently regresses T-2390's real production case — a stray `$HOME/.tasks`
  (e.g. `/root/.tasks`) that the `$PWD` walk latches when hooks run with cwd=`$HOME`. Under the
  literal rule that stray would be a "different root" and cwd would wrongly win, re-breaking the
  budget-gauge blindness T-2390/T-2391 fixed. `_project_root_is_stale` already encodes exactly the
  `=$HOME`/no-marker test, so reusing it keeps the two daemon-poison guards in lockstep and cannot
  drift.
- **Rejected:** (a) "any different root → cwd wins" — regresses the `$HOME`-stray case above.
  (b) Discriminate on `.framework.yaml`-presence (consumer has it, stray `/root/.tasks` doesn't) —
  fragile: the framework repo itself has `.tasks` but no `.framework.yaml`, so this would mis-handle
  framework-repo cwds; `$HOME`-exclusion is the property that actually distinguishes poison from a
  genuine project.
- **Consequence:** `t2390` t1 had to be reconciled — its mktemp decoy was a non-`$HOME` stand-in for
  the `$HOME`-poison case; the refined contract makes the `$HOME` signature load-bearing, so t1 now
  pins `HOME=$DECOY`. Faithful to t1's original *intent* (production cwd=`$HOME`), not a green-washing.

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

### 2026-06-21T10:09:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2446-f10-residual--claudeprojectdir-trusted-w.md
- **Context:** Initial task creation

### 2026-06-21T10:10:54Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: next → next

### 2026-06-21T10:28:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fada5be7
- **Timestamp:** 2026-06-21T10:34:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
