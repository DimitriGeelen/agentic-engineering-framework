---
id: T-1871
name: "fix episodic generator YAML escape — backticks in double-quoted scalars break
  parse (L-392)"
description: >
  Episodic generator emits invalid YAML when ## Decisions scalar contains backticks
  or other YAML-unsafe characters inside double-quoted strings. Reproduce: close T-1764-class
  task with backticked code in Decisions block; observe yaml.scanner.ScannerError
  on episodic load. Fix shape: switch to literal-block (|-) when content contains
  backtick/backslash/embedded-double-quote, or migrate to ruamel.yaml with explicit
  string handling.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/lib/episodic.sh, 
      tests/unit/episodic_yaml_decision_escape.bats]
related_tasks: []
created: 2026-05-16T07:11:48Z
last_update: '2026-08-16T22:24:47Z'
date_finished: 2026-05-16T07:49:15Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1871: fix episodic generator YAML escape — backticks in double-quoted scalars break parse (L-392)

## Context

L-392 captured the class. Triggered on T-1764 close 2026-05-16: the task's `## Decisions` section embedded shell/markdown code with backticks (`` `markdown2.markdown(f"\`\`\`{lang}...\`\`\`")` ``). `agents/context/lib/episodic.sh` lines 320-333 emit each Decisions field wrapped in YAML **double-quoted scalars** (`chose: "$chose"`), escaping only `"` → `\"` via `sed 's/"/\\"/g'`. Backticks pass through untouched; the markdown author already wrote `\`` (escaped-backtick) to represent literal triple-backticks inside the inline-code wrapper, so the value handed to the YAML scalar ends up containing `\`` byte sequences. YAML double-quoted scalars reject `\`` ("found unknown escape character"). Generated `.context/episodic/T-1764.yaml` line 47 col 12 fails `yaml.safe_load`. Closure succeeds (task moves to completed/, status updates) but the episodic artefact is malformed.

Fix: switch decision-field writes from YAML double-quoted scalars to YAML single-quoted scalars. Single-quoted YAML scalars do NOT process escapes; the only escape rule is `'` → `''`. That handles backticks, backslashes, embedded double-quotes, and all other special-to-double-quote characters at once. Trade-off: input single-quotes need `'→''` escaping, but that's a single-character substitution vs the current per-special-char approach.

## Acceptance Criteria

### Agent
- [x] `agents/context/lib/episodic.sh` decision-field emit (lines ~320-333) writes single-quoted YAML scalars: `chose: '$chose'`, `rationale: '$rationale'`, `alternatives_rejected: ['$rejected']`. Input single-quotes escaped via `sed "s/'/''/g"`.
- [x] Decision topic header (line ~322-323) also switches to single-quoted: `- decision: '$topic'`.
- [x] `tests/unit/episodic_yaml_decision_escape.bats` (new) covers: (a) decision with backticked code in Chose renders parseable YAML, (b) decision with embedded single-quote (`'`) escapes correctly, (c) decision with embedded double-quote renders without `\"` escape, (d) decision with literal backslash survives. All cases use `python3 -c "import yaml; yaml.safe_load(open(...))"` as the contract pin. 6/6 pass.
- [x] Regenerated `.context/episodic/T-1764.yaml` via `bin/fw context generate-episodic T-1764` and confirmed it parses (`python3 -c "import yaml; yaml.safe_load(open('.context/episodic/T-1764.yaml'))"` → 2 decisions loaded).
- [x] `bash -n agents/context/lib/episodic.sh` clean.

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

bash -n agents/context/lib/episodic.sh
bats tests/unit/episodic_yaml_decision_escape.bats
python3 -c "import yaml; yaml.safe_load(open('.context/episodic/T-1764.yaml'))"

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

**Symptom:** Closing T-1764 on 2026-05-16 emitted `.context/episodic/T-1764.yaml` with `chose: "...`markdown2.markdown(f\"\`\`\`{lang}\n{content}\n\`\`\`\")"`. `yaml.safe_load` raised `yaml.scanner.ScannerError: found unknown escape character `\``` at line 47, col 12. The task-close state machine still completed (move + status update), but the episodic artefact was unreadable — invisible to `fw recall`, `fw timeline`, and any future episodic-driven retrieval.

**Root cause:** `agents/context/lib/episodic.sh:316-337` emitted each Decisions field as a YAML **double-quoted scalar** and escaped only embedded double-quotes (`sed 's/"/\\"/g'`). YAML double-quoted scalars interpret backslash-escape sequences (`\n`, `\t`, `\X`, etc.) and reject *unknown* `\X` forms — including `\`` (which the markdown author had written to represent a literal backtick inside an inline-code wrapper). The byte sequence reached the YAML scalar unchanged, and the parser correctly refused it.

**Why structurally allowed:** No test ever fed YAML-hostile content (backticks, backslashes, embedded quotes) through `generate-episodic` and re-parsed the output. The 47 prior `.context/episodic/*.yaml` artefacts all happened to use Decisions content with prose-only Chose/Why fields — the bug was latent until T-1764, the first Decisions block to contain a markdown code-span with escaped backticks. The escape strategy choice (double-quoted + per-char escape vs single-quoted + `'→''`) was never questioned because the smoke case worked.

**Prevention:** `tests/unit/episodic_yaml_decision_escape.bats` (this commit) pins the contract with 4 hostile-input cases: backticked code, embedded `'`, embedded `"`, and literal backslash. Each emits a decision block via the same sed chain the script uses and asserts `yaml.safe_load` succeeds. Future regressions to the escape strategy fail this test before reaching the field. The single-quoted choice (only `'→''` escape) means the next class of special character can only break in a known, narrow way — there is no longer an open set of "unknown escape" rejections to discover one task at a time. L-392 captures the class for future agents.

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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c49b3956
- **Timestamp:** 2026-06-02T15:00:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-16T07:49:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
