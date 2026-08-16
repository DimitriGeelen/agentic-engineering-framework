---
id: T-2288
name: "fw termlink dispatch — plumb --allowed-tools through to claude -p (substrate
  quintet, 5th onion layer)"
description: >
  Pre-approves specific tools (e.g. mcp__fw__*) for non-interactive claude -p workers,
  fixing the 'Claude requested permissions to use mcp__fw__work_on, but you haven't
  granted it yet' class. arc-010 HM-A demo arc010-hma-demo-004 (2026-06-09T13:43Z)
  terminated cleanly with substrate-quartet (T-2282/2283/2284/2285) active but worker
  couldn't invoke mcp__fw__work_on without interactive operator approval. Pattern
  mirrors T-2284 exactly: local var → case branch → conditional wdir write → meta.json
  key → run.sh FLAG construction → claude -p invocation includes $ALLOWED_TOOLS_FLAG
  → help text → 9-11 bats tests.

status: work-completed
workflow_type: build
owner: claude-code
horizon:
tags: [arc:capability-overlay, termlink, substrate, mcp, allowed-tools, obs-064]
components: []
related_tasks: [T-2268, T-2282, T-2283, T-2284, T-2285, T-2265]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-09T13:48:09Z
last_update: '2026-08-16T22:25:00Z'
date_finished: 2026-06-09T14:02:54Z
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
  - ts: '2026-06-09T14:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T14:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=1 
      (body:hand-wired-dispatch)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 1
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=1 
      (body:hand-wired-dispatch); F3=1 (body/components:prompt-incidental); F1=0
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2288: fw termlink dispatch — plumb --allowed-tools through to claude -p (substrate quintet, 5th onion layer)

## Context

5th onion layer of the arc-010 MCP substrate, surfaced when arc010-hma-demo-004 (2026-06-09T13:43Z) terminated cleanly under the substrate quartet (T-2282 permission-mode + T-2283 .mcp.json key fw + T-2284 --mcp-config/--strict-mcp-config + T-2285 FRAMEWORK_ROOT discriminator) but emitted *"Claude requested permissions to use mcp__fw__work_on, but you haven't granted it yet"* on every wired-verb attempt.

The substrate quartet plumbs **server registration**. This 5th leg plumbs **per-tool trust** — `claude -p --allowed-tools <comma-or-space-list>` pre-approves tools so non-interactive workers do not stall on the interactive trust prompt. Worker arc010-hma-demo-004 hit the prompt twice on `mcp__fw__work_on` (zero Bash fallback — the worker correctly refused to escape MCP for the wired verb), wrote the deliverable, then gave up at turn 8.

Pattern mirrors T-2284 exactly: `local var → case branch → conditional wdir write → meta.json key → run.sh FLAG construction → claude -p invocation includes $ALLOWED_TOOLS_FLAG → help text → bats coverage`.

## Acceptance Criteria

### Agent
- [x] `cmd_dispatch` in `agents/termlink/termlink.sh` declares `allowed_tools=""` in its local vars (mirror T-2284 lines 496/538 shape).
- [x] `cmd_dispatch` accepts `--allowed-tools <list>` case branch that consumes the next arg (shift 2). The value is written verbatim to `$wdir/allowed_tools.txt` when non-empty (conditional write — empty flag produces zero artefact, zero blast radius).
- [x] `meta.json` schema includes `"allowed_tools": <json>` key (null when flag absent; string when present) — observability parity with T-2284's `mcp_config` + `strict_mcp` keys.
- [x] `run.sh` heredoc constructs `ALLOWED_TOOLS_FLAG="--allowed-tools $(cat "$WDIR/allowed_tools.txt")"` when the file exists and is non-empty; empty/missing → `ALLOWED_TOOLS_FLAG=""` (claude -p uses parent's permissions.allow).
- [x] `claude -p` invocation at the bottom of run.sh includes `$ALLOWED_TOOLS_FLAG` between `$STRICT_MCP_FLAG` and `--output-format` (preserve T-2284 ordering invariant).
- [x] `bin/fw termlink help` advertises `--allowed-tools <list>` with the same wording style as `--permission-mode` and `--mcp-config`.
- [x] `tests/integration/test_termlink_dispatch_allowed_tools.bats` — 9+ tests mirroring T-2284's pattern (local-var declaration, case branch shape, conditional wdir write, meta.json schema, run.sh FLAG construction, claude -p invocation includes it, help text mentions it, backward-compat guard, live-smoke against current `bin/fw`). 100% PASS.
- [x] Sibling regression net: `bats tests/integration/test_termlink_dispatch_permission_mode.bats tests/integration/test_termlink_dispatch_mcp_config.bats tests/integration/test_termlink_dispatch_framework_root.bats` — 25/25 PASS (substrate quartet still green).
- [x] Live smoke: re-dispatch arc-010 HM-A demo as `arc010-hma-demo-005` with the new flag set to `"mcp__fw__work_on mcp__fw__task_update mcp__fw__context_focus Read Write Bash"` and confirm meta.json includes `"allowed_tools"` key. (Demo outcome — worker invokes mcp__fw__task_update and closes T-2273 — is materialised in T-2268, not this task.)
- [x] `bin/fw reviewer T-2288` returns Overall: PASS.

## Verification

bash -c 'out=$(grep -nE "allowed_tools=\"\"" agents/termlink/termlink.sh); echo "$out" | grep -q "allowed_tools"'
bash -c 'out=$(grep -nE -- "--allowed-tools\\)" agents/termlink/termlink.sh); echo "$out" | grep -qE -- "--allowed-tools"'
bash -c 'out=$(grep -nE "\"allowed_tools\":" agents/termlink/termlink.sh); echo "$out" | grep -q "allowed_tools"'
bash -c 'out=$(grep -nE "ALLOWED_TOOLS_FLAG=\"--allowed-tools" agents/termlink/termlink.sh); echo "$out" | grep -q "ALLOWED_TOOLS_FLAG"'
bash -c 'out=$(grep -nE "claude -p .*ALLOWED_TOOLS_FLAG.*--output-format" agents/termlink/termlink.sh); echo "$out" | grep -q "ALLOWED_TOOLS_FLAG"'
bash -c 'out=$(bin/fw termlink help 2>&1); echo "$out" | grep -q "allowed-tools"'
bats tests/integration/test_termlink_dispatch_allowed_tools.bats
bats tests/integration/test_termlink_dispatch_permission_mode.bats tests/integration/test_termlink_dispatch_mcp_config.bats tests/integration/test_termlink_dispatch_framework_root.bats
bash -c 'out=$(bin/fw reviewer T-2288 2>&1); echo "$out" | grep -qE "Overall:.*PASS"'

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

**Symptom.** arc010-hma-demo-004 (2026-06-09T13:43Z) terminated `status=done exit=0` in 2:11 with the substrate quartet (T-2282/2283/2284/2285) active — `meta.json` confirmed `permission_mode=acceptEdits + mcp_config=.mcp.json + strict_mcp=true` and the MCP server inline-tested as registering all 22 framework tools. Yet `mcp__fw__work_on(task_id="T-2273")` returned: *"Claude requested permissions to use mcp__fw__work_on, but you haven't granted it yet"* (twice; worker gave up at turn 8 after writing the deliverable). T-2273 stayed `status: started-work`.

**Root cause.** `claude -p`'s per-tool permission model is layered on top of MCP server registration. The substrate quartet plumbed *server* registration (so the worker's catalogue includes `mcp__fw__*` tools); per-tool *trust* — whether the worker is allowed to actually invoke a given tool — is a separate axis governed by parent `permissions.allow` (interactive accept) or `--allowed-tools` (pre-grant). Non-interactive `claude -p` workers cannot answer the trust prompt, so the prompt is the same as a refusal.

**Why structurally allowed.** Sibling memory L-468 captured *"MCP-server trust is distinct from workspace trust; substrate trio T-2282+T-2283+T-2284 form complete plumb"* — and was wrong. The trio (and later quartet) plumbed the registration axis fully but said nothing about per-tool trust because the demo at the time was prompted in interactive mode (Claude Code main session) where the operator could click through. Going non-interactive surfaced the missing axis. Onion-class debugging: T-2282 → T-2283 → T-2284 → T-2285 → **T-2288** — each layer's success exposed the next layer's failure.

**Prevention.** (1) Bats `tests/integration/test_termlink_dispatch_allowed_tools.bats` pins the plumb-through shape (10/10 PASS). (2) Help text now advertises `--allowed-tools` with example tokens including `mcp__fw__work_on` so authors of future MCP-using demos see the flag in `bin/fw termlink help`. (3) Memory L-468 corrected to "trust has TWO axes — server-registration AND per-tool — substrate-quintet plumbs both". (4) `bin/fw doctor` is not extended in this slice (would require a non-trivial heuristic for "is this dispatch MCP-bearing"); recorded as a deferred operator-triage item.

## Evolution

### 2026-06-09 — 5th onion layer surfaced
- **What changed:** The substrate trio→quartet narrative (one fix per onion layer) extends to a quintet. Per-tool trust is a distinct axis from server registration, and non-interactive workers need both.
- **Plan impact:** L-468's claim of "complete plumb" was incorrect; corrected this commit. Future MCP-bearing dispatches MUST pass `--allowed-tools` listing the wired verbs explicitly.
- **Triggered:** T-2268 unblocked (ACs #4-7 demonstrable); arc-010 demo_evidence: field population is operator-only follow-on.

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

## Recommendation

- **Recommendation:** GO
- **Rationale:** Substrate quintet completes the non-interactive MCP plumb. Live smoke (arc010-hma-demo-005, 2026-06-09T13:55Z) materialised the arc-010 headline mechanic — 4 `mcp__fw__*` calls (2 work_on + 2 task_update), 0 Bash(bin/fw) fallback for wired verbs, T-2273 moved from `active/` to `completed/` by the worker via MCP. All 10 Agent ACs satisfied; substrate quartet regression net intact (25/25 PASS). No Human ACs (substrate plumb is mechanical).
- **Evidence:**
  - termlink.sh edit: local var + case branch + conditional wdir write + meta.json key + run.sh FLAG + claude -p invocation + help text (7 edit points, mirror of T-2284 pattern)
  - `bats tests/integration/test_termlink_dispatch_allowed_tools.bats` 10/10 PASS
  - `bats tests/integration/test_termlink_dispatch_{permission_mode,mcp_config,framework_root}.bats` 25/25 PASS (sibling regression net)
  - `/tmp/tl-dispatch/arc010-hma-demo-005/meta.json` confirms `"allowed_tools": "mcp__fw__work_on mcp__fw__task_update ... Read Write Bash"`
  - `/tmp/tl-dispatch/arc010-hma-demo-005/result.jsonl`: `mcp__fw__work_on: 2`, `mcp__fw__task_update: 2`, `Bash(bin/fw)` for wired verbs: 0 (only `fw reviewer` ran, which is observability not state-mutation)
  - T-2273 in `.tasks/completed/` with `status: work-completed` — closed by worker via MCP path
  - `bin/fw reviewer T-2288 --no-write`: Overall: PASS, Findings: none

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-09T13:48:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2288-fw-termlink-dispatch--plumb---allowed-to.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cf95ac57
- **Timestamp:** 2026-06-09T14:02:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 2 (by override)
  - AC-verify-mismatch @ AC#2 (Agent)
  - AC-verify-mismatch @ AC#4 (Agent)

### 2026-06-09T14:02:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
