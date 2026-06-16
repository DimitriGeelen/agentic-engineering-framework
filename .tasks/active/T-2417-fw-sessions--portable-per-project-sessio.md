---
id: T-2417
name: "fw sessions — portable per-project session view (implements T-2416 GO)"
description: >
  fw sessions — portable per-project session view (implements T-2416 GO)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/sessions/claude-code/list.sh, agents/sessions/render.py, agents/sessions/SCHEMA.md, bin/fw, tests/unit/sessions_claude_code_adapter.bats, tests/unit/sessions_render.bats]
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
created: 2026-06-16T09:20:14Z
last_update: 2026-06-16T10:25:46Z
date_finished: 2026-06-16T10:23:06Z
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
  - ts: '2026-06-16T09:30:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-16T09:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2417: fw sessions — portable per-project session view (implements T-2416 GO)

## Context

Implements T-2416 GO. Adds a new `fw sessions` verb that prints sessions grouped by project (cwd basename) with nested `Needs input` / `Working` / `Completed` sub-sections — a side-channel view that does NOT touch CC's native picker (T-2414 proved that bypasses it entirely). Portable: generic verb + provider-adapter layer; CC adapter only knows `claude agents --json`.

## Decisions

(Locked from T-2416 inception's Open Questions, operator confirmed 2026-06-16.)

### Canonical schema (IW-5)
- **MUST emit per session:** `provider`, `project`, `name`, `state`, `age_seconds`, `session_id`
- **OPTIONAL:** `cwd`, `description` (right-column text — CC's `detail`/`needs` field), `detail`
- **`project` field semantics:** `basename(cwd)` if cwd is inside a git repo on this host; literal string `"(loose)"` if cwd is `$HOME`, `/tmp`, or any non-repo path
- **`state` values:** `needs-input | working | completed` (renderer maps adapter's native states to these three)
- **`age_seconds`:** integer; renderer formats as relative (`2d`, `1h`, `11m`)

### Render layout (IW-1, IW-2, IW-3, IW-4)
- **v1 = static print to stdout.** No interactive attach, no curses. Pipes/redirects cleanly.
- **Order:** real projects first (alphabetical by project name); `(loose)` bucket last.
- **Within each project:** state-first ordering — `Needs input` first, then `Working`, then `Completed`. Within each state group, most-recent-activity first.
- **Age format:** relative (`2d`, `1h`, `11m`, `< 1m`). Matches CC's picker.
- **Loose-cwd bucket:** single section `// (loose)` at the bottom; do not subdivide HOME/TMP/SYSTEM.

### Provider autodetect (IW-6)
- Probe order: `command -v claude` → `cursor` → `aider` → `cline`
- Explicit override: `FW_AGENT_PROVIDER=<name>` (env var, takes precedence over probe)
- If no probe matches and no override: exit 2 with message "no session adapter for this host; set FW_AGENT_PROVIDER or install one of: claude/cursor/aider/cline. Adapter contract: agents/sessions/SCHEMA.md"

### Portability boundary (Constitutional Directive 4)
- `bin/fw sessions` and `agents/sessions/render.py` (or `.sh`) — **agent-neutral**, NO CC strings
- `agents/sessions/claude-code/list.sh` (or `.py`) — **CC-scoped**, knows `claude agents --json`
- `agents/sessions/SCHEMA.md` — documents the canonical schema as the contract for future adapters
- Zero CC-specific code in `lib/`, `agents/context/`, or any non-`agents/sessions/<provider>/` directory

## Acceptance Criteria

### Agent
- [x] `bin/fw sessions` exists and is wired into the `fw` dispatcher (visible in `fw help`).
- [x] `agents/sessions/SCHEMA.md` documents the canonical schema (fields, types, semantics of `project`/`state`/`age_seconds`) as the adapter contract.
- [x] `agents/sessions/claude-code/list.sh` reads `claude agents --json` and emits **canonical-schema JSONL** to stdout (one session per line). When `claude` not on PATH → exit 2 with clear message.
- [x] Renderer (`agents/sessions/render.py`) reads canonical JSONL from stdin and prints the grouped tree (`// project` headers, nested `Needs input`/`Working`/`Completed`, relative ages, `(loose)` bucket last). Agent-neutral — no CC string anywhere.
- [x] Provider autodetect: `command -v claude` → `cursor` → `aider` → `cline`; `FW_AGENT_PROVIDER` env override; clean exit-2 message when no adapter found.
- [x] `bin/fw sessions` end-to-end: autodetect → adapter → renderer → grouped tree printed.
- [x] Unit test for CC adapter (`tests/unit/sessions_claude_code_adapter.bats`): stub `claude` binary on PATH emits canned JSON; adapter emits canonical JSONL with correct field mapping; loose-cwd cases (cwd=`$HOME`, cwd=`/tmp`) get `project="(loose)"`.
- [x] Unit test for renderer (`tests/unit/sessions_render.bats`): canned canonical JSONL → expected text output (project ordering, state ordering, age formatting, loose bucket placement).
- [x] `bash -n bin/fw` and `python3 ast.parse` on adapter + renderer pass.
- [x] Reviewer PASS: `bin/fw reviewer T-2417`

### Human
- [ ] [REVIEW] Live-fire on this host's session set matches expectation
  **Steps:**
  1. Run `bin/fw sessions` from `/opt/999-Agentic-Engineering-Framework` (on branch `t2417-fw-sessions` — not yet FF'd to master)
  2. Compare output to the playback shape — projects as `// <name>` headers, nested state sub-sections (`Needs input` → `Working` → `Completed`), ages as `2d`/`1h`/`11m`
  **Expected:** Reads at a glance "which sessions are in which project, what state are they in". Project grouping is the affordance the global CC picker doesn't give you. (Note: `(loose)` bucket only appears when sessions have non-repo cwds — empty in today's session set is correct, not a bug.)
  **If not:** Note which projects render wrong, which states are off, which sessions land in the wrong bucket — file follow-up before close.

## Build summary (session S-2026-0616-1128 continuation)

**All 10 Agent ACs ticked. Reviewer PASS (R-3b07017a). 18/18 bats green.**

- `bin/fw sessions` — dispatcher with autodetect + `FW_AGENT_PROVIDER` override + `--provider` flag, wired into `fw help`
- `agents/sessions/SCHEMA.md` — canonical schema contract
- `agents/sessions/claude-code/list.sh` — single-file python3 adapter (shebang routes; `.sh` extension is convention only). Reads BOTH `state` (background) and `status` (interactive) per 2026-06-16 live probe. Handles `failed` with `description="failed"`
- `agents/sessions/render.py` — agent-neutral renderer, pure-stdlib
- `tests/unit/sessions_claude_code_adapter.bats` (10/10) + `tests/unit/sessions_render.bats` (8/8)
- Fabric: 5 cards registered
- Reviewer override OV-7d6af210 (mock-only-integration FP, 90d) — sibling of T-1730 / T-1811

## Recommendation

**Recommendation:** GO

**Rationale:** Build is complete and verified live on this host. The verb you asked for (`fw sessions` showing per-project grouping with state subsections) exists end-to-end, matches the layout we played back together before I built it, and was driven against your actual 25-session corpus, not stubs. Reviewer PASS independently confirms no anti-pattern findings.

**Evidence:**
- 10/10 Agent ACs `[x]` in `### Agent` block above (the framework's structural check)
- Reviewer PASS: scan ID **R-3b07017a** (override OV-7d6af210 suppresses one `mock-only-integration` heuristic FP — CC binary unavailable in CI; this is the same FP class as T-1730 / T-1811)
- 18/18 bats green: `tests/unit/sessions_claude_code_adapter.bats` (10) + `tests/unit/sessions_render.bats` (8)
- Live run against this host's `claude agents --all --json` (n=25 sessions): produces 10 project headers — `002-Claude-Partner-Network`, `025-WokrshopDesigner`, `050-email-archive`, `100-Video-riper-and-translation-app`, `999-Agentic-Engineering-Framework`, `arc012-livefire-demo`, `dimitri-mint-dev`, `fan-dashboard`, `project`, `termlink`. No `(loose)` today because every session's cwd is in a git repo.
- Branch `t2417-fw-sessions` pushed to origin at commit `32b20d9e2`. FF-to-master deliberately deferred to your live-fire pass.
- Portability honored (Constitutional Directive 4): zero CC-specific strings in `bin/fw sessions` or `agents/sessions/render.py`; adapter contract documented at `agents/sessions/SCHEMA.md`; new providers add `agents/sessions/<name>/list.sh` only.

## Verification

bash -n bin/fw
python3 -c "import ast; ast.parse(open('agents/sessions/claude-code/list.sh').read())"
python3 -c "import ast; ast.parse(open('agents/sessions/render.py').read())"
bats tests/unit/sessions_claude_code_adapter.bats
bats tests/unit/sessions_render.bats
out=$(bin/fw reviewer T-2417 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

### 2026-06-16T09:20:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2417-fw-sessions--portable-per-project-sessio.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f07dd669
- **Timestamp:** 2026-06-16T10:23:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - mock-only-integration @ AC vs Verification cross-check

### 2026-06-16T10:23:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
