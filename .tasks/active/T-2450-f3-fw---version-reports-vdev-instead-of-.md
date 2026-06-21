---
id: T-2450
name: "F3: fw --version reports vdev instead of stamped VERSION on consumer installs (T-2441 dogfood)"
description: >
  F3: fw --version reports vdev instead of stamped VERSION on consumer installs (T-2441 dogfood)

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
created: 2026-06-21T11:48:45Z
last_update: 2026-06-21T11:48:45Z
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

# T-2450: F3: fw --version reports vdev instead of stamped VERSION on consumer installs (T-2441 dogfood)

## Context

T-2441 dogfood F3: a fresh consumer's `fw --version` reports **`vdev`** (install-time reported a real
version, e.g. `v1.6.25`). The report's named remediation ("`fw --version` should read the stamped
VERSION") was **already implemented** (bin/fw `_derive_version` line 38-39) — disproven as the cause.
The real root cause: `_derive_version` runs at script top, **before** the symlink resolution
(`FW_REAL_PATH`, bin/fw:57), using the unresolved `BASH_SOURCE[0]`. The global shim `~/.local/bin/fw`
is a **symlink** to the framework's `bin/fw`; invoked via that symlink, `fw_dir` resolves to the
symlink's parent (`~/.local` — no `.git`, no `VERSION`), so BOTH the git-describe and VERSION-file
branches miss → falls through to `"dev"` → `fw vdev`. Reproduced live: a symlink to `bin/fw` placed in
a bare dir reports `fw vdev`; direct invocation reports the real version.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — `_derive_version` resolves `BASH_SOURCE[0]` through symlinks (`readlink -f`/`realpath`, the
      same chain as `FW_REAL_PATH`) before deriving `fw_dir`, and uses that resolved `fw_dir` for BOTH
      the `.git` and `VERSION` branches. Invocation via a symlink no longer degrades to `dev`.
- [x] AC2 — regression test `tests/unit/fw_derive_version_symlink.bats` (4/4) pins: direct ≠ vdev,
      symlink-in-bare-dir ≠ vdev, symlink == direct, chained-symlink resolves through. `bash -n bin/fw`
      clean; no regression to `lib_version.bats` / the resolver bats (t2390/t2391/t2446) — confirmed.

## Verification

out=$(bats tests/unit/fw_derive_version_symlink.bats 2>&1); echo "$out" | grep -qE "^ok 4 " && ! echo "$out" | grep -q "^not ok"
bash -n bin/fw
grep -q 'readlink -f "$_src"' bin/fw

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

**Symptom:** a freshly-installed consumer's `fw --version` reports `vdev` (both via the bare global
shim and, as reported, project-local), even though install-time stamping reported a real version. The
user cannot tell what version they are running.

**Root cause:** `_derive_version` (bin/fw:16) computes `fw_dir` from the **unresolved** `BASH_SOURCE[0]`
and runs *before* the script's symlink resolution (`FW_REAL_PATH`, bin/fw:57). The global shim
`~/.local/bin/fw` is a symlink to the framework's real `bin/fw`. Invoked via the symlink, `fw_dir`
becomes the symlink's own parent (`~/.local/..`), which has neither `.git` nor a `VERSION` file, so the
git-describe branch is skipped and the VERSION-file branch (which already existed) is also missed →
the `else` arm returns `"dev"` → `fw vdev`.

**Why structurally allowed:** the VERSION fallback was correct but pointed at the wrong directory; the
two surfaces that resolve fw's location (`_derive_version` and `FW_REAL_PATH`) diverged — one resolves
symlinks, the other did not. No test exercised symlink invocation of `--version` (the global shim is
exactly that), so the divergence stayed invisible until a real global install surfaced it (T-2441 F3).
The report's named fix ("read VERSION") was a plausible-but-wrong hypothesis — disproven by reading the
code (the fallback was already there).

**Prevention:** (1) `_derive_version` now resolves `BASH_SOURCE[0]` via the same `readlink -f`/`realpath`
chain as `FW_REAL_PATH`, and uses the resolved `fw_dir` for both branches — the two surfaces no longer
diverge. (2) `tests/unit/fw_derive_version_symlink.bats` pins symlink invocation == direct invocation
(never `vdev`), so any future refactor that drops the resolution re-fails immediately.

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

### 2026-06-21T11:48:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2450-f3-fw---version-reports-vdev-instead-of-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-11ec284e
- **Timestamp:** 2026-06-21T11:53:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
