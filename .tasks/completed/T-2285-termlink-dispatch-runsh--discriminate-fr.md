---
id: T-2285
name: "termlink dispatch run.sh — discriminate framework-self vs consumer when setting
  FRAMEWORK_ROOT (OBS-062 substrate fix)"
description: >
  termlink dispatch run.sh — discriminate framework-self vs consumer when setting
  FRAMEWORK_ROOT (OBS-062 substrate fix)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-09T11:40:31Z
last_update: '2026-06-11T22:24:14Z'
date_finished: 2026-06-09T11:44:14Z
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
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
      (no-signal); F-ORCH=1 (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2285: termlink dispatch run.sh — discriminate framework-self vs consumer when setting FRAMEWORK_ROOT (OBS-062 substrate fix)

## Context

OBS-062 surfaced during arc-010 HM-A demo-003 attempt (after T-2282 + T-2283 + T-2284 substrate trio was confirmed correct via meta.json + wdir artefacts). The framework MCP server's `_project_root()` (agents/mcp/manifest.py:24) honours FRAMEWORK_ROOT first, and the termlink dispatch run.sh template sets `FRAMEWORK_ROOT=$PROJECT_DIR/.agentic-framework` whenever `.agentic-framework/` exists. In the framework REPO itself (where `.agentic-framework/` is the self-vendored MIRROR, not the source), this redirects FRAMEWORK_ROOT away from the actual source. The MCP server then looks for `policy/capability-overlay/tool-set.yaml` in the mirror (which doesn't carry policy/) and refuses to start tool registration — leaving `mcp__fw__*` verbs unavailable to spawned workers even though `--mcp-config + --strict-mcp-config` is correctly applied.

Fix: discriminate framework-self vs consumer in run.sh BEFORE setting FRAMEWORK_ROOT. Use `FRAMEWORK.md` at PROJECT_DIR root as the discriminator — only the framework repo has it, consumers don't. When present → FRAMEWORK_ROOT=$PROJECT_DIR (treat as source). Otherwise fall back to existing logic (consumer or bare project). Out of scope: changing `_project_root()`'s env-var priority (that's the consumer-correct behaviour); duplicating policy/ into the self-vendor list (would diverge canonical-source semantics).

## Acceptance Criteria

### Agent
- [x] `run.sh` heredoc in `agents/termlink/termlink.sh` discriminates framework-self via `[ -f "$PROJECT_DIR/FRAMEWORK.md" ]` before redirecting FRAMEWORK_ROOT. Verification: `grep -qE 'PROJECT_DIR/FRAMEWORK.md' agents/termlink/termlink.sh`.
- [x] Three-branch logic: framework-self → FRAMEWORK_ROOT=PROJECT_DIR; consumer with `.agentic-framework/` → existing redirect preserved; bare project → FRAMEWORK_ROOT=PROJECT_DIR. Verification: bats test below covers all three.
- [x] Bats test `tests/integration/test_termlink_dispatch_framework_root.bats` covers ≥3 cases (framework-self, consumer-shape, bare-project), all PASS. Static-inspection style (mirrors T-2282/T-2284 pattern — extract the heredoc and assert structurally).
- [x] Vendored `.agentic-framework/agents/termlink/termlink.sh` in sync via `bin/fw vendor self`. Verification: `bin/fw vendor self --dry-run 2>&1` produces no "would sync" output.
- [x] [REVIEWER] Reviewer PASS via `bin/fw reviewer T-2285`.

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

# Discriminator in place
grep -qE 'PROJECT_DIR/FRAMEWORK.md' agents/termlink/termlink.sh

# Bats coverage for all three branches
bats tests/integration/test_termlink_dispatch_framework_root.bats

# Self-vendor in sync (no "would sync" line)
out=$(bin/fw vendor self --dry-run 2>&1); [ -z "$(echo "$out" | grep 'would sync')" ]

# Reviewer verdict (L-387 capture-then-grep, T-2094 markdown-bold pattern)
out=$(bin/fw reviewer T-2285 2>&1); echo "$out" | grep -qE "Overall:.*PASS"

## RCA

**Symptom:** arc-010 HM-A demo-003 (immediately after T-2284 substrate trio shipped) couldn't surface `mcp__fw__*` verbs to its spawned worker. ToolSearch returned "No matching deferred tools found" for all `mcp__fw__*` queries despite meta.json + wdir artefacts confirming `permission_mode=acceptEdits`, `mcp_config=.mcp.json`, `strict_mcp=true` were applied correctly. Worker's diagnostic Bash call exposed the proximate error: `ERROR: tool-set.yaml not found at /opt/999-Agentic-Engineering-Framework/.agentic-framework/policy/capability-overlay/tool-set.yaml`.

**Root cause:** Two-layer interaction. (1) `agents/mcp/manifest.py:_project_root()` honours `$FRAMEWORK_ROOT` first, then `$PROJECT_ROOT`, then walks for `bin/fw + policy/`. (2) `agents/termlink/termlink.sh` run.sh heredoc redirects `FRAMEWORK_ROOT=$PROJECT_DIR/.agentic-framework` WHENEVER `.agentic-framework/` exists — without discriminating whether `.agentic-framework/` is the vendored source (consumer case) or the self-vendored mirror (framework-repo case). In the framework repo, the redirect points FRAMEWORK_ROOT at the mirror, which doesn't carry `policy/` (canonical source-only assets aren't part of the self-vendor surface, by design). The MCP server fails to load tool-set.yaml and registers zero tools — `mcp__fw__*` never surfaces.

**Why structurally allowed:** The `.agentic-framework/` discriminator was correct when the framework had only ONE consumer shape (vendored). The framework-repo-self case emerged later (T-2095, self-vendor extraction) as an inverse-direction sync: the framework keeps a mirror of WHAT IT VENDORS so consumers can be diffed against canonical. Nothing in the run.sh logic recognised that `.agentic-framework/` now means two different things depending on caller-root identity. The OBS-058 → T-2282 → T-2283 → T-2284 chain treated each substrate failure as the "last one" because each fix surfaced new logs; OBS-062 only surfaced after the prior three were ALL correct, exposing this fourth layer. Classic onion-class debugging — one fix at a time, each demanding a clean trial dispatch.

**Prevention:** (1) bats test `test_termlink_dispatch_framework_root.bats` pins the three-branch logic structurally (7 tests covering framework-self, consumer-shape, bare-project, discriminator-order, live-smoke). (2) The discriminator comment in run.sh names the failure mode explicitly so the next reader doesn't repeat the analysis. (3) The substrate trio (T-2282/T-2283/T-2284) + T-2285 together form the complete set for non-interactive MCP workers, captured in L-468 — future demo attempts have a documented incantation. (4) OBS-062 entry was filed at hit-time and is now resolvable by T-2285. The deeper learning: framework-self vs consumer is a distinct DIMENSION from vendored vs source — both directions need explicit discrimination, not implicit `.agentic-framework/` presence-check.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Completes the substrate-fix chain (T-2282 permission-mode → T-2283 .mcp.json key → T-2284 mcp-config → T-2285 FRAMEWORK_ROOT discriminator) that arc-010 HM-A demo dispatch unearthed across two sessions. Three-branch run.sh logic preserves consumer-shape zero-regression (consumer with `.agentic-framework/` still redirects) while fixing framework-self (FRAMEWORK.md present → no redirect). 7/7 bats PASS, 19/19 sibling regression PASS (T-2282 + T-2284), reviewer PASS. The fix is mechanical, scope-bounded (one heredoc block in run.sh), and reversible (revert the 11 lines if needed).

**Evidence:**
- `agents/termlink/termlink.sh:705-723` — three-branch FRAMEWORK_ROOT logic with explicit comments
- `tests/integration/test_termlink_dispatch_framework_root.bats` — 7/7 PASS (incl. t6 discriminator-order, t7 live-smoke on current repo)
- `tests/integration/test_termlink_dispatch_permission_mode.bats` + `_mcp_config.bats` — 19/19 PASS (no regression)
- Reviewer R-9dffec72 — PASS, zero findings, AC #5 auto-ticked
- OBS-062 resolved by this task (substrate-class — would have stayed blind indefinitely without arc-010 demo unearthing it)

**Next move (operator or next agent):** re-dispatch arc-010 HM-A demo with the same incantation (`--permission-mode acceptEdits --mcp-config .mcp.json --strict-mcp-config`) — substrate quartet (T-2282/T-2283/T-2284/T-2285) is now complete. The framework MCP server should register all 22 tools from policy/capability-overlay/tool-set.yaml on startup, and the demo's `mcp__fw__work_on` + `mcp__fw__task_update` calls should resolve to live verbs.

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

### 2026-06-09T11:40:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2285-termlink-dispatch-runsh--discriminate-fr.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1aeaa997
- **Timestamp:** 2026-06-09T11:44:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#4 (Agent)

### 2026-06-09T11:44:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
