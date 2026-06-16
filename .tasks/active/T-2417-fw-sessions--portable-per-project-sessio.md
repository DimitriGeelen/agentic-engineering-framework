---
id: T-2417
name: "fw sessions — portable per-project session view (implements T-2416 GO)"
description: >
  fw sessions — portable per-project session view (implements T-2416 GO)

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
created: 2026-06-16T09:20:14Z
last_update: 2026-06-16T09:20:14Z
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
- [ ] `bin/fw sessions` exists and is wired into the `fw` dispatcher (visible in `fw help`).
- [x] `agents/sessions/SCHEMA.md` documents the canonical schema (fields, types, semantics of `project`/`state`/`age_seconds`) as the adapter contract.
- [x] `agents/sessions/claude-code/list.sh` reads `claude agents --json` and emits **canonical-schema JSONL** to stdout (one session per line). When `claude` not on PATH → exit 2 with clear message.
- [x] Renderer (`agents/sessions/render.py`) reads canonical JSONL from stdin and prints the grouped tree (`// project` headers, nested `Needs input`/`Working`/`Completed`, relative ages, `(loose)` bucket last). Agent-neutral — no CC string anywhere.
- [ ] Provider autodetect: `command -v claude` → `cursor` → `aider` → `cline`; `FW_AGENT_PROVIDER` env override; clean exit-2 message when no adapter found.
- [ ] `bin/fw sessions` end-to-end: autodetect → adapter → renderer → grouped tree printed.
- [ ] Unit test for CC adapter (`tests/unit/sessions_claude_code_adapter.bats`): stub `claude` binary on PATH emits canned JSON; adapter emits canonical JSONL with correct field mapping; loose-cwd cases (cwd=`$HOME`, cwd=`/tmp`) get `project="(loose)"`.
- [ ] Unit test for renderer (`tests/unit/sessions_render.bats`): canned canonical JSONL → expected text output (project ordering, state ordering, age formatting, loose bucket placement).
- [ ] `bash -n bin/fw` and `bash -n agents/sessions/claude-code/list.sh` pass.
- [ ] Reviewer PASS: `bin/fw reviewer T-2417`

## Partial-complete state (session S-2026-0615-2341, budget critical at 288K)

**Done (3/10 Agent ACs ticked):**
- Schema doc (`agents/sessions/SCHEMA.md`)
- CC adapter (`agents/sessions/claude-code/list.sh`) — bash + inline python3
- Generic renderer (`agents/sessions/render.py`) — pure-stdlib

**TODO next session:**
1. Verify renderer syntax: `python3 -c "import ast; ast.parse(open('agents/sessions/render.py').read())"`
2. Verify CC adapter end-to-end manually: `bash agents/sessions/claude-code/list.sh | python3 agents/sessions/render.py` against live `claude agents --json`
3. Add `bin/fw sessions` dispatcher — autodetect (`command -v claude` → `cursor` → `aider` → `cline`), `FW_AGENT_PROVIDER` override, exit-2 message if no adapter
4. Wire into `bin/fw` help table
5. bats unit test for adapter (`tests/unit/sessions_claude_code_adapter.bats`) — stub `claude` on PATH with canned JSON
6. bats unit test for renderer (`tests/unit/sessions_render.bats`) — canned JSONL → expected output
7. `fw fabric register` the 4 new files
8. Reviewer PASS
9. Live-fire with operator on this host's session set (Human AC)
10. Branch + commit + FF + push + close

### Human
- [ ] [REVIEW] Live-fire on this host's session set matches expectation
  **Steps:**
  1. Run `bin/fw sessions` from `/opt/999-Agentic-Engineering-Framework`
  2. Compare output to the playback shape — projects as `// <name>` headers, nested state sub-sections, ages as `2d`/`1h`/`11m`, `(loose)` bucket for `$HOME`/`/tmp` sessions
  **Expected:** Reads at a glance "which sessions are in which project, what state are they in". Project grouping is the affordance the global CC picker doesn't give you.
  **If not:** Note which projects render wrong, which states are off, which sessions land in the wrong bucket — file follow-up before close.

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

bash -n bin/fw
bash -n agents/sessions/claude-code/list.sh
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
