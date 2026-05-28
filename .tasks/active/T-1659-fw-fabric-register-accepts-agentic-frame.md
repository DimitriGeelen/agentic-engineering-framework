---
id: T-1659
name: "fw fabric register accepts .agentic-framework/ vendored paths and creates malformed
  cards"
description: >
  Witness 2026-05-01: 'bin/fw fabric register .agentic-framework/lib/hook-telemetry.sh'
  produced a card at .fabric/components/.yaml (empty filename, dot-only). Two bugs:
  (1) accepts vendored-copy path that already has an upstream card (lib/hook-telemetry.sh),
  (2) filename-derivation logic returns empty when path starts with dot-prefix component.
  Should: detect vendored path → reject with hint to register upstream instead; OR
  derive filename robustly from full path (e.g. agentic-framework-lib-hook-telemetry.yaml).
  Not orchestrator-arc; framework hygiene.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-01T17:09:56Z
last_update: 2026-05-28T19:40:43Z
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 4
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=4 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1659: fw fabric register accepts .agentic-framework/ vendored paths and creates malformed cards

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

**Class widened 2026-05-03 (T-1693):** the malformed-card pattern is not limited to `.agentic-framework/` paths. `bin/fw fabric register .context/project/workflows/<file>.yaml` also produces `.fabric/components/.yaml` (empty filename) — four invocations all overwrote each other. Filename derivation is brittle for any path with multiple slashes; vendored-copy detection is a separate concern. Fix scope should cover **both** bugs: (1) robust filename derivation across all repo-relative paths (slash → dash, leading-dot stripped or hex-encoded), (2) detect vendored-copy paths and reject. T-1693 worked around it by manually deleting the malformed card; root fix lives here.

## Acceptance Criteria

### Agent
- [x] `agents/fabric/lib/register.sh:_do_register_file()` rejects any `rel_path` beginning with `.agentic-framework/` with a hint to register the upstream framework file instead. Exit non-zero; print the upstream path the agent should register. (Bug 1 — vendored-copy detection.)
- [x] Slug derivation replaces the greedy `s|\..*$||` with `s|\.[^./-]*$||` (strip ONLY the trailing extension), so paths with dots earlier in the slugified name no longer collapse to an empty string. (Bug 2 — multi-slash + leading-dot.)
- [x] The same slug derivation pattern in `_register_directory()` (in the same file) is fixed in lockstep — both call sites use the identical sed. (L-441 symmetry — don't fix half.)
- [x] `bats tests/unit/fabric_register_slug.bats` pins: (a) `.context/project/workflows/foo.yaml` → slug `context-project-workflows-foo`; (b) `.agentic-framework/lib/hook-telemetry.sh` → REJECT exit non-zero with "register the upstream"; (c) `lib/pickup.sh` → slug `lib-pickup` (regression guard for normal path); (d) `bin/fw` (no extension) → slug `bin-fw` (no-extension regression guard). 6/6 green (2 extra regression cases also pinned).

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
bash -n agents/fabric/lib/register.sh
bats tests/unit/fabric_register_slug.bats
out=$(bin/fw fabric register .agentic-framework/lib/hook-telemetry.sh 2>&1 || true); echo "$out" | grep -qi "register the upstream"
[ ! -f .fabric/components/.yaml ]
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## Recommendation

**Recommendation:** GO (complete)

**Rationale:** Two real bugs in `fw fabric register` closed at root. (1) Vendored `.agentic-framework/*` paths now refuse cleanly with a hint at the upstream path the agent should register instead — eliminates the duplicate-card/split-identity class. (2) Slug derivation no longer collapses to an empty string on any path with a dot earlier than the basename — six regression cases pinned by `tests/unit/fabric_register_slug.bats`. Fix applied to both `_do_register_file()` and the directory-walker's inline derivation in `_register_directory()` (L-441 symmetry — both call sites updated).

**Evidence:**
- `agents/fabric/lib/register.sh:_do_register_file()`: vendored prefix check at the top of the function, REJECTs with `Register the upstream framework file instead: fw fabric register <upstream-path>`. Non-zero exit.
- `agents/fabric/lib/register.sh`: both slug-derivation sites (`_do_register_file` line 187 and `_register_directory` line 109) now use `s|\.[^./-]*$||` (strip last extension only).
- `tests/unit/fabric_register_slug.bats`: 6 scenarios green. Covers (a) dot-prefix multi-slash, (b) vendored REJECT + no malformed card, (c) normal path, (d) no-extension path, (e) `.claude/settings.json`, (f) deep dot-prefix.
- Live smoke: `bin/fw fabric register .agentic-framework/lib/hook-telemetry.sh` → REJECT with upstream hint; `.fabric/components/.yaml` still absent (no malformed cards remain).

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-01T17:09:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1659-fw-fabric-register-accepts-agentic-frame.md
- **Context:** Initial task creation

### 2026-05-01T17:10:22Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-28T19:40:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now
