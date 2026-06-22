---
id: T-2459
name: "Slice 1 (T-2458 C): fw init/upgrade auto-wire the fw MCP server into consumer .mcp.json"
description: >
  Slice 1 (T-2458 C): fw init/upgrade auto-wire the fw MCP server into consumer .mcp.json

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
created: 2026-06-22T08:47:40Z
last_update: 2026-06-22T09:32:33Z
date_finished: 2026-06-22T09:32:33Z
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

# T-2459: Slice 1 (T-2458 C): fw init/upgrade auto-wire the fw MCP server into consumer .mcp.json

## Context

Slice 1 (C) of T-2458 (GO). Goal: consumers receive a *working* `fw` MCP via `fw init`/`upgrade`.

**Grounding against the real `/opt/505-Ring20-Site` consumer (2026-06-22) reshaped this slice — it is
NOT a one-line `.mcp.json` add.** Wiring a server that doesn't yet function in a consumer would just
register a failing MCP (the OBS-058/061 "pending" class). Findings:

1. **`policy/` is not vendored to consumers** — `/opt/505/.agentic-framework/policy/` does not exist, so
   `tool-set.yaml` (the server's catalogue source via `load_tool_set()`) is absent → server would crash
   at startup. (Same sync-helper-filter class as T-2455/T-2436.)
2. **Root resolution is framework-repo-shaped.** `manifest._project_root()` walks up from `__file__` to
   the dir with `bin/fw`+`policy/` → in a consumer that's `.agentic-framework/`, and the server uses it
   as `cwd` for `_run_fw`. So fw would operate on the *vendored* dir, not the consumer project (tasks/
   notes/focus would land in `.agentic-framework/`). The framework-repo case never exposed this because
   project root == framework root == cwd there (classic T-1633 consumer-breakage class).
3. **`import mcp` works on this host** (one less blocker), but fresh-machine availability is unverified.
4. **Consumer `.mcp.json` has no `fw` entry** — RC-1 confirmed live.

**Clean architecture (proposed):** the server should (a) read the **vendored manifest**
(`agents/mcp/framework-mcp-manifest.json`, already vendored under `agents/`) as its catalogue — removes
the tool-set.yaml-not-vendored blocker, no yaml parse, self-contained; (b) split **framework_root**
(locate manifest + `bin/fw`, relative to `__file__`) from **project_root** (the consumer project =
`framework_root.parent` when vendored, else `framework_root` — used as `cwd` for `fw`); (c) only then
wire init/upgrade.

**Decomposition (Task Sizing: 3+ independent problems → split):**
- **T-2459 (this) — enabling server fix:** read vendored manifest + framework/project root split, so the
  vendored server works against the consumer project. Verifiable live against `/opt/505`.
- **(follow-on) wiring:** `fw init`/`upgrade` add the `fw` entry to consumer `.mcp.json` (pointing at
  `.agentic-framework/agents/mcp/framework_mcp_server.py`); pinned by `upgrade_fresh_machine_simulation.bats`.
- **(follow-on) dep guarantee:** ensure `mcp` python pkg present in consumer envs (or graceful degrade).

This task is now scoped to the **enabling server fix** (the prerequisite). Wiring + dep follow once the
server is proven to operate on the consumer project.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Server resolves a distinct **framework_root** (manifest + `bin/fw` location) and **project_root**
      (fw operating dir = consumer root when vendored, framework root otherwise); unit test covers both layouts
      → `manifest.framework_root()`/`project_root()`; t2459 t1/t2/t3/t6 (framework + vendored layouts).
- [x] Server loads its tool catalogue from the vendored manifest when `tool-set.yaml` is absent
      (consumer case), falling back to `tool-set.yaml` in the framework repo
      → `manifest.load_catalogue()`; t2459 t4 (tool-set preferred) + t5 (manifest fallback, fw_command preserved).
- [x] `fw` invoked by the server runs with `cwd = project_root` (consumer root), proven by a test asserting
      the resolved cwd for a synthetic `.agentic-framework/` layout
      → `_run_fw(fw_root, proj_root, …)`: bin/fw from framework_root, cwd=project_root; t2459 t6 + t9 (server build).
- [x] Live: against `/opt/505-Ring20-Site`, the vendored server starts, lists tools, and a read-only tool
      (e.g. `version`/`metrics`) operates on the /opt/505 project (not `.agentic-framework/`)
      → with my 3 files copied into /opt/505/.agentic-framework: `framework_root=/opt/505/.agentic-framework`,
      `project_root=/opt/505-Ring20-Site` (NOT `.agentic-framework/`), catalogue=22 via manifest fallback,
      server built, `fw version`/`task list` rc=0 with cwd=project_root. /opt/505 restored after.
      **Caveat (separate pre-existing bug → OBS filed):** /opt/505's *own* stale vendored `bin/fw` mis-resolves
      its project root to the framework (reports 234 tasks vs its own 7) regardless of cwd — reproduced with
      zero server involvement (`cd /opt/505 && .agentic-framework/bin/fw task list` → 234). The MCP fix's job
      (hand `fw` the correct cwd=project_root) is done; the consumer-fw mis-resolution is the wiring/re-vendor
      slice's concern (a freshly-upgraded consumer carries the T-2389/2390/2391 resolution fixes).
- [x] No regression: existing `agents/mcp` tests + manifest emit stay green
      → t2459 9/9, t2293 4/4, test_orchestrator_mcp_classify 22/22, t2290/t2294/t2296 drift suite green;
      `fw mcp check` = in sync (22 tools). t2272 wire-fragment failures are pre-existing (`git diff HEAD` = 0
      lines on fragment + test; fragment top-key is `fw` but T-2272 test asserts `framework-mcp`) — OBS filed.

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
#
# Fast + decisive only (slow doctor/audit drift tests verified manually, cited
# in ACs — kept out of the gate to avoid the F6 ~150s doctor timeout). FRAMEWORK_ROOT
# pinned to cwd + PROJECT_ROOT unset for hermeticity (L-490).
out=$(env -u PROJECT_ROOT FRAMEWORK_ROOT="$(pwd)" bats tests/unit/t2459_mcp_server_root_split.bats 2>&1); echo "$out" | grep -qE "^ok 9 " && ! echo "$out" | grep -q "^not ok"
out=$(env -u PROJECT_ROOT FRAMEWORK_ROOT="$(pwd)" bats tests/unit/t2293_mcp_check.bats 2>&1); echo "$out" | grep -qE "^ok 4 " && ! echo "$out" | grep -q "^not ok"
out=$(bin/fw mcp check 2>&1); echo "$out" | grep -q "in sync"
out=$(env -u PROJECT_ROOT FRAMEWORK_ROOT="$(pwd)" python3 -m pytest tests/unit/test_orchestrator_mcp_classify.py -q 2>&1); echo "$out" | grep -qE "[0-9]+ passed" && ! echo "$out" | grep -qE "failed|error"

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

### 2026-06-22 — catalogue source for the consumer case
- **Chose:** enrich the **vendored manifest** (`framework-mcp-manifest.json`, already vendored under
  `agents/`) with `fw_command`+`description` per tool, and have the server load from tool-set.yaml when
  present (framework/dev) else the manifest (consumer). `_manifest_tool` uses `.get("fw_command")` so a
  malformed/partial source entry can't crash emission (and the drift-test path stays green).
- **Why:** the manifest is *already* vendored to consumers and is JSON (no yaml dep at runtime); making it a
  self-contained runtime catalogue removes the "policy/ not vendored" blocker without adding a second
  vendor-filter change. It also aligns with slice 2 (B = codegen the catalogue) — the server reads the
  emitted manifest regardless of how it was produced.
- **Rejected:** (a) vendor `policy/capability-overlay/tool-set.yaml` to consumers — adds a vendor-filter
  change + runtime yaml dep + two files to keep in sync in the consumer; (b) read the *un-enriched* manifest
  — it lacked `fw_command`, so the server couldn't actually run any tool.

### 2026-06-22 — framework_root vs project_root split
- **Chose:** `framework_root` from `__file__` (`parents[2]`, FRAMEWORK_ROOT override) for assets + bin/fw;
  `project_root` = `framework_root.parent` when vendored (`.agentic-framework`) else itself, PROJECT_ROOT
  override; `bin/fw` from framework_root, subprocess `cwd` from project_root.
- **Why:** the old `_project_root()` conflated the two — invisible in the framework repo (project == framework
  == cwd) but wrong in a consumer, where fw must operate on the consumer checkout, not the vendored dir
  (T-1633 consumer-breakage class). `_project_root` kept as a back-compat alias → `framework_root` (its
  historic callers were asset-path lookups).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-22T08:47:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2459-slice-1-t-2458-c-fw-initupgrade-auto-wir.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1ae15fb5
- **Timestamp:** 2026-06-22T09:32:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-22T09:32:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
