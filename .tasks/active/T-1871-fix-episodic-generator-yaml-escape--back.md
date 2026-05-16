---
id: T-1871
name: "fix episodic generator YAML escape — backticks in double-quoted scalars break parse (L-392)"
description: >
  Episodic generator emits invalid YAML when ## Decisions scalar contains backticks or other YAML-unsafe characters inside double-quoted strings. Reproduce: close T-1764-class task with backticked code in Decisions block; observe yaml.scanner.ScannerError on episodic load. Fix shape: switch to literal-block (|-) when content contains backtick/backslash/embedded-double-quote, or migrate to ruamel.yaml with explicit string handling.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-16T07:11:48Z
last_update: 2026-05-16T07:35:39Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1871: fix episodic generator YAML escape — backticks in double-quoted scalars break parse (L-392)

## Context

L-392 captured the class. Triggered on T-1764 close 2026-05-16: the task's `## Decisions` section embedded shell/markdown code with backticks (`` `markdown2.markdown(f"\`\`\`{lang}...\`\`\`")` ``). `agents/context/lib/episodic.sh` lines 320-333 emit each Decisions field wrapped in YAML **double-quoted scalars** (`chose: "$chose"`), escaping only `"` → `\"` via `sed 's/"/\\"/g'`. Backticks pass through untouched; the markdown author already wrote `\`` (escaped-backtick) to represent literal triple-backticks inside the inline-code wrapper, so the value handed to the YAML scalar ends up containing `\`` byte sequences. YAML double-quoted scalars reject `\`` ("found unknown escape character"). Generated `.context/episodic/T-1764.yaml` line 47 col 12 fails `yaml.safe_load`. Closure succeeds (task moves to completed/, status updates) but the episodic artefact is malformed.

Fix: switch decision-field writes from YAML double-quoted scalars to YAML single-quoted scalars. Single-quoted YAML scalars do NOT process escapes; the only escape rule is `'` → `''`. That handles backticks, backslashes, embedded double-quotes, and all other special-to-double-quote characters at once. Trade-off: input single-quotes need `'→''` escaping, but that's a single-character substitution vs the current per-special-char approach.

## Acceptance Criteria

### Agent
- [ ] `agents/context/lib/episodic.sh` decision-field emit (lines ~320-333) writes single-quoted YAML scalars: `chose: '$chose'`, `rationale: '$rationale'`, `alternatives_rejected: ['$rejected']`. Input single-quotes escaped via `sed "s/'/''/g"`.
- [ ] Decision topic header (line ~322-323) also switches to single-quoted: `- decision: '$topic'`.
- [ ] `tests/unit/test_episodic_yaml_decision_escape.bats` (new) covers: (a) decision with backticked code in Chose renders parseable YAML, (b) decision with embedded single-quote (`'`) escapes correctly, (c) decision with embedded double-quote renders without `\"` escape, (d) decision with literal `\n` (backslash-n) survives without becoming newline. All cases use `python3 -c "import yaml; yaml.safe_load(open(...))"` as the contract pin.
- [ ] Regenerate `.context/episodic/T-1764.yaml` via `bin/fw context generate-episodic T-1764` and confirm it parses (`python3 -c "import yaml; yaml.safe_load(open('.context/episodic/T-1764.yaml'))"`).
- [ ] `bash -n agents/context/lib/episodic.sh` clean.

**Captured state (2026-05-16T07:30Z, S-2026-0501-1642):** Task scoped with real ACs after L-392 was filed. Source-file edit was attempted but hit the §SESSION WRAPPING UP budget gate at 292K tokens (~97% of 300K window). Implementation deferred to next session — the fix is a one-block edit at `agents/context/lib/episodic.sh:316-337` (switch `"$value"` quoting to `'$value'`, change escape sed from `"/\\"` to `'/''`) plus a new bats covering the 4 cases listed above. Estimated 30 minutes including regression test + T-1764.yaml regeneration. No external dependencies.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
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

### 2026-05-16T07:11:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1871-fix-episodic-generator-yaml-escape--back.md
- **Context:** Initial task creation

### 2026-05-16T07:35:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
