---
id: T-2380
name: "fw costs + 2 surfaces blind in worktrees — migrate stale transcript-dir reconstruction to fw_claude_project_dir_name (T-2375 completion)"
description: >
  fw costs + 2 surfaces blind in worktrees — migrate stale transcript-dir reconstruction to fw_claude_project_dir_name (T-2375 completion)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [capture-reader, agents/handover/discard-manifest.sh, lib/costs.sh, tests/unit/t2380_transcript_dir_encoding.bats]
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
created: 2026-06-13T20:37:21Z
last_update: 2026-06-13T20:45:05Z
date_finished: 2026-06-13T20:45:05Z
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

# T-2380: fw costs + 2 surfaces blind in worktrees — migrate stale transcript-dir reconstruction to fw_claude_project_dir_name (T-2375 completion)

## Context

`fw costs`, `discard-manifest.sh`, and `read-transcript.py` reconstruct the Claude Code transcript dir name with a slash-only sanitizer (`tr '/' '-'` / `.replace('/', '-')`), which diverges from Claude Code's full non-alnum encoding the moment a path contains a dot (i.e. any git worktree under `.claude/worktrees/`). T-2375 introduced the canonical `fw_claude_project_dir_name()` helper and migrated the budget gauge (checkpoint.sh/budget-gate.sh, completed by T-2377); these three read-surfaces were never migrated. This task finishes the migration. Discovered live: `fw costs session` → "No JSONL directory found at .../Framework-.claude-worktrees-..." (a `.` survived where Claude Code wrote `--claude`).

## Acceptance Criteria

### Agent
- [x] `lib/costs.sh` `_costs_jsonl_dir()` resolves the projects dir via `fw_claude_project_dir_name()` (no `tr '/' '-'`), sourcing `lib/paths.sh` if the helper is not already defined
- [x] `agents/handover/discard-manifest.sh` resolves the projects dir via `fw_claude_project_dir_name()` (no `tr '/' '-'`)
- [x] `agents/capture/read-transcript.py` sanitizes the project root with full non-alnum replacement (`re.sub(r'[^A-Za-z0-9]', '-', ...)`), not slash-only
- [x] `bin/fw costs session` run from this worktree exits 0 and finds the JSONL dir (no "No JSONL directory found")
- [x] Regression test pins the worktree-path encoding for the migrated surface(s) (a path containing a dot encodes the dot to `-`)

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

# No slash-only sanitizer remains in any of the 3 migrated surfaces (|| true: no-match grep exits 1 under set -e)
out=$(grep -nE "tr '/' '-'|replace\('/', '-'\)" lib/costs.sh agents/handover/discard-manifest.sh agents/capture/read-transcript.py 2>&1 || true); test -z "$out"
# fw costs resolves the worktree JSONL dir (no failure string)
out=$(bin/fw costs session 2>&1); ! echo "$out" | grep -q "No JSONL directory found"
# read-transcript.py still parses
python3 -c "import ast; ast.parse(open('agents/capture/read-transcript.py').read())"
# regression test green
bats tests/unit/t2380_transcript_dir_encoding.bats

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

**Symptom:** `fw costs session` reports `No JSONL directory found at .../Framework-.claude-worktrees-...`; agent perceives "can't self-measure token usage" in worktree/bg-job sessions. A `.` survived in the reconstructed path where Claude Code wrote `--claude`.

**Root cause:** `lib/costs.sh:41` (and siblings `discard-manifest.sh:37`, `read-transcript.py:34`) reconstruct the `~/.claude/projects/<dir>` name with a slash-only sanitizer (`tr '/' '-'`). Claude Code encodes the dir name by replacing **every** non-alphanumeric char (`tr -c 'a-zA-Z0-9' '-'`). The two agree only when the project path contains no characters other than `/` and alphanumerics. A git worktree path (`/opt/.../.claude/worktrees/...`) contains a `.` → the two diverge (`Framework-.claude` vs `Framework--claude`) → the reader looks in a directory that does not exist.

**Why structurally allowed:** for ~5 years all sessions ran in the **main repo** (`/opt/999-Agentic-Engineering-Framework` — a dot-free path), where slash-only sanitization happens to produce the correct dir name. The bug was latent and invisible until work moved into git worktrees. No test exercised a dotted project path. T-2375 created the canonical `fw_claude_project_dir_name()` helper and migrated the budget gauge, but a corpus-wide sweep for other slash-only reconstructions was never done — so these three read-surfaces silently kept the old code (silent-corpus pattern, L-397).

**Prevention:** (1) all three surfaces migrated to the single canonical helper / full non-alnum sanitization, removing the divergent private reconstructions; (2) `tests/unit/t2380_transcript_dir_encoding.bats` pins that a dotted path encodes the dot to `-` (regression guard for the worktree case specifically); (3) Verification grep asserts no `tr '/' '-'` / `.replace('/', '-')` slash-only sanitizer remains in the three files.

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

### 2026-06-13T20:37:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2380-fw-costs--2-surfaces-blind-in-worktrees-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0f10a636
- **Timestamp:** 2026-06-13T20:45:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 35
     - evidence: `out=$(bin/fw costs session 2>&1); ! echo "$out" | grep -q "No JSONL directory found"`

### 2026-06-13T20:45:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
