---
id: T-1557
name: "Sweep lib/*.sh for pipefail-trap class (L-302 systemic check)"
description: >
  Sweep lib/*.sh for pipefail-trap class (L-302 systemic check)

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: [lib/config.sh, lib/inception.sh, lib/yaml.sh, tests/unit/yaml_pipefail.bats]
related_tasks: []
created: 2026-04-27T18:24:42Z
last_update: 2026-04-27T18:30:40Z
date_finished: 2026-04-27T18:30:40Z
---

# T-1557: Sweep lib/*.sh for pipefail-trap class (L-302 systemic check)

## Context

L-302 (pipefail trap, captured T-1545) fixed one site (`lib/review.sh`) but the same bare-assignment + `grep | head | sed` pipeline pattern appears in foundation utilities (`lib/yaml.sh:get_yaml_field`, `lib/config.sh:_fw_config_file_val`) and three sites in `lib/inception.sh`. Empirically reproduced — a synthetic `set -e -o pipefail` shell calling `get_yaml_field file missing_field` exits 1 silently (no stderr, no return path). All three inception.sh sites are on the GO/NO-GO decision path; a malformed task file would silent-kill `fw inception decide`.

## Acceptance Criteria

### Agent
- [x] Foundation `get_yaml_field` in lib/yaml.sh returns 0 (not 1) when the requested field is absent, even under `set -e -o pipefail`
- [x] Foundation `_fw_config_file_val` in lib/config.sh does not silent-kill the parent shell when the requested key is absent
- [x] Three bare-assignment sites in lib/inception.sh (decide path + sweep path) are pipefail-safe (refactored to call the foundation helper or guarded directly)
- [x] New regression bats `tests/unit/yaml_pipefail.bats` covers the foundation invariant under set -e -o pipefail
- [x] All pre-existing bats suites still pass (no regression)


## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

bats tests/unit/yaml_pipefail.bats
bats tests/unit/review_pipefail.bats
bats tests/unit/placeholder_audit.bats
bash -c "set -e -o pipefail; source lib/yaml.sh; v=\$(get_yaml_field /etc/hostname missing); echo ok"

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

### 2026-04-27T18:24:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1557-sweep-libsh-for-pipefail-trap-class-l-30.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-966e47d7
- **Timestamp:** 2026-06-02T14:58:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T18:30:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
