---
id: T-2501
name: "claude-fw --worktree strips FW_CLAUDE_FW_SUPERVISED — worktree sessions silently unsupervised"
description: >
  claude-fw --worktree strips FW_CLAUDE_FW_SUPERVISED — worktree sessions silently unsupervised

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
created: 2026-06-25T12:53:15Z
last_update: 2026-06-25T12:53:15Z
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

# T-2501: claude-fw --worktree strips FW_CLAUDE_FW_SUPERVISED — worktree sessions silently unsupervised

## Context

Launching `claude-fw --worktree <name> --resume` produced a session where
`FW_CLAUDE_FW_SUPERVISED` is unset and `fw doctor` reports unsupervised — even
though `bin/claude-fw:33` unconditionally exports the marker before launching
`claude`. The T-2499 loudness WARN fired correctly, surfacing the gap. If the
mechanism is real, the arc-012 budget-critical auto-restart loop silently does
not arm for any worktree-launched session (the 300K→350K overrun class T-2499
was built to make loud). RCA the mechanism, confirm it, then fix so worktree
sessions are supervised (or fail loud at launch).

## Acceptance Criteria

### Agent
- [x] Process ancestry traced: determine whether `claude-fw` is an ancestor of this session's process, and which (if any) ancestor carries `FW_CLAUDE_FW_SUPERVISED=1` in `/proc/PID/environ`. Finding recorded in `## RCA`.
- [x] Mechanism confirmed: the specific reason the marker does not reach the session is identified and evidenced (not inferred) — recorded in `## RCA` with the structural "why allowed" leg.
- [ ] Fix shipped IF a code fix is warranted: worktree-launched `claude-fw` sessions either inherit the marker or fail loud at launch. If RCA concludes no code fix is appropriate (e.g. Claude Code-internal), `## RCA` states that explicitly with rationale and the prevention is a doc/learning.
- [ ] Regression coverage: a test or doctor/audit signal pins the fixed behaviour (or, if no code fix, a learning captures the class for the next agent).

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

**Symptom:** Operator launched `claude-fw` (from inside the worktree cwd) and
believed the session was supervised. `fw doctor` reported `WARN Unsupervised
session — auto-restart will NOT fire`, and `FW_CLAUDE_FW_SUPERVISED` was unset
in the session environment. The arc-012 budget-critical auto-restart loop would
not have armed for this session.

**Trace (verified, not inferred):**
- Process ancestry confirmed `claude-fw` IS the parent: `/bin/bash
  /root/.local/bin/claude-fw --resume` → child `claude --resume` → this shell.
  (The real argv was `claude-fw --resume`, not `--worktree …`; we are in the
  worktree because the wrapper was run from the worktree cwd.)
- `FW_CLAUDE_FW_SUPERVISED` absent in `/proc/<claude>/environ` AND in the
  wrapper's own environ → the export never reached the child.
- `/root/.local/bin/claude-fw` → symlink → `/root/.agentic-framework/bin/claude-fw`.
- The symlink target is a STALE vendored copy: 344 lines, **no**
  `FW_CLAUDE_FW_SUPERVISED` line. Repo `bin/claude-fw` is 352 lines WITH the
  export at line 33. `diff -q` → DIFFER. `grep` → export present in repo,
  absent in installed.

**Root cause:** NOT a logic bug in claude-fw — the wrapper code is correct. It
is a **deployment-propagation gap**. T-2499's export shipped to the repo
`bin/claude-fw`, to master, and to MAIN's running code (integrate-go-live syncs
`lib agents bin` inside `/opt/999-…`). But the wrapper the operator actually
executes lives at a THIRD location — the host's vendored framework tree
`~/.agentic-framework/bin/claude-fw` — which the go-live path never refreshes.
The running wrapper is therefore a different (older) file than the one shipped.

**Why structurally allowed:** Same class as [[project_t2494_deploy_whackamole_rca]]
(deploy whack-a-mole — code lives in N locations, no declared topology, no
end-to-end verifier). The claude-fw wrapper has an extra deploy hop nobody
declared: `repo bin/` → vendored `~/.agentic-framework/bin/` → `~/.local/bin`
symlink. The symlink hop is self-currenting; the **repo → vendored** hop is the
stale leg, and nothing in go-live, no `fw doctor` check, and no audit detects
that the host-installed `claude-fw` has drifted from repo source. The T-2499
loudness WARN caught the *symptom* (this session unsupervised) but there was no
signal pointing at the *cause* (stale installed wrapper).

**Prevention:** (pending refresh-path finding — see Decisions) — candidate legs:
(a) `fw doctor` drift check comparing installed `claude-fw` (resolve symlink)
against repo `bin/claude-fw`; (b) make the host install a symlink/checkout to
the live tree rather than a copy; (c) fold `~/.agentic-framework` refresh into
the go-live / vendor-self path so bin/ changes propagate to the installed
wrapper. Fix + prevention finalised once the intended refresh command is known.

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

### 2026-06-25T12:53:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2501-claude-fw---worktree-strips-fwclaudefwsu.md
- **Context:** Initial task creation
