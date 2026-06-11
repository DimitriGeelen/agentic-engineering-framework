---
id: T-2287
name: "arc-010 follow-on: add policy/capability-overlay/tool-set.yaml to _self_vendor_policy
  (consumer MCP enablement)"
description: >
  Consumer-side framework_mcp_server.py is self-vendored to .agentic-framework/agents/mcp/
  but policy/capability-overlay/tool-set.yaml is excluded from _self_vendor_policy
  (lib/upgrade.sh:237-240). Consumer MCP server crashes on tool-set.yaml-not-found.
  Path (a) per OBS-063: structural one-liner — extend explicit list. Path (c) framing:
  arc-010 follow-on slice for consumer enablement (current arc-010 GO scope is framework-self
  only). Origin: OBS-063.

status: work-completed
workflow_type: build
owner: claude-code
horizon:
tags: [arc:capability-overlay, consumer, mcp, vendor-policy, obs-063]
components: []
related_tasks: [T-2265, T-2268, T-2241, T-2095]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-09T13:45:07Z
last_update: '2026-06-11T22:24:14Z'
date_finished: 2026-06-09T14:37:39Z
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
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T14:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2287: arc-010 follow-on: add policy/capability-overlay/tool-set.yaml to _self_vendor_policy (consumer MCP enablement)

## Context

Consumer projects vendor the framework MCP server to `.agentic-framework/agents/mcp/framework_mcp_server.py` (T-2266 self-vendor agents). The server reads `policy/capability-overlay/tool-set.yaml` at startup to classify tools as read-only vs agent-authority vs sovereignty-bound-excluded (T-2258). But `_self_vendor_policy()` in `lib/upgrade.sh:260` only loops over a flat two-file list (`value-drivers.yaml bvp-scoring-rubric.md`) — the capability-overlay subdirectory is never synced. Consumer-side MCP server thus crashes on `tool-set.yaml-not-found` after `fw upgrade`.

Path (a) per OBS-063: extend the explicit loop with `capability-overlay/tool-set.yaml` + add `mkdir -p $(dirname)` guard since the destination subdir doesn't exist in fresh vendored copies. Same shape as the existing two entries — same dry-run/real-run wording, same diff-vs-copy gate, same T-2240 pre-push regex catches the drift class.

## Acceptance Criteria

### Agent
- [x] `_self_vendor_policy()` in `lib/upgrade.sh` includes `capability-overlay/tool-set.yaml` in its sync list
- [x] `_self_vendor_policy()` creates the destination subdirectory (`.agentic-framework/policy/capability-overlay/`) before `cp` — `mkdir -p $(dirname "$_svp_dst")` guard added
- [x] `.agentic-framework/policy/capability-overlay/tool-set.yaml` exists and is byte-identical to `policy/capability-overlay/tool-set.yaml`
- [x] After running `bin/fw vendor self` once, `bin/fw vendor self --dry-run` reports zero "would sync" lines (clean state)
- [x] Mutating `policy/capability-overlay/tool-set.yaml` (then reverting) causes `bin/fw vendor self --dry-run` to report exactly one "would sync 1 file(s) to .agentic-framework/policy/" line — proving the T-2240 pre-push gate sees subdir drift
- [x] New bats test `tests/unit/t2287_self_vendor_policy_subdir.bats` covers: helper-defined ✓ / subdir-entry-listed ✓ / mkdir-guard-present ✓ / dry-run on mutate emits "would sync 1 file(s)" / real-run syncs and result is byte-identical / second dry-run is clean
- [x] All sibling self-vendor regression bats remain PASS (`t2095`, `t2241`, `t2266`, `t2267`)
- [x] `fw reviewer T-2287` returns Overall PASS

### Human
<!-- No Human section: all ACs above are deterministic / shell-verifiable. -->


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

# --- T-2287 ACs ---
grep -q 'capability-overlay/tool-set.yaml' lib/upgrade.sh
grep -qE 'mkdir -p .*dirname' lib/upgrade.sh
test -f .agentic-framework/policy/capability-overlay/tool-set.yaml && diff -q .agentic-framework/policy/capability-overlay/tool-set.yaml policy/capability-overlay/tool-set.yaml
out=$(bin/fw vendor self --dry-run 2>&1); test "$(echo "$out" | grep -c "would sync" || true)" = "0"
TMP_FILE=$(mktemp -p /tmp fw-t2287-mutate-XXXXXX); cp policy/capability-overlay/tool-set.yaml "$TMP_FILE"; printf '\n# T-2287 smoke mutation\n' >> policy/capability-overlay/tool-set.yaml; out=$(bin/fw vendor self --dry-run 2>&1); cp "$TMP_FILE" policy/capability-overlay/tool-set.yaml; echo "$out" | grep -qE "would sync 1 file\(s\) to .agentic-framework/policy/"
bats tests/unit/t2287_self_vendor_policy_subdir.bats
bats tests/unit/t2095_upgrade_self_vendor_extraction.bats tests/unit/t2241_upgrade_self_vendor_templates.bats tests/unit/t2266_self_vendor_agents.bats tests/unit/t2267_self_vendor_web.bats
out=$(bin/fw reviewer T-2287 --no-write 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-09 — _self_vendor_policy() generalised to handle subdir entries

- **What changed:** the existing helper's flat-list loop (`value-drivers.yaml bvp-scoring-rubric.md`) couldn't be extended with a subdir entry by just appending the path — `cp` would fail on missing destination directory. Added a single `mkdir -p "$(dirname "$_svp_dst")"` guard, gated on `dry_run != true` so dry-runs stay observation-only. The change is one-line + comment block + new loop entry; no new wiring or new function.
- **Plan impact:** keeps the helper backward-compatible for the two flat entries (mkdir is harmless when dir already exists). T-2240 pre-push regex (`would sync`) catches the new subdir drift without modification — same matcher line, same gate.
- **Triggered:** none. Bats test `t2287_self_vendor_policy_subdir.bats` mirrors `t2266_self_vendor_agents.bats` shape with one synthetic-fw fixture per behaviour leg.



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

### 2026-06-09T13:45:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2287-arc-010-follow-on-add-policycapability-o.md
- **Context:** Initial task creation

### 2026-06-09T14:33:32Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-06-09T14:33:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-76274845
- **Timestamp:** 2026-06-09T14:37:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-09T14:37:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
