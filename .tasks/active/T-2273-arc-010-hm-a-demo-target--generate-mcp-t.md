---
id: T-2273
name: "arc-010 HM-A demo-target — generate MCP tools overview doc"
description: >
  Demo-target task for arc-010 Slice 3 (T-2268). Fresh Claude Code worker (spawned with .mcp.json configured for framework-mcp) drives this task end-to-end using ONLY mcp__fw__ verbs for governance — never Bash(bin/fw ...). Deliverable: docs/reports/arc-010-mcp-tools-overview.md, a 100-word overview of the 22 tools registered by the framework MCP server (16 read_only + 6 agent_authority per T-2265 + policy/capability-overlay/tool-set.yaml), grouped by capability. The headline mechanic fires when (a) this task moves captured→started-work→work-completed via mcp__fw__task_update calls, (b) the deliverable file exists, (c) transcript JSONL grep confirms mcp__fw__ usage and zero Bash(bin/fw task update|work-on|context focus) lines.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [arc:capability-overlay, mcp, demo-target, hm-a]
components: []
related_tasks: [T-2268, T-2265, T-2258, T-2209]
arc_id: capability-overlay
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-08T23:03:13Z
last_update: 2026-06-08T23:03:13Z
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

# T-2273: arc-010 HM-A demo-target — generate MCP tools overview doc

## Context

Demo-target for arc-010 Slice 3 (T-2268). Fresh Claude Code worker (spawned with `.mcp.json` configured per `agents/mcp/framework-mcp.mcp-fragment.json` — see T-2272) drives this task end-to-end using ONLY `mcp__fw__*` verbs for governance. Worker's prompt: `docs/reports/arc-010-hm-a-demo-prompt.md`. Transcript captured to `docs/reports/arc-010-hm-a-demo/transcript.jsonl` by the operator-orchestrated demo run. The headline mechanic (per `.context/arcs/capability-overlay.yaml:headline_mechanic`) fires when: (a) this task moves captured→started-work→work-completed via `mcp__fw__work_on` + `mcp__fw__task_update`, (b) deliverable file exists, (c) transcript shows zero `Bash(bin/fw task update|work-on|context focus)` lines for those verbs (proof: MCP-only governance).

## Acceptance Criteria

### Agent
<!-- Mechanical, verified from the deliverable + transcript. -->
- [ ] Deliverable file `docs/reports/arc-010-mcp-tools-overview.md` exists.
- [ ] Deliverable file word count between 80 and 150 words (`wc -w docs/reports/arc-010-mcp-tools-overview.md` ≥ 80 and ≤ 150).
- [ ] Deliverable groups the 22 framework MCP tools (16 read_only + 6 agent_authority per `policy/capability-overlay/tool-set.yaml`) into ≥ 4 named capability groupings (e.g. task / context / focus / fabric / handover / metrics).
- [ ] Deliverable references T-2265 (MCP server ship), T-2258 (tool-set artefact), and `policy/capability-overlay/tool-set.yaml` (path).
- [ ] `bin/fw reviewer T-2273` returns Overall: PASS or CONCERN with findings only in suppressible FP classes (mock-only-integration, AC-verify-mismatch). Override via `bin/fw reviewer override add T-2273 ...` if confirmed FP.

<!-- No Human ACs: deliverable is mechanical (file exists + word count + ≥4 groupings +
     references). Subject of every check is structural/grep-able — agent self-verifies
     per T-2143 audience axis. -->

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

test -f docs/reports/arc-010-mcp-tools-overview.md
wc=$(wc -w < docs/reports/arc-010-mcp-tools-overview.md); [ "$wc" -ge 80 ] && [ "$wc" -le 150 ]
out=$(cat docs/reports/arc-010-mcp-tools-overview.md); echo "$out" | grep -qE "T-2265"
out=$(cat docs/reports/arc-010-mcp-tools-overview.md); echo "$out" | grep -qE "T-2258"
out=$(cat docs/reports/arc-010-mcp-tools-overview.md); echo "$out" | grep -q "policy/capability-overlay/tool-set.yaml"
out=$(bin/fw reviewer T-2273 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-08T23:03:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2273-arc-010-hm-a-demo-target--generate-mcp-t.md
- **Context:** Initial task creation
